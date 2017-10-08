/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTask.h"

#import "FBControlCoreError.h"
#import "FBControlCoreLogger.h"
#import "FBFileConsumer.h"
#import "FBFileWriter.h"
#import "FBPipeReader.h"
#import "FBRunLoopSpinner.h"
#import "FBTaskConfiguration.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"

NSString *const FBTaskErrorDomain = @"com.facebook.FBControlCore.task";
FBTerminationHandleType const FBTerminationHandleTypeTask = @"Task";

@protocol FBTaskOutput <NSObject>

- (id)contents;
- (id)attachWithError:(NSError **)error;
- (void)teardownResources;

@end

@interface FBTaskOutput_File : NSObject <FBTaskOutput>

@property (nonatomic, copy, nullable, readonly) NSString *filePath;
@property (nonatomic, strong, nullable, readwrite) NSFileHandle *fileHandle;

@end

@interface FBTaskOutput_Consumer : NSObject <FBTaskOutput>

@property (nonatomic, strong, nullable, readwrite) FBPipeReader *reader;
@property (nonatomic, strong, nullable, readwrite) id<FBFileConsumer> consumer;

@end

@interface FBTaskOutput_Logger : FBTaskOutput_Consumer

@property (nonatomic, strong, readwrite) id<FBControlCoreLogger> logger;

@end

@interface FBTaskOutput_Data : FBTaskOutput_Consumer

@property (nonatomic, strong, readonly) FBAccumilatingFileConsumer *dataConsumer;

@end

@interface FBTaskOutput_String : FBTaskOutput_Data

@end

@interface FBTaskInput_Consumer : NSObject <FBTaskOutput, FBFileConsumer>

@property (nonatomic, strong, nullable, readonly) NSPipe *pipe;
@property (nonatomic, strong, nullable, readonly) id<FBFileConsumer> writer;

@end

@implementation FBTaskOutput_Consumer

- (instancetype)initWithConsumer:(id<FBFileConsumer>)consumer
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _consumer = consumer;

  return self;
}

- (id)contents
{
  return self.consumer;
}

- (id)attachWithError:(NSError **)error
{
  NSAssert(self.reader == nil, @"Cannot attach when already attached to a reader");
  self.reader = [FBPipeReader pipeReaderWithConsumer:self.consumer];
  if (![self.reader startReadingWithError:error]) {
    self.reader = nil;
    return nil;
  }
  return self.reader.pipe;
}

- (void)teardownResources
{
  [self.reader stopReadingWithError:nil];
  self.reader = nil;
}

@end

@implementation FBTaskOutput_Logger

- (instancetype)initWithLogger:(id<FBControlCoreLogger>)logger
{
  id<FBFileConsumer> consumer = [FBLineFileConsumer asynchronousReaderWithConsumer:^(NSString *line) {
    [logger log:line];
  }];
  self = [super initWithConsumer:consumer];
  if (!self) {
    return nil;
  }

  _logger = logger;
  return self;
}

- (id<FBControlCoreLogger>)contents
{
  return self.logger;
}

@end

@implementation FBTaskOutput_File

- (instancetype)initWithPath:(NSString *)filePath
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _filePath = filePath;
  return self;
}

- (NSString *)contents
{
  return self.filePath;
}

- (id)attachWithError:(NSError **)error
{
  NSAssert(self.fileHandle == nil, @"Cannot attach when already attached to file %@", self.fileHandle);
  if (!self.filePath) {
    self.fileHandle = NSFileHandle.fileHandleWithNullDevice;
    return self.fileHandle;
  }

  if (![NSFileManager.defaultManager createFileAtPath:self.filePath contents:nil attributes:nil]) {
    return [[FBControlCoreError
      describeFormat:@"Could not create file for writing at %@", self.filePath]
      fail:error];
  }
  self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
  return self.fileHandle;
}

- (void)teardownResources
{
  [self.fileHandle closeFile];
  self.fileHandle = nil;
}

@end

@implementation FBTaskOutput_Data

- (instancetype)initWithMutableData:(NSMutableData *)mutableData
{
  FBAccumilatingFileConsumer *consumer = [[FBAccumilatingFileConsumer alloc] initWithMutableData:mutableData];
  self = [super initWithConsumer:consumer];
  if (!self) {
    return nil;
  }

  _dataConsumer = consumer;

  return self;
}

