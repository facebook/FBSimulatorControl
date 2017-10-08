/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBListTestStrategy.h"

#import <sys/types.h>
#import <sys/stat.h>

#import <FBControlCore/FBControlCore.h>
#import <XCTestBootstrap/XCTestBootstrap.h>

@interface FBListTestStrategy ()

@property (nonatomic, strong, readonly) id<FBXCTestProcessExecutor> executor;
@property (nonatomic, strong, readonly) FBListTestConfiguration *configuration;
@property (nonatomic, strong, readonly) id<FBControlCoreLogger> logger;

@end

@interface FBListTestStrategy_ReporterWrapped : NSObject <FBXCTestRunner>

@property (nonatomic, strong, readonly) FBListTestStrategy *strategy;
@property (nonatomic, strong, readonly) id<FBXCTestReporter> reporter;

@end

@implementation FBListTestStrategy_ReporterWrapped

- (instancetype)initWithStrategy:(FBListTestStrategy *)strategy reporter:(id<FBXCTestReporter>)reporter
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _strategy = strategy;
  _reporter = reporter;

  return self;
}


- (BOOL)executeWithError:(NSError **)error
{
  [self.reporter didBeginExecutingTestPlan];

  // Additional timeout added to base timeout to give time to catch a sample.
  NSTimeInterval timeout = self.strategy.configuration.testTimeout + 5;
  NSArray<NSString *> *testNames = [NSRunLoop.currentRunLoop awaitCompletionOfFuture:self.strategy.listTests timeout:timeout error:error];
  if (!testNames) {
    return NO;
  }
  for (NSString *testName in testNames) {
    NSRange slashRange = [testName rangeOfString:@"/"];
    NSString *className = [testName substringToIndex:slashRange.location];
    NSString *methodName = [testName substringFromIndex:slashRange.location + 1];
    [self.reporter testCaseDidStartForTestClass:className method:methodName];
    [self.reporter testCaseDidFinishForTestClass:className method:methodName withStatus:FBTestReportStatusPassed duration:0];
  }

  [self.reporter didFinishExecutingTestPlan];
  return YES;
}

@end

@implementation FBListTestStrategy

+ (instancetype)strategyWithExecutor:(id<FBXCTestProcessExecutor>)executor configuration:(FBListTestConfiguration *)configuration logger:(id<FBControlCoreLogger>)logger
{
  return [[self alloc] initWithExecutor:executor configuration:configuration logger:logger];
}

- (instancetype)initWithExecutor:(id<FBXCTestProcessExecutor>)executor configuration:(FBListTestConfiguration *)configuration logger:(id<FBControlCoreLogger>)logger
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _executor = executor;
  _configuration = configuration;
  _logger = logger;

  return self;
}

- (FBFuture<NSArray<NSString *> *> *)listTests
{
  NSString *xctestPath = self.configuration.destination.xctestPath;
  NSString *otestQueryPath = self.executor.queryShimPath;
  NSString *otestQueryOutputPath = [self.configuration.workingDirectory stringByAppendingPathComponent:@"query-output-pipe"];
  [NSFileManager.defaultManager removeItemAtPath:otestQueryOutputPath error:nil];

  if (mkfifo([otestQueryOutputPath UTF8String], S_IWUSR | S_IRUSR) != 0) {
    NSError *posixError = [[NSError alloc] initWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    return [[[FBXCTestError
      describeFormat:@"Failed to create a named pipe %@", otestQueryOutputPath]
      causedBy:posixError]
      failFuture];
  }

  NSArray<NSString *> *arguments = @[@"-XCTest", @"All", self.configuration.testBundlePath];
  NSDictionary<NSString *, NSString *> *environment = @{
    @"DYLD_INSERT_LIBRARIES": otestQueryPath,
    @"OTEST_QUERY_OUTPUT_FILE": otestQueryOutputPath,
    @"OtestQueryBundlePath": self.configuration.testBundlePath,
  };
  FBXCTestProcess *process = [FBXCTestProcess
    processWithLaunchPath:xctestPath
    arguments:arguments
    environment:environment
    waitForDebugger:NO
    stdOutReader:FBFileWriter.nullWriter
    stdErrReader:FBFileWriter.nullWriter
    executor:self.executor];

  // Start the process.
  pid_t processIdentifier = 0;
  FBFuture<NSNumber *> *future = [process start:&processIdentifier timeout:self.configuration.testTimeout];
  if (future.error) {
    return [FBFuture futureWithError:future.error];
  }

  NSError *error = nil;
  FBAccumilatingFileConsumer *consumer = [FBAccumilatingFileConsumer new];
  FBFileReader *reader = [FBFileReader readerWithFilePath:otestQueryOutputPath consumer:consumer error:&error];
  if (![reader startReadingWithError:&error]) {
    return [FBFuture futureWithError:error];
  }
  return [[future
    onQueue:self.executor.workQueue notifyOfCompletion:^(FBFuture *_) {
      [reader stopReadingWithError:nil];
    }]
    onQueue:self.executor.workQueue fmap:^(NSNumber *_) {
      NSMutableArray<NSString *> *testNames = [NSMutableArray array];
      for (NSString *line in consumer.lines) {
        if (line.length == 0) {
          // Ignore empty lines
          continue;
        }
        NSRange slashRange = [line rangeOfString:@"/"];
        if (slashRange.length == 0) {
          return [[FBXCTestError
            describeFormat:@"Received unexpected test name from shim: %@", line]
            failFuture];
        }
        [testNames addObject:line];
      }
      return [FBFuture futureWithResult:[testNames copy]];
    }];
}

- (id<FBXCTestRunner>)wrapInReporter:(id<FBXCTestReporter>)reporter
{
  return [[FBListTestStrategy_ReporterWrapped alloc] initWithStrategy:self reporter:reporter];
}

@end
