/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import <FBSimulatorControl/FBSimulatorControlConfiguration.h>

@class FBSimulator;
@class FBSimulatorConfiguration;
@class FBSimulatorControl;
@class FBSimulatorControlAssertions;
@class FBSimulatorSession;

/**
 A Test Case that boostraps a FBSimulatorControl instance.
 Should be overridden to provide Integration tests for Simulators.
 */
@interface FBSimulatorControlTestCase : XCTestCase


/**
 Allocates a Simulator with a default configuration.
 */
- (FBSimulator *)allocateSimulator;

/**
 Creates a Session with the default configuration.
 */
- (FBSimulatorSession *)createSession;

/**
 Create a Session with a booted Simulator of the default configuration.
 */
- (FBSimulatorSession *)createBootedSession;

/**
 Create a Session with a booted Simulator with a booted TableSearch app, of the default configuration.
 */
- (FBSimulatorSession *)createBootedSessionWithUserApplication;

/**
 The Per-Test-Case Management Options.
 */
@property (nonatomic, assign, readwrite) FBSimulatorManagementOptions managementOptions;

/**
 A default Simulator Configuration.
 */
@property (nonatomic, strong, readwrite) FBSimulatorConfiguration *simulatorConfiguration;

/**
 The Per-Test-Case Device Set Path.
 */
@property (nonatomic, copy, readwrite) NSString *deviceSetPath;

/**
 The Simulator Control instance that is lazily created from the defaults
 */
@property (nonatomic, strong, readwrite) FBSimulatorControl *control;

/**
 The FBSimulatorControlAssertions instance
 */
@property (nonatomic, strong, readonly) FBSimulatorControlAssertions *assert;

@end