- (NSData *)contents
{
  return self.dataConsumer.data;
}

@end

@implementation FBTaskOutput_String

- (NSString *)contents
{
  NSData *data = self.dataConsumer.data;
  // Strip newline from the end of the buffer.
  if (data.length) {
    char lastByte = 0;
    NSRange range = NSMakeRange(data.length - 1, 1);
    [data getBytes:&lastByte range:range];
    if (lastByte == '\n') {
      data = [data subdataWithRange:NSMakeRange(0, data.length - 1)];
    }
  }
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end

@implementation FBTaskInput_Consumer

- (id)contents
{
  return self.pipe ? self : nil;
}

- (id)attachWithError:(NSError **)error
{
  NSPipe *pipe = [NSPipe pipe];
  id<FBFileConsumer> writer = [FBFileWriter asyncWriterWithFileHandle:pipe.fileHandleForWriting error:error];
  if (!writer) {
    return nil;
  }
  _pipe = pipe;
  _writer = writer;
  return pipe;
}

- (void)teardownResources
{
  _pipe = nil;
  _writer = nil;
}

- (void)consumeData:(NSData *)data
{
  [self.writer consumeData:data];
}

- (void)consumeEndOfFile
{
  [self.writer consumeEndOfFile];
  [self teardownResources];
}

@end

@protocol FBTaskProcess <NSObject>

@property (nonatomic, assign, readonly) int terminationStatus;
@property (nonatomic, assign, readonly) BOOL isRunning;

- (pid_t)launchWithError:(NSError **)error terminationHandler:(void(^)(id<FBTaskProcess>))terminationHandler;
- (void)mountStandardOut:(id)stdOut;
- (void)mountStandardErr:(id)stdErr;
- (void)mountStandardIn:(id)stdIn;
- (void)terminate;

@end

@interface FBTaskProcess_NSTask : NSObject <FBTaskProcess>

@property (nonatomic, strong, readwrite) NSTask *task;

@end

@implementation FBTaskProcess_NSTask

+ (instancetype)fromConfiguration:(FBTaskConfiguration *)configuration
{
  NSTask *task = [[NSTask alloc] init];
  task.environment = configuration.environment;
  task.launchPath = configuration.launchPath;
  task.arguments = configuration.arguments;
  return [[self alloc] initWithTask:task];
}

- (instancetype)initWithTask:(NSTask *)task
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _task = task;
  return self;
}

- (pid_t)processIdentifier
{
  return self.task.processIdentifier;
}

- (int)terminationStatus
{
  return self.task.terminationStatus;
}

- (BOOL)isRunning
{
  return self.task.isRunning;
}

- (void)mountStandardOut:(id)stdOut
{
  self.task.standardOutput = stdOut;
}

- (void)mountStandardErr:(id)stdErr
{
  self.task.standardError = stdErr;
}

- (void)mountStandardIn:(id)stdIn
{
  self.task.standardInput = stdIn;
}

- (pid_t)launchWithError:(NSError **)error terminationHandler:(void(^)(id<FBTaskProcess>))terminationHandler
{
  self.task.terminationHandler = ^(NSTask *_) {
    [self terminate];
    terminationHandler(self);
  };
  [self.task launch];
  return self.task.processIdentifier;
}

- (void)terminate
{
  [self.task terminate];
  [self.task waitUntilExit];
  self.task.terminationHandler = nil;
}

@end

@interface FBTask ()

@property (nonatomic, copy, readonly) NSSet<NSNumber *> *acceptableStatusCodes;

@property (nonatomic, strong, nullable, readwrite) id<FBTaskProcess> process;
@property (nonatomic, strong, nullable, readwrite) id<FBTaskOutput> stdOutSlot;
@property (nonatomic, strong, nullable, readwrite) id<FBTaskOutput> stdErrSlot;
@property (nonatomic, strong, nullable, readwrite) id<FBTaskOutput> stdInSlot;
@property (nonatomic, copy, nullable, readwrite) NSString *configurationDescription;

@property (atomic, assign, readwrite) pid_t processIdentifier;
@property (atomic, assign, readwrite) int exitCode;
@property (atomic, assign, readwrite) BOOL completedTeardown;
@property (atomic, copy, nullable, readwrite) NSString *emittedError;

@property (atomic, copy, nullable, readwrite) void (^terminationHandler)(FBTask *);
@property (atomic, strong, nullable, readwrite) dispatch_queue_t terminationQueue;


