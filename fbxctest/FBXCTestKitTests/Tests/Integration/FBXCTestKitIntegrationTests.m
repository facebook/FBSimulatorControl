/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCTestKitFixtures.h"

#import <FBXCTestKit/FBXCTestKit.h>
#import <XCTest/XCTest.h>

#import "FBXCTestReporterDouble.h"

@interface FBXCTestKitIntegrationTests : XCTestCase

@property (nonatomic, strong, readwrite) FBXCTestReporterDouble *reporter;

@end

@implementation FBXCTestKitIntegrationTests

- (void)setUp
{
  self.reporter = [FBXCTestReporterDouble new];
}

- (void)testRunsiOSUnitTestInApplication
{
  NSError *error;
  NSString *workingDirectory = [FBXCTestKitFixtures createTemporaryDirectory];
  NSString *applicationPath = [FBXCTestKitFixtures tableSearchApplicationPath];
  NSString *testBundlePath = [FBXCTestKitFixtures iOSUnitTestBundlePath];
  NSString *appTestArgument = [NSString stringWithFormat:@"%@:%@", testBundlePath, applicationPath];
  NSArray *arguments = @[ @"run-tests", @"-destination", @"name=iPhone 6", @"-appTest", appTestArgument ];

  FBTestRunConfiguration *configuration = [[FBTestRunConfiguration alloc] initWithReporter:self.reporter processUnderTestEnvironment:@{}];
  [configuration loadWithArguments:arguments workingDirectory:workingDirectory error:&error];
  XCTAssertNil(error);

  FBXCTestRunner *testRunner = [FBXCTestRunner testRunnerWithConfiguration:configuration];
  [testRunner executeTestsWithError:&error];
  XCTAssertNil(error);

  XCTAssertTrue(self.reporter.printReportWasCalled);
  NSArray<NSArray<NSString *> *> *expected = @[
    @[@"iOSUnitTestFixtureTests", @"testHostProcessIsMobileSafari"],
    @[@"iOSUnitTestFixtureTests", @"testHostProcessIsXctest"],
    @[@"iOSUnitTestFixtureTests", @"testIsRunningInIOSApp"],
    @[@"iOSUnitTestFixtureTests", @"testIsRunningInMacOSXApp"],
    @[@"iOSUnitTestFixtureTests", @"testIsRunningOnIOS"],
    @[@"iOSUnitTestFixtureTests", @"testIsRunningOnMacOSX"],
    @[@"iOSUnitTestFixtureTests", @"testPossibleCrashingOfHostProcess"],
    @[@"iOSUnitTestFixtureTests", @"testWillAlwaysFail"],
    @[@"iOSUnitTestFixtureTests", @"testWillAlwaysPass"],
  ];
  XCTAssertEqualObjects(expected, self.reporter.startedTests);
  expected = @[
    @[@"iOSUnitTestFixtureTests", @"testIsRunningInIOSApp"],
    @[@"iOSUnitTestFixtureTests", @"testIsRunningOnIOS"],
    @[@"iOSUnitTestFixtureTests", @"testPossibleCrashingOfHostProcess"],
    @[@"iOSUnitTestFixtureTests", @"testWillAlwaysPass"],
  ];
  XCTAssertEqualObjects(expected, self.reporter.passedTests);
  expected = @[
    @[@"iOSUnitTestFixtureTests", @"testHostProcessIsMobileSafari"],
    @[@"iOSUnitTestFixtureTests", @"testHostProcessIsXctest"],
    @[@"iOSUnitTestFixtureTests", @"testIsRunningInMacOSXApp"],
    @[@"iOSUnitTestFixtureTests", @"testIsRunningOnMacOSX"],
    @[@"iOSUnitTestFixtureTests", @"testWillAlwaysFail"],
  ];
  XCTAssertEqualObjects(expected, self.reporter.failedTests);
}

