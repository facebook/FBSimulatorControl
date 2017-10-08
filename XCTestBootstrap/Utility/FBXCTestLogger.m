/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCTestLogger.h"

static NSString *const fbxctestOutputLogDirectoryEnv = @"FBXCTEST_LOG_DIRECTORY";
static NSString *const xctoolOutputLogDirectoryEnv = @"XCTOOL_TEST_ENV_FB_LOG_DIRECTORY";

@interface FBXCTestLogger ()

@property (nonatomic, copy, readonly) NSString *logDirectory;
@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, strong, readonly) NSFileHandle *fileHandle;
@property (nonatomic, strong, readonly) id<FBControlCoreLogger> baseLogger;

@end

@implementation FBXCTestLogger

+ (NSString *)logDirectory
{
  NSString *directory = NSProcessInfo.processInfo.environment[fbxctestOutputLogDirectoryEnv];
  if (directory) {
    return directory;
  }
  directory = NSProcessInfo.processInfo.environment[xctoolOutputLogDirectoryEnv];
  if (directory) {
    return directory;
  }
  directory = [NSFileManager.defaultManager.currentDirectoryPath stringByAppendingPathComponent:@"tmp"];
  if ([NSFileManager.defaultManager fileExistsAtPath:directory]) {
    return directory;
  }
  return NSTemporaryDirectory();
}

+ (NSString *)defaultLogName
{
  return [NSString stringWithFormat:@"%@_test.log", NSProcessInfo.processInfo.globallyUniqueString];
}

+ (instancetype)defaultLoggerInDefaultDirectory
{
  return [self loggerInDefaultDirectory:self.defaultLogName];
}

+ (instancetype)loggerInDefaultDirectory:(NSString *)name
{
  return [self loggerInDirectory:self.logDirectory name:name];
}

+ (instancetype)defaultLoggerInDirectory:(NSString *)directory
{
  return [self loggerInDirectory:directory name:self.defaultLogName];
}

+ (instancetype)loggerInDirectory:(NSString *)directory name:(NSString *)name
{
  // First, ensure that the container directory exists. Some directories may not exist yet.
  NSError *error = nil;
  BOOL success = [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error];
  NSAssert(success, @"Expected to create directory at path %@, but could not %@", directory, error);

  // Create an empty file so that it can be appeneded to.
  NSString *path = [directory stringByAppendingPathComponent:name];
  success = [NSFileManager.defaultManager createFileAtPath:path contents:nil attributes:nil];
  NSAssert(success, @"Expected to create file at path %@, but could not", path);
  NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
  NSAssert(fileHandle, @"Could not create a writable file handle for file at path %@", fileHandle);

  id<FBControlCoreLogger> baseLogger = [FBControlCoreLogger compositeLoggerWithLoggers:@[
    [FBControlCoreLogger systemLoggerWritingToStderrr:YES withDebugLogging:YES],
    [FBControlCoreLogger systemLoggerWritingToFileHandle:fileHandle withDebugLogging:YES],
  ]];

  return [[self alloc] initWithBaseLogger:baseLogger logDirectory:directory];
}

- (instancetype)initWithBaseLogger:(id<FBControlCoreLogger>)baseLogger logDirectory:(NSString *)logDirectory
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _baseLogger = baseLogger;
  _logDirectory = logDirectory;

  return self;
}

#pragma mark Protocol Implementation

- (id<FBControlCoreLogger>)log:(NSString *)string
{
  [self.baseLogger log:string];
  return self;
}

- (id<FBControlCoreLogger>)logFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2)
{
  va_list args;
  va_start(args, format);
  NSString *string = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);

  return [self log:string];
}

- (id<FBControlCoreLogger>)info
{
  return [[self.class alloc]
    initWithBaseLogger:[self.baseLogger info]
    logDirectory:self.logDirectory];
}

- (id<FBControlCoreLogger>)debug
{
  return [[self.class alloc]
    initWithBaseLogger:[self.baseLogger debug]
    logDirectory:self.logDirectory];
}

- (id<FBControlCoreLogger>)error
{
  return [[self.class alloc]
    initWithBaseLogger:[self.baseLogger error]
    logDirectory:self.logDirectory];
}

- (id<FBControlCoreLogger>)onQueue:(dispatch_queue_t)queue
{
  return [[self.class alloc]
    initWithBaseLogger:[self.baseLogger onQueue:queue]
    logDirectory:self.logDirectory];
}

- (id<FBControlCoreLogger>)withPrefix:(NSString *)prefix
{
  return [[self.class alloc]
    initWithBaseLogger:[self.baseLogger withPrefix:prefix]
    logDirectory:self.logDirectory];
}

- (id<FBFileConsumer>)logConsumptionToFile:(id<FBFileConsumer>)consumer outputKind:(NSString *)outputKind udid:(NSUUID *)uuid
{
  NSString *fileName = [NSString stringWithFormat:@"%@.%@", uuid.UUIDString, outputKind];
  NSString *filePath = [self.logDirectory stringByAppendingPathComponent:fileName];
  NSError *error = nil;
  FBFileWriter *writer = [FBFileWriter asyncWriterForFilePath:filePath error:&error];
  NSAssert(writer, @"Could not make side-channel writer %@", error);

  return [FBCompositeFileConsumer consumerWithConsumers:@[
    consumer,
    writer,
  ]];
}

@end