@end

@implementation FBTask

#pragma mark Initializers

+ (id<FBTaskOutput>)createTaskOutput:(id)output
{
  if (!output) {
    return nil;
  }
  if ([output isKindOfClass:NSURL.class]) {
     return [[FBTaskOutput_File alloc] initWithPath:[output path]];
  }
  if ([output conformsToProtocol:@protocol(FBFileConsumer)]) {
    return [[FBTaskOutput_Consumer alloc] initWithConsumer:output];
  }
  if ([output conformsToProtocol:@protocol(FBControlCoreLogger)]) {
    return [[FBTaskOutput_Logger alloc] initWithLogger:output];
  }
  if ([output isKindOfClass:NSData.class]) {
    return [[FBTaskOutput_Data alloc] initWithMutableData:NSMutableData.data];
  }
  if ([output isKindOfClass:NSString.class]) {
    return [[FBTaskOutput_String alloc] initWithMutableData:NSMutableData.data];
  }
  NSAssert(NO, @"Unexpected output type %@", output);
  return nil;
}

+ (id<FBTaskOutput>)createTaskInput:(BOOL)connectStdIn
{
  if (!connectStdIn) {
    return nil;
  }
  return [FBTaskInput_Consumer new];
}

+ (instancetype)taskWithConfiguration:(FBTaskConfiguration *)configuration
{
  id<FBTaskProcess> task = [FBTaskProcess_NSTask fromConfiguration:configuration];
  id<FBTaskOutput> stdOut = [self createTaskOutput:configuration.stdOut];
  id<FBTaskOutput> stdErr = [self createTaskOutput:configuration.stdErr];
  id<FBTaskOutput> stdIn = [self createTaskInput:configuration.connectStdIn];
  return [[self alloc] initWithProcess:task stdOut:stdOut stdErr:stdErr stdIn:stdIn acceptableStatusCodes:configuration.acceptableStatusCodes configurationDescription:configuration.description];
}

- (instancetype)initWithProcess:(id<FBTaskProcess>)process stdOut:(id<FBTaskOutput>)stdOut stdErr:(id<FBTaskOutput>)stdErr stdIn:(id<FBTaskOutput>)stdIn acceptableStatusCodes:(NSSet<NSNumber *> *)acceptableStatusCodes configurationDescription:(NSString *)configurationDescription
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _process = process;
  _acceptableStatusCodes = acceptableStatusCodes;
  _stdOutSlot = stdOut;
  _stdErrSlot = stdErr;
  _stdInSlot = stdIn;
  _configurationDescription = configurationDescription;

  return self;
}

#pragma mark - FBTerminationHandle Protocol

- (void)terminate
{
  [self terminateWithErrorMessage:nil];
}

- (FBTerminationHandleType)handleType
{
  return FBTerminationHandleTypeTask;
}

#pragma mark - FBTask Protocl

#pragma mark Starting

- (instancetype)startAsynchronously
{
  return [self launchWithTerminationQueue:nil handler:nil];
}

- (instancetype)startAsynchronouslyWithTerminationQueue:(dispatch_queue_t)terminationQueue handler:(void (^)(FBTask *task))handler
{
  NSParameterAssert(terminationQueue);
  NSParameterAssert(handler);
  return [self launchWithTerminationQueue:terminationQueue handler:handler];
}

- (instancetype)startSynchronouslyWithTimeout:(NSTimeInterval)timeout
{
  [self launchWithTerminationQueue:nil handler:nil];

  NSError *error = nil;
  if (![self waitForCompletionWithTimeout:timeout error:&error]) {
    return [self terminateWithErrorMessage:error.description];
  }
  return [self terminateWithErrorMessage:nil];
}

#pragma mark Awaiting Completion

- (BOOL)waitForCompletionWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
{
  BOOL completed = [NSRunLoop.currentRunLoop spinRunLoopWithTimeout:timeout untilTrue:^ BOOL {
    return !self.process.isRunning;
  }];

  if (!completed) {
    return [[FBControlCoreError
      describeFormat:@"Launched process '%@' took longer than %f seconds to terminate", self, timeout]
      failBool:error];
  }
  [self terminateWithErrorMessage:nil];
  return YES;
}

#pragma mark Accessors

- (nullable id)stdOut
{
  return [self.stdOutSlot contents];
}

