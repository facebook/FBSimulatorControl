/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBApplicationTestRunner.h"

#import <FBSimulatorControl/FBSimulatorControl.h>
#import <XCTestBootstrap/XCTestBootstrap.h>

#import "FBTestRunConfiguration.h"
#import "FBXCTestLogger.h"
#import "FBXCTestReporterAdapter.h"

@interface FBApplicationTestRunner ()

@property (nonatomic, strong, readonly) FBSimulator *simulator;
@property (nonatomic, strong, readonly) FBTestRunConfiguration *configuration;

@end

@implementation FBApplicationTestRunner

+ (instancetype)withSimulator:(FBSimulator *)simulator configuration:(FBTestRunConfiguration *)configuration
{
  return [[self alloc] initWithSimulator:simulator configuration:configuration];
}

- (instancetype)initWithSimulator:(FBSimulator *)simulator configuration:(FBTestRunConfiguration *)configuration
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _simulator = simulator;
  _configuration = configuration;

  return self;
}

- (BOOL)runTestsWithError:(NSError **)error
{
  FBApplicationDescriptor *testRunnerApp = [FBApplicationDescriptor applicationWithPath:self.configuration.runnerAppPath error:error];
  if (!testRunnerApp) {
    [self.configuration.logger logFormat:@"Failed to open test runner application: %@", *error];
    return NO;
  }

  if (![[self.simulator.interact installApplication:testRunnerApp] perform:error]) {
    [self.configuration.logger logFormat:@"Failed to install test runner application: %@", *error];
    return NO;
  }

  FBApplicationLaunchConfiguration *appLaunch = [FBApplicationLaunchConfiguration
    configurationWithApplication:testRunnerApp
    arguments:@[]
    environment:self.configuration.processUnderTestEnvironment
    options:0];

  NSString *workingDirectoryPath = [self.configuration.workingDirectory stringByAppendingPathComponent:@"tmp"];
  FBInteraction *interaction = [[self.simulator.interact
    startTestRunnerLaunchConfiguration:appLaunch
    testBundlePath:self.configuration.testBundlePath
    reporter:[FBXCTestReporterAdapter adapterWithReporter:self.configuration.reporter]
    workingDirectory:workingDirectoryPath]
    waitUntilAllTestRunnersHaveFinishedTestingWithTimeout:5000];


  if (![interaction perform:error]) {
    [self.configuration.logger logFormat:@"Failed to execute test bundle: %@", *error];
    return NO;
  }
  return YES;
}


@end
