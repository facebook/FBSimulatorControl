/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBFramebufferVideo.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CVPixelBuffer.h>
#import <CoreVideo/CoreVideo.h>

#import "FBCapacityQueue.h"
#import "FBDiagnostic.h"
#import "FBFramebufferFrame.h"
#import "FBSimulatorError.h"
#import "FBSimulatorEventSink.h"
#import "FBSimulatorLogger.h"

typedef NS_ENUM(NSInteger, FBFramebufferVideoState) {
  FBFramebufferVideoStateNotStarted = 0,
  FBFramebufferVideoStateWaitingForFirstFrame = 1,
  FBFramebufferVideoStateRunning = 2,
  FBFramebufferVideoStateTerminating = 3,
};

static const OSType FBFramebufferPixelFormat = kCVPixelFormatType_32ARGB;
// Timescale is in microseconds.
static const CMTimeScale FBFramebufferVideoTimescale = 10E4;
static const CMTimeScale FBFramebufferVideoRoundingMode = kCMTimeRoundingMethod_RoundTowardZero;

@interface FBFramebufferVideo ()

@property (nonatomic, strong, readonly) FBDiagnostic *diagnostic;
@property (nonatomic, strong, readonly) id<FBSimulatorLogger> logger;
@property (nonatomic, strong, readonly) id<FBSimulatorEventSink> eventSink;

@property (nonatomic, strong, readonly) dispatch_queue_t mediaQueue;
@property (nonatomic, strong, readonly) FBCapacityQueue *frameQueue;

@property (nonatomic, assign, readwrite) FBFramebufferVideoState state;
@property (nonatomic, strong, readwrite) FBFramebufferFrame *lastFrame;
@property (nonatomic, assign, readwrite) CMTimebaseRef timebase;

@property (nonatomic, strong, readwrite) AVAssetWriter *writer;
@property (nonatomic, strong, readwrite) AVAssetWriterInputPixelBufferAdaptor *adaptor;
@property (nonatomic, copy, readwrite) NSDictionary *pixelBufferAttributes;

@end

@implementation FBFramebufferVideo

#pragma mark Initializers

+ (instancetype)withDiagnostic:(FBDiagnostic *)diagnostic shouldAutorecord:(BOOL)autorecord logger:(id<FBSimulatorLogger>)logger eventSink:(id<FBSimulatorEventSink>)eventSink
{
  dispatch_queue_t queue = dispatch_queue_create("com.facebook.FBSimulatorControl.media", DISPATCH_QUEUE_SERIAL);
  return [[self alloc] initWithDiagnostic:diagnostic shouldAutorecord:autorecord onQueue:queue logger:[logger onQueue:queue] eventSink:eventSink];
}

- (instancetype)initWithDiagnostic:(FBDiagnostic *)diagnostic shouldAutorecord:(BOOL)autorecord onQueue:(dispatch_queue_t)queue logger:(id<FBSimulatorLogger>)logger eventSink:(id<FBSimulatorEventSink>)eventSink
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _diagnostic = diagnostic;
  _logger = logger;
  _eventSink = eventSink;

  _mediaQueue = queue;
  _frameQueue = [FBCapacityQueue withCapacity:20];
  _state = autorecord ? FBFramebufferVideoStateWaitingForFirstFrame : FBFramebufferVideoStateNotStarted;
  _timebase = NULL;

  return self;
}

#pragma mark Public Methods

- (void)startRecording
{
  dispatch_async(self.mediaQueue, ^{
    // Must be NotStarted to flick the First Frame wait switch.
    if (self.state != FBFramebufferVideoStateNotStarted) {
      [self.logger.info logFormat:@"Cannot start recording with state '%@'", [FBFramebufferVideo stateStringForState:self.state]];
      return;
    }
    [self.logger.debug log:@"Manually starting recording"];
    self.state = FBFramebufferVideoStateWaitingForFirstFrame;
  });
}