- (nullable id)stdErr
{
  return [self.stdErrSlot contents];
}

- (nullable id)stdIn
{
  return [self.stdInSlot contents];
}

- (nullable NSError *)error
{
  if (!self.emittedError) {
    return nil;
  }

  FBControlCoreError *error = [[[[[FBControlCoreError
    describe:self.emittedError]
    inDomain:FBTaskErrorDomain]
    extraInfo:@"stdout" value:self.stdOut]
    extraInfo:@"stderr" value:self.stdErr]
    extraInfo:@"pid" value:@(self.processIdentifier)];

  if (!self.process.isRunning) {
    [error extraInfo:@"exitcode" value:@(self.exitCode)];
  }
  return [error build];
}

- (BOOL)hasTerminated
{
  return self.completedTeardown;
}

- (BOOL)wasSuccessful
{
  @synchronized(self)
  {
    return self.hasTerminated && self.emittedError == nil;
  }
}

#pragma mark Private

- (instancetype)launchWithTerminationQueue:(dispatch_queue_t)queue handler:(void (^)(FBTask *task))handler
{
  // Since the FBTask may not be returned by anyone and is asynchronous, it needs to be retained.
  // This Retain is matched by a release in -[FBTask completeTermination].
  CFRetain((__bridge CFTypeRef)(self));

  self.terminationQueue = queue;
  self.terminationHandler = handler;

  NSError *error = nil;
  id<FBTaskOutput> slot = self.stdOutSlot;
  if (slot) {
    id stdOut = [slot attachWithError:&error];
    if (!stdOut) {
      return [self terminateWithErrorMessage:error.description];
    }
    [self.process mountStandardOut:stdOut];
  }

  slot = self.stdErrSlot;
  if (slot) {
    id stdErr = [slot attachWithError:&error];
    if (!stdErr) {
      return [self terminateWithErrorMessage:error.description];
    }
    [self.process mountStandardErr:stdErr];
  }

  slot = self.stdInSlot;
  if (slot) {
    id stdIn = [slot attachWithError:&error];
    if (!stdIn) {
      return [self terminateWithErrorMessage:error.description];
    }
    [self.process mountStandardIn:stdIn];
  }

  pid_t pid = [self.process launchWithError:&error terminationHandler:^(id<FBTaskProcess> process) {
    self.exitCode = process.terminationStatus;
    [self terminateWithErrorMessage:nil];
  }];
  if (pid < 1) {
    return [self terminateWithErrorMessage:error.description];
  }
  self.processIdentifier = pid;

  return self;
}

- (instancetype)terminateWithErrorMessage:(nullable NSString *)errorMessage
{
  @synchronized(self) {
    if (!self.emittedError) {
      self.emittedError = errorMessage;
    }
    if (self.completedTeardown) {
      return self;
    }

    [self teardownProcess];
    [self teardownResources];
    [self completeTermination];
    self.completedTeardown = YES;
    return self;
  }
}

- (void)teardownProcess
{
  if (self.process.isRunning) {
    [self.process terminate];
  }
}

- (void)teardownResources
{
  [self.stdOutSlot teardownResources];
  [self.stdErrSlot teardownResources];
  [self.stdInSlot teardownResources];
}

- (void)completeTermination
{
  NSAssert(self.process.isRunning == NO, @"Process should be terminated before calling completeTermination");
  if (self.emittedError == nil && [self.acceptableStatusCodes containsObject:@(self.process.terminationStatus)] == NO) {
    self.emittedError = [NSString stringWithFormat:@"Returned non-zero status code %d", self.process.terminationStatus];
  }

  // Matches the release in -[FBTask launchWithTerminationHandler:].
  CFRelease((__bridge CFTypeRef)(self));

  void (^terminationHandler)(FBTask *) = self.terminationHandler;
  if (!terminationHandler) {
    return;
  }
  dispatch_queue_t queue = self.terminationQueue;
  if (!queue) {
    return;
  }
  dispatch_async(queue, ^{
    terminationHandler(self);
  });
  self.terminationQueue = nil;
  self.terminationHandler = nil;
}

- (NSString *)description
{
  return [NSString
    stringWithFormat:@"%@ | Has Terminated %d",
    self.configurationDescription,
    self.hasTerminated
  ];
}

#pragma mark FBFuture

- (BOOL)hasCompleted
{
  return self.hasTerminated;
}

@end

#pragma clang diagnostic pop
