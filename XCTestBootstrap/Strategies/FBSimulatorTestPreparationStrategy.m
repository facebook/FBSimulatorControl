/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSimulatorTestPreparationStrategy.h"

#import <FBControlCore/FBControlCore.h>

#import "FBDeviceOperator.h"
#import "FBFileManager.h"
#import "FBProductBundle.h"
#import "FBTestBundle.h"
#import "FBTestConfiguration.h"
#import "FBTestRunnerConfiguration.h"
#import "NSFileManager+FBFileManager.h"
#import "XCTestBootstrapError.h"
#import "FBCodeSignCommand.h"

@interface FBSimulatorTestPreparationStrategy ()
@property (nonatomic, copy) NSString *workingDirectory;
@property (nonatomic, copy) NSString *testRunnerBundleID;
@property (nonatomic, copy) NSString *testBundlePath;
@property (nonatomic, strong) id<FBFileManager> fileManager;
@end

@implementation FBSimulatorTestPreparationStrategy

+ (instancetype)strategyWithTestRunnerBundleID:(NSString *)testRunnerBundleID
                                testBundlePath:(NSString *)testBundlePath
                              workingDirectory:(NSString *)workingDirectory
{
  return
  [self strategyWithTestRunnerBundleID:testRunnerBundleID
                        testBundlePath:testBundlePath
                      workingDirectory:workingDirectory
                           fileManager:[NSFileManager defaultManager]
   ];
}

+ (instancetype)strategyWithTestRunnerBundleID:(NSString *)testRunnerBundleID
                                testBundlePath:(NSString *)testBundlePath
                              workingDirectory:(NSString *)workingDirectory
                                   fileManager:(id<FBFileManager>)fileManager
{
  FBSimulatorTestPreparationStrategy *strategy = [self.class new];
  strategy.testRunnerBundleID = testRunnerBundleID;
  strategy.testBundlePath = testBundlePath;
  strategy.workingDirectory = workingDirectory;
  strategy.fileManager = fileManager;
  return strategy;
}

#pragma mark - FBTestPreparationStrategy protocol

- (FBTestRunnerConfiguration *)prepareTestWithDeviceOperator:(id<FBDeviceOperator>)deviceOperator error:(NSError **)error
{
  NSAssert(deviceOperator, @"deviceOperator is needed to load bundles");
  NSAssert(self.workingDirectory, @"Working directory is needed to prepare bundles");
  NSAssert(self.testRunnerBundleID, @"Test runner bundle ID is needed to load bundles");
  NSAssert(self.testBundlePath, @"Path to test bundle is needed to load bundles");


  // Check the bundle is codesigned (if required).
  NSError *innerError;
  if (FBControlCoreGlobalConfiguration.isXcode8OrGreater && ![FBCodeSignCommand.codeSignCommandWithAdHocIdentity cdHashForBundleAtPath:self.testBundlePath error:&innerError]) {
    return [[[XCTestBootstrapError
      describeFormat:@"Could not determine bundle at path '%@' is codesigned and codesigning is required", self.testBundlePath]
      causedBy:innerError]
      fail:error];
  }

  // Prepare XCTest bundle
  NSUUID *sessionIdentifier = [NSUUID UUID];
  FBTestBundle *testBundle = [[[[[FBTestBundleBuilder builderWithFileManager:self.fileManager]
    withBundlePath:self.testBundlePath]
    withWorkingDirectory:self.workingDirectory]
    withSessionIdentifier:sessionIdentifier]
    buildWithError:&innerError];
  if (!testBundle) {
    return [[[XCTestBootstrapError
      describe:@"Failed to prepare test bundle"]
      causedBy:innerError]
      fail:error];
  }

  // Prepare test runner
  FBProductBundle *application = [deviceOperator applicationBundleWithBundleID:self.testRunnerBundleID error:error];
  if (!application) {
    return [[[XCTestBootstrapError
      describe:@"Failed to prepare test runner"]
      causedBy:innerError]
      fail:error];
  }

  NSString *IDEBundleInjectionFrameworkPath = [FBControlCoreGlobalConfiguration.developerDirectory
    stringByAppendingPathComponent:@"Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks/IDEBundleInjection.framework"];

  FBProductBundle *IDEBundleInjectionFramework = [[[FBProductBundleBuilder builder]
    withBundlePath:IDEBundleInjectionFrameworkPath]
    buildWithError:&innerError];
  if (!IDEBundleInjectionFramework) {
    return [[[XCTestBootstrapError
      describe:@"Failed to prepare IDEBundleInjectionFramework"]
      causedBy:innerError]
      fail:error];
  }

  return [[[[[[[FBTestRunnerConfigurationBuilder builder]
    withSessionIdentifer:sessionIdentifier]
    withTestRunnerApplication:application]
    withIDEBundleInjectionFramework:IDEBundleInjectionFramework]
    withWebDriverAgentTestBundle:testBundle]
    withTestConfigurationPath:testBundle.configuration.path]
    build];
}

@end