- (void)stopRecording
{
  dispatch_group_t group = dispatch_group_create();
  dispatch_async(self.mediaQueue, ^{
    // No video has been recorded, so the recorder can just switch off.
    if (self.state == FBFramebufferVideoStateWaitingForFirstFrame) {
      self.state = FBFramebufferVideoStateNotStarted;
      return;
    }
    // If not running, this is an invalid state to call from.
    if (self.state != FBFramebufferVideoStateRunning) {
      [self.logger.info logFormat:@"Cannot stop recording with state '%@'", [FBFramebufferVideo stateStringForState:self.state]];
      return;
    }
    [self.logger.debug log:@"Manually stopping recording"];
    [self teardownWriterWithGroup:group];
  });
}

#pragma mark FBFramebufferDelegate Implementation

- (void)framebuffer:(FBSimulatorFramebuffer *)framebuffer didUpdate:(FBFramebufferFrame *)frame
{
  dispatch_async(self.mediaQueue, ^{
    // Push the image, converting to the new timebase.
    [self pushFrame:frame timebaseConversion:YES];
  });
}

- (void)framebuffer:(FBSimulatorFramebuffer *)framebuffer didBecomeInvalidWithError:(NSError *)error teardownGroup:(dispatch_group_t)teardownGroup
{
  dispatch_group_enter(teardownGroup);
  dispatch_barrier_async(self.mediaQueue, ^{
    [self teardownWriterWithGroup:teardownGroup];
    dispatch_group_leave(teardownGroup);
  });
}

#pragma mark - Private

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  NSParameterAssert([keyPath isEqualToString:@"readyForMoreMediaData"]);
  if (![change[NSKeyValueChangeNewKey] boolValue]) {
    return;
  }

  dispatch_async(self.mediaQueue, ^{
    [self drainQueue];
  });
}

#pragma mark Queueing

- (void)pushFrame:(FBFramebufferFrame *)frame timebaseConversion:(BOOL)timebaseConversion
{
  // Discard frames when there's no reason to record them
  if (self.state == FBFramebufferVideoStateNotStarted || self.state == FBFramebufferVideoStateTerminating) {
    self.lastFrame = nil;
    [self.frameQueue popAll];
    return;
  }
  // When waiting for first frame, start video recording.
  if (self.state == FBFramebufferVideoStateWaitingForFirstFrame) {
    self.lastFrame = nil;
    [self.frameQueue popAll];
    [self startRecordingWithFrame:frame error:nil];
    return;
  }

  // Convert the timebase if required, then push the frame to the queue and drain.
  frame = timebaseConversion ? [frame convertToTimebase:self.timebase timescale:FBFramebufferVideoTimescale roundingMethod:FBFramebufferVideoRoundingMode] : frame;
  [self.frameQueue push:frame];
  [self drainQueue];
}

- (FBFramebufferFrame *)popFrame
{
  FBFramebufferFrame *frame = [self.frameQueue pop];
  if (!frame) {
    return nil;
  }
  // It's important that a number of conditions are met to ensure that this call is reliable as possible.
  // Setting -[AVAssetWriter movieFragmentInterval] usually exacerbates any problems in the input.
  // Much of the information here comes from the AVFoundation guru @rfistman.
  //
  // 1) The time used in -[AVAssetWriter startSessionAtSourceTime:] should have the same value as the first call to -[AVAssetWriterInputPixelBufferAdaptor appendPixelBuffer:withPresentationTime:]
  // 2) The ordering of frames should always mean that each frame is sequential in it's presentation time. kCMTimeRoundingMethod_Default can result in strange values from rounding so kCMTimeRoundingMethod_RoundTowardNegativeInfinity is used.
  //
  // "The operation couldn't be completed. (OSStatus error -12633.)" is 'InvalidTimestamp': http://stackoverflow.com/a/23252239
  // "An unknown error occurred (-16341)" is 'kMediaSampleTimingGeneratorError_InvalidTimeStamp': @rfistman
  if (self.lastFrame && CMTimeCompare(frame.time, self.lastFrame.time) != 1) {
    [self.logger.error logFormat:@"Dropping Frame (%@) as it's timestamp is not greater than a previous frame (%@)", frame, self.lastFrame];
    return nil;
  }
  self.lastFrame = frame;
  return frame;
}