- (void)testApplicationTestEndsOnCrashingTest
{
  NSError *error;
  NSString *workingDirectory = [FBXCTestKitFixtures createTemporaryDirectory];
  NSString *applicationPath = [FBXCTestKitFixtures tableSearchApplicationPath];
  NSString *testBundlePath = [FBXCTestKitFixtures iOSUnitTestBundlePath];
  NSString *appTestArgument = [NSString stringWithFormat:@"%@:%@", testBundlePath, applicationPath];
  NSArray *arguments = @[ @"run-tests", @"-destination", @"name=iPhone 6", @"-appTest", appTestArgument ];
  NSDictionary<NSString *, NSString *> *processUnderTestEnvironment = @{
    @"TEST_FIXTURE_SHOULD_CRASH" : @"1",
  };

  FBTestRunConfiguration *configuration = [[FBTestRunConfiguration alloc] initWithReporter:self.reporter processUnderTestEnvironment:processUnderTestEnvironment];
  [configuration loadWithArguments:arguments workingDirectory:workingDirectory error:&error];
  XCTAssertNil(error);

  FBXCTestRunner *testRunner = [FBXCTestRunner testRunnerWithConfiguration:configuration];
  [testRunner executeTestsWithError:&error];
  XCTAssertNil(error);

  XCTAssertTrue(self.reporter.printReportWasCalled);
  NSArray<NSArray<NSString *> *> *expected = @[
    @[@"iOSUnitTestFixtureTests", @"testHostProcessIsMobileSafari"],
    @[@"iOSUnitTestFixtureTests", @"testHostProcessIsXctest"],
    @[@"iOSUnitTestFixtureTests", @"testIsRunningInIOSApp"],
    @[@"iOSUnitTestFixtureTests", @"testIsRunningInMacOSXApp"],
    @[@"iOSUnitTestFixtureTests", @"testIsRunningOnIOS"],
    @[@"iOSUnitTestFixtureTests", @"testIsRunningOnMacOSX"],
    @[@"iOSUnitTestFixtureTests", @"testPossibleCrashingOfHostProcess"],
  ];
  XCTAssertEqualObjects(expected, self.reporter.startedTests);
  expected = @[
    @[@"iOSUnitTestFixtureTests", @"testIsRunningInIOSApp"],
    @[@"iOSUnitTestFixtureTests", @"testIsRunningOnIOS"],
  ];
  XCTAssertEqualObjects(expected, self.reporter.passedTests);
  expected = @[
    @[@"iOSUnitTestFixtureTests", @"testHostProcessIsMobileSafari"],
    @[@"iOSUnitTestFixtureTests", @"testHostProcessIsXctest"],
    @[@"iOSUnitTestFixtureTests", @"testIsRunningInMacOSXApp"],
    @[@"iOSUnitTestFixtureTests", @"testIsRunningOnMacOSX"],
  ];
  XCTAssertEqualObjects(expected, self.reporter.failedTests);
}

- (void)testRunsiOSLogicTestsWithoutApplication
{
  if (![FBTestRunConfiguration findShimDirectoryWithError:nil]) {
    NSLog(@"Could not locate a shim directory, skipping -[%@ %@]", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
    return;
  }

  NSError *error;
  NSString *workingDirectory = [FBXCTestKitFixtures createTemporaryDirectory];
  NSString *testBundlePath = [FBXCTestKitFixtures iOSUnitTestBundlePath];
  NSArray *arguments = @[ @"run-tests", @"-destination", @"name=iPhone 6", @"-logicTest", testBundlePath ];

  FBTestRunConfiguration *configuration = [[FBTestRunConfiguration alloc] initWithReporter:self.reporter processUnderTestEnvironment:@{}];
  [configuration loadWithArguments:arguments workingDirectory:workingDirectory error:&error];
  XCTAssertNil(error);

  FBXCTestRunner *testRunner = [FBXCTestRunner testRunnerWithConfiguration:configuration];
  [testRunner executeTestsWithError:&error];
  XCTAssertNil(error);

  XCTAssertTrue(self.reporter.printReportWasCalled);
  XCTAssertEqual([self.reporter eventsWithName:@"begin-test-suite"].count, 1u);
  XCTAssertEqual([self.reporter eventsWithName:@"end-test-suite"].count, 1u);
  XCTAssertEqual([self.reporter eventsWithName:@"begin-test"].count, 9u);
  XCTAssertEqual([self.reporter eventsWithName:@"end-test"].count, 9u);
}

- (void)testReportsMacOSXTestList
{
  if (![FBTestRunConfiguration findShimDirectoryWithError:nil]) {
    NSLog(@"Could not locate a shim directory, skipping -[%@ %@]", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
    return;
  }

  NSError *error;
  NSString *workingDirectory = [FBXCTestKitFixtures createTemporaryDirectory];
  NSString *testBundlePath = [FBXCTestKitFixtures macUnitTestBundlePath];
  NSArray *arguments = @[ @"run-tests", @"-sdk", @"macosx", @"-logicTest", testBundlePath, @"-listTestsOnly" ];

  FBTestRunConfiguration *configuration = [[FBTestRunConfiguration alloc] initWithReporter:self.reporter processUnderTestEnvironment:@{}];
  [configuration loadWithArguments:arguments workingDirectory:workingDirectory error:&error];
  XCTAssertNil(error);

  FBXCTestRunner *testRunner = [FBXCTestRunner testRunnerWithConfiguration:configuration];
  [testRunner executeTestsWithError:&error];
  XCTAssertNil(error);

  XCTAssertTrue(self.reporter.printReportWasCalled);
  NSArray<NSArray<NSString *> *> *expected = @[
    @[@"MacUnitTestFixtureTests", @"testHostProcessIsMobileSafari"],
    @[@"MacUnitTestFixtureTests", @"testHostProcessIsXctest"],
    @[@"MacUnitTestFixtureTests", @"testIsRunningInIOSApp"],
    @[@"MacUnitTestFixtureTests", @"testIsRunningInMacOSXApp"],
    @[@"MacUnitTestFixtureTests", @"testIsRunningOnIOS"],
    @[@"MacUnitTestFixtureTests", @"testIsRunningOnMacOSX"],
    @[@"MacUnitTestFixtureTests", @"testPossibleCrashingOfHostProcess"],
    @[@"MacUnitTestFixtureTests", @"testWillAlwaysFail"],
    @[@"MacUnitTestFixtureTests", @"testWillAlwaysPass"],
  ];
  XCTAssertEqualObjects(expected, self.reporter.startedTests);
}

@end
