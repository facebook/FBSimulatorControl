/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import <XCTestBootstrap/XCTestBootstrap.h>
#import <FBControlCore/FBControlCore.h>

NS_ASSUME_NONNULL_BEGIN

@class FBApplicationLaunchConfiguration;
@class FBApplicationTestConfiguration;
@class FBSimulator;
@class FBTestBundle;
@class FBTestLaunchConfiguration;
@protocol FBTestManagerTestReporter;
@protocol FBXCTestReporter;

/**
 Commands to perform on a Simulator, related to XCTest.
 */
@protocol FBSimulatorXCTestCommands <NSObject, FBXCTestCommands, FBiOSTargetCommand>

/**
 Starts testing application using test bundle.

 @param testLaunchConfiguration configuration used to launch test.
 @param reporter the reporter to report to.
 @param error an error out for any error that occurs.
 @return a Test Operation if successful, nil otherwise.
 */
- (nullable id<FBXCTestOperation>)startTestWithLaunchConfiguration:(FBTestLaunchConfiguration *)testLaunchConfiguration reporter:(nullable id<FBTestManagerTestReporter>)reporter error:(NSError **)error;

/**
 Starts testing application using test bundle.

 @param testLaunchConfiguration configuration used to launch test.
 @param reporter the reporter to report to.
 @param workingDirectory xctest working directory.
 @param error an error out for any error that occurs.
 @return a Test Operation if successful, nil otherwise.
 */
- (nullable id<FBXCTestOperation>)startTestWithLaunchConfiguration:(FBTestLaunchConfiguration *)testLaunchConfiguration reporter:(nullable id<FBTestManagerTestReporter>)reporter workingDirectory:(nullable NSString *)workingDirectory error:(NSError **)error;

/**
 Runs the specified Application Test.

 @param configuration the configuration to use
 @param reporter the reporter to report to.
 @param error an error out for any error that occurs.
 @return YES if successful, NO otherwise.
 */
- (BOOL)runApplicationTest:(FBApplicationTestConfiguration *)configuration reporter:(id<FBXCTestReporter>)reporter error:(NSError **)error;

@end

/**
 The implementation of the FBSimulatorXCTestCommands instance.
 */
@interface FBSimulatorXCTestCommands : NSObject <FBSimulatorXCTestCommands>

@end

NS_ASSUME_NONNULL_END