- (void)drainQueue
{
  NSInteger drainCount = 0;
  while (self.adaptor.assetWriterInput.readyForMoreMediaData) {
    FBFramebufferFrame *frame = [self popFrame];
    if (!frame) {
      return;
    }
    drainCount++;

    // Create the pixel buffer from the buffer pool if the pool exists, otherwise create one.
    NSError *error = nil;
    CVPixelBufferRef pixelBuffer = self.adaptor.pixelBufferPool
      ? [FBFramebufferVideo createPixelBufferFromAdaptor:self.adaptor ofImage:frame.image error:&error]
      : [FBFramebufferVideo createPixelBufferFromAttributes:self.pixelBufferAttributes ofImage:frame.image error:&error];
    if (!pixelBuffer) {
      [self.logger.error logFormat:@"Could not construct a pixel buffer for frame (%@): %@", frame, error];
      continue;
    }

    // Append the PixelBuffer to the Adaptor.
    if (![self.adaptor appendPixelBuffer:pixelBuffer withPresentationTime:frame.time]) {
      [self.logger.error logFormat:@"Failed to append pixel buffer of frame (%@) with error %@", frame, self.writer.error];
    }
    CVPixelBufferRelease(pixelBuffer);
  }
  if (drainCount == 0 && self.frameQueue.count > 0) {
    [self.logger.debug logFormat:@"Failed to drain any frames with a queue of length %lu", drainCount];
  }
}

#pragma mark Writer Lifecycle

- (BOOL)startRecordingWithFrame:(FBFramebufferFrame *)frame error:(NSError **)error
{
  // Bail out if we're in an invalid state
  if (self.state == FBFramebufferVideoStateWaitingForFirstFrame) {
    return [[FBSimulatorError
      describeFormat:@"Cannot start recording from state '%@'", [FBFramebufferVideo stateStringForState:self.state]]
      failBool:error];
  }

  // Create a Timebase to construct the time of the first frame.
  CMTimebaseRef timebase = NULL;
  CMTimebaseCreateWithMasterTimebase(
    kCFAllocatorDefault,
    frame.timebase,
    &timebase
  );
  NSAssert(timebase, @"Expected to be able to construct timebase");
  CMTimebaseSetTime(timebase, kCMTimeZero);
  CMTimebaseSetRate(timebase, 1.0);
  self.timebase = timebase;

  // Create the asset writer.
  FBDiagnosticBuilder *logBuilder = [FBDiagnosticBuilder builderWithDiagnostic:self.diagnostic];
  NSString *path = logBuilder.createPath;
  if (![self createAssetWriterAtPath:path fromFrame:frame error:error]) {
    return NO;
  }
  // Mark as running.
  self.state = FBFramebufferVideoStateRunning;

  // Enqueue the first frame, converting it to the timebase that has just been created.
  [self pushFrame:frame timebaseConversion:YES];

  // Report the availability of the video
  [self.eventSink diagnosticAvailable:[[logBuilder updatePath:path] build]];

  return YES;
}

