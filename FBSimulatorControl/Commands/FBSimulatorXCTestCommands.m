/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSimulatorXCTestCommands.h"

#import <XCTestBootstrap/XCTestBootstrap.h>

#import "FBApplicationTestRunStrategy.h"
#import "FBSimulator+Private.h"
#import "FBSimulator.h"
#import "FBSimulatorError.h"
#import "FBSimulatorResourceManager.h"
#import "FBSimulatorTestRunStrategy.h"
#import "FBSimulatorXCTestProcessExecutor.h"

@interface FBSimulatorXCTestCommands ()

@property (nonatomic, weak, readonly) FBSimulator *simulator;

@end

@implementation FBSimulatorXCTestCommands

#pragma mark Initializers

+ (instancetype)commandsWithTarget:(FBSimulator *)target
{
  return [[self alloc] initWithSimulator:target];
}

- (instancetype)initWithSimulator:(FBSimulator *)simulator
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _simulator = simulator;
  return self;
}

#pragma mark Public

- (nullable id<FBXCTestOperation>)startTestWithLaunchConfiguration:(FBTestLaunchConfiguration *)testLaunchConfiguration reporter:(nullable id<FBTestManagerTestReporter>)reporter error:(NSError **)error
{
  return [self startTestWithLaunchConfiguration:testLaunchConfiguration reporter:reporter workingDirectory:self.simulator.auxillaryDirectory error:error];
}

- (nullable id<FBXCTestOperation>)startTestWithLaunchConfiguration:(FBTestLaunchConfiguration *)testLaunchConfiguration reporter:(nullable id<FBTestManagerTestReporter>)reporter workingDirectory:(nullable NSString *)workingDirectory error:(NSError **)error
{
  return [[FBSimulatorTestRunStrategy
    strategyWithSimulator:self.simulator configuration:testLaunchConfiguration workingDirectory:workingDirectory reporter:reporter]
    connectAndStartWithError:error];
}

- (BOOL)runApplicationTest:(FBApplicationTestConfiguration *)configuration reporter:(id<FBXCTestReporter>)reporter error:(NSError **)error
{
  return [[FBApplicationTestRunStrategy
    strategyWithSimulator:self.simulator configuration:configuration reporter:reporter logger:self.simulator.logger]
    executeWithError:error];
}

- (NSArray<id<FBXCTestOperation>> *)testOperations
{
  return [self.simulator.resourceSink.testManagers copy];
}

- (FBFuture<NSArray<NSString *> *> *)listTestsForBundleAtPath:(NSString *)bundlePath timeout:(NSTimeInterval)timeout
{
  NSError *error = nil;
  FBXCTestShimConfiguration *shims = [FBXCTestShimConfiguration defaultShimConfigurationWithError:&error];
  if (!shims) {
    return [FBFuture futureWithError:error];
  }
  FBXCTestDestination *destination = [[FBXCTestDestinationiPhoneSimulator alloc] initWithModel:self.simulator.deviceType.model version:self.simulator.osVersion.name];
  FBListTestConfiguration *configuration = [FBListTestConfiguration
    configurationWithDestination:destination
    shims:shims
    environment:@{}
    workingDirectory:self.simulator.auxillaryDirectory
    testBundlePath:bundlePath
    waitForDebugger:NO
    timeout:timeout];

  return [[FBListTestStrategy
    strategyWithExecutor:[FBSimulatorXCTestProcessExecutor executorWithSimulator:self.simulator configuration:configuration]
    configuration:configuration
    logger:self.simulator.logger]
    listTests];
}

#pragma mark Private


@end
