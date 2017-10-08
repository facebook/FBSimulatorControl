/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>

#import <XCTestBootstrap/XCTestBootstrap.h>

@interface FBTestConfigurationTests : XCTestCase

@end

@implementation FBTestConfigurationTests

- (void)testSimpleConstructor
{
  NSUUID *sessionIdentifier = [[NSUUID alloc] initWithUUIDString:@"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"];
  FBTestConfiguration *testConfiguration = [FBTestConfiguration
    configurationWithSessionIdentifier:sessionIdentifier
    moduleName:@"Franek"
    testBundlePath:@"BundlePath"
    path:@"ConfigPath"
    uiTesting:YES];

  XCTAssertTrue([testConfiguration isKindOfClass:FBTestConfiguration.class]);
  XCTAssertEqual(testConfiguration.sessionIdentifier, sessionIdentifier);
  XCTAssertTrue([testConfiguration isKindOfClass:FBTestConfiguration.class]);
  XCTAssertEqual(testConfiguration.testBundlePath, @"BundlePath");
  XCTAssertEqual(testConfiguration.path, @"ConfigPath");
  XCTAssertTrue(testConfiguration.shouldInitializeForUITesting);
}

- (void)testSaveAs
{
  NSError *error;
  NSUUID *sessionIdentifier = NSUUID.UUID;
  NSString *savePath = [NSTemporaryDirectory() stringByAppendingPathComponent:sessionIdentifier.UUIDString];

  FBTestConfiguration *testConfiguration = [FBTestConfiguration
    configurationWithFileManager:NSFileManager.defaultManager
    sessionIdentifier:sessionIdentifier
    moduleName:@"ModuleName"
    testBundlePath:@"BundlePath"
    uiTesting:YES
    testsToRun:[NSSet set]
    testsToSkip:[NSSet set]
    targetApplicationPath:@"targetAppPath"
    targetApplicationBundleID:@"targetBundleID"
    savePath:savePath
    error:&error];

  XCTAssertNil(error);
  XCTAssertNotNil(testConfiguration);
  XCTAssertEqual(testConfiguration.path, savePath);
  XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:savePath]);
}

@end