- (BOOL)createAssetWriterAtPath:(NSString *)videoPath fromFrame:(FBFramebufferFrame *)frame error:(NSError **)error
{
  NSError *innerError = nil;
  NSURL *url = [NSURL fileURLWithPath:videoPath];
  AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeMPEG4 error:&innerError];
  if (!writer) {
    return [[[FBSimulatorError
      describeFormat:@"Failed to create an asset writer at %@", videoPath]
      causedBy:innerError]
      failBool:error];
  }

  // Create an Input for the Writer
  NSDictionary *outputSettings = @{
    AVVideoCodecKey : AVVideoCodecH264,
    AVVideoWidthKey : @(frame.size.width),
    AVVideoHeightKey : @(frame.size.height),
  };
  AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSettings];
  input.expectsMediaDataInRealTime = NO;
  if (![writer canAddInput:input]) {
    return [[FBSimulatorError
      describeFormat:@"Not permitted to add writer input at %@", input]
      failBool:error];
  }
  [writer addInput:input];

  // Create an adaptor for writing to the input via concrete pixel buffers
  self.pixelBufferAttributes =  @{
    (NSString *) kCVPixelBufferCGImageCompatibilityKey:(id)kCFBooleanTrue,
    (NSString *) kCVPixelBufferCGBitmapContextCompatibilityKey:(id)kCFBooleanTrue,
    (NSString *) kCVPixelBufferWidthKey : @(frame.size.width),
    (NSString *) kCVPixelBufferHeightKey : @(frame.size.height),
    (NSString *) kCVPixelBufferPixelFormatTypeKey : @(FBFramebufferPixelFormat)
  };
  AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
   assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input
   sourcePixelBufferAttributes:self.pixelBufferAttributes];

  // If the file exists at the path it must be removed first.
  NSFileManager *fileManager = NSFileManager.defaultManager;
  if ([fileManager fileExistsAtPath:videoPath] && ![fileManager removeItemAtPath:videoPath error:&innerError]) {
    return [[[FBSimulatorError
      describeFormat:@"Failed to remove item at path %@ prior to deletion", videoPath]
      causedBy:innerError]
      failBool:error];
  }

  // Start the Writer and the Session
  if (![writer startWriting]) {
    return [[[FBSimulatorError
      describeFormat:@"Failed to start writing to the writer %@ error code %ld", writer, writer.status]
      causedBy:writer.error]
      failBool:error];
  }
  // Create a writer at time zero with the first frame's scale.
  CMTime startTime = CMTimeMake(0, frame.time.timescale);
  [writer startSessionAtSourceTime:startTime];

  // Success means the state needs to be set.
  self.writer = writer;
  self.adaptor = adaptor;
  [writer addObserver:self forKeyPath:@"readyForMoreMediaData" options:NSKeyValueObservingOptionNew context:NULL];

  // Log the success
  [self.logger.info logFormat:@"Started Recording video at path %@", videoPath];

  return YES;
}

- (void)teardownWriterWithGroup:(dispatch_group_t)teardownGroup
{
  // Invalid to teardown when not running.
  if (self.state != FBFramebufferVideoStateRunning) {
    [self.logger.info logFormat:@"Cannot stop recording with state '%@'", [FBFramebufferVideo stateStringForState:self.state]];
    return;
  }

  // Push last frame if one exists.
  if (self.lastFrame) {
    // Construct a time at the current timebase's time and push it to the queue.
    // Timebase conversion does not need to apply.
    CMTime time = CMTimebaseGetTimeWithTimeScale(self.timebase, FBFramebufferVideoTimescale, FBFramebufferVideoRoundingMode);
    FBFramebufferFrame *finalFrame = [[FBFramebufferFrame alloc] initWithTime:time timebase:self.timebase image:self.lastFrame.image count:(self.lastFrame.count + 1) size:self.lastFrame.size];
    [self.logger.info logFormat:@"Pushing last frame (%@) with new timing (%@) as this is the final frame", self.lastFrame, finalFrame];
    [self pushFrame:finalFrame timebaseConversion:NO];
  }

  // Update state.
  self.state = FBFramebufferVideoStateTerminating;
  [self.logger.info logFormat:@"Marking video at '%@ as finished", self.writer.outputURL];

  // Free Resources
  CFRelease(self.timebase);
  self.timebase = nil;
  [self.adaptor.assetWriterInput markAsFinished];
  [self.writer removeObserver:self forKeyPath:@"readyForMoreMediaData"];

  // Finish writing, making sure to update state on the media queue.
  [self.logger.info logFormat:@"Finishing Writing '%@'", self.writer.outputURL];
  dispatch_group_enter(teardownGroup);
  [self.writer finishWritingWithCompletionHandler:^{
    [self.logger.info logFormat:@"Finished Writing '%@'", self.writer.outputURL];
    dispatch_group_leave(teardownGroup);
    dispatch_async(self.mediaQueue, ^{
      self.state = FBFramebufferVideoStateNotStarted;
    });
  }];
}

#pragma mark Pixel Buffers

+ (CVPixelBufferRef)createPixelBufferFromAttributes:(NSDictionary *)attributes ofImage:(CGImageRef)image error:(NSError **)error
{
  size_t width = (size_t) [attributes[(NSString *) kCVPixelBufferWidthKey] unsignedLongValue];
  size_t height = (size_t) [attributes[(NSString *) kCVPixelBufferHeightKey] unsignedLongValue];
  OSType pixelFormat = [attributes[(NSString *) kCVPixelBufferPixelFormatTypeKey] unsignedIntValue];

  // Create the Pixel Buffer, caller will release.
  CVPixelBufferRef pixelBuffer = NULL;
  CVReturn status = CVPixelBufferCreate(
    kCFAllocatorDefault,
    width,
    height,
    pixelFormat,
    (__bridge CFDictionaryRef) attributes,
    &pixelBuffer
  );
  if (status != kCVReturnSuccess) {
    [[FBSimulatorError describeFormat:@"CVPixelBufferCreate returned non-success status %d", status] fail:error];
    return NULL;
  }

  return [self writeImage:image ofSize:CGSizeMake(width, height) intoPixelBuffer:pixelBuffer];
}

+ (CVPixelBufferRef)createPixelBufferFromAdaptor:(AVAssetWriterInputPixelBufferAdaptor *)adaptor ofImage:(CGImageRef)image error:(NSError **)error
{
  if (!adaptor.pixelBufferPool) {
    [[FBSimulatorError describe:@"-[AVAssetWriterInputPixelBufferAdaptor pixelBufferPool] is nil"] fail:error];
    return NULL;
  }

  // Get the pixel buffer from the pool
  CVPixelBufferRef pixelBuffer = NULL;
  CVReturn status = CVPixelBufferPoolCreatePixelBuffer(
    NULL,
    adaptor.pixelBufferPool,
    &pixelBuffer
  );
  if (status != kCVReturnSuccess) {
    [[FBSimulatorError describeFormat:@"CVPixelBufferPoolCreatePixelBuffer returned non-success status %d", status] fail:error];
    return NULL;
  }

  size_t width = (size_t) [adaptor.sourcePixelBufferAttributes[(NSString *) kCVPixelBufferWidthKey] unsignedLongValue];
  size_t height = (size_t) [adaptor.sourcePixelBufferAttributes[(NSString *) kCVPixelBufferHeightKey] unsignedLongValue];
  return [self writeImage:image ofSize:CGSizeMake(width, height) intoPixelBuffer:pixelBuffer];
}

+ (CVPixelBufferRef)writeImage:(CGImageRef)image ofSize:(CGSize)size intoPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
  // Get and lock the buffer.
  CVPixelBufferLockBaseAddress(pixelBuffer, 0);
  void *buffer = CVPixelBufferGetBaseAddress(pixelBuffer);

  // Create a graphics context based on the pixel buffer.
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(
    buffer,
    (size_t) size.width,
    (size_t) size.height,
    8, // See CGBitmapContextCreate documentation
    CVPixelBufferGetBytesPerRow(pixelBuffer),
    colorSpace,
    (CGBitmapInfo) kCGImageAlphaNoneSkipFirst
  );

  // Draw to it.
  CGRect rect = { .size = size, .origin = CGPointZero };
  CGContextDrawImage(
    context,
    rect,
    image
  );

  // Cleanup.
  CGColorSpaceRelease(colorSpace);
  CGContextRelease(context);
  CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

  return pixelBuffer;
}

#pragma mark String Formatting

+ (NSString *)stateStringForState:(FBFramebufferVideoState)state
{
  switch (state) {
    case FBFramebufferVideoStateNotStarted:
      return @"Not Started";
    case FBFramebufferVideoStateWaitingForFirstFrame:
      return @"Waiting for First Frame";
    case FBFramebufferVideoStateRunning:
      return @"Running";
    case FBFramebufferVideoStateTerminating:
      return @"Terminating";
    default:
      return @"Unknown";
  }
}

@end
