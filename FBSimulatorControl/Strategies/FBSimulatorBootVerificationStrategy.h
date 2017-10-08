/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FBSimulator;

/**
 A Strategy for determining that a Simulator is actually usable after it is booted.
 In some circumstances it will take some time for a Simulator to be usable for standard operations.
 This can be for a variety of reasons, but represents the time take for a Simulator to boot to the OS.
 In particular, the first boot of a Simulator after creation can take some time during the run of datamigrator.
 */
@interface FBSimulatorBootVerificationStrategy : NSObject

#pragma mark Initializers

/**
 The Designated Initializer.

 @param simulator the Simulator.
 @return a Boot Verification Strategy.
 */
+ (instancetype)strategyWithSimulator:(FBSimulator *)simulator;

#pragma mark Public Methods.

/**
 Verifies that the Simulator is booted.
 This can be called as soon as a Simulator enters the 'Booted' state.
 It can also be called on a Simulator after it has been booted for some time
 as a means of verifying the Simulator is in a known-good state.

 @param error an error out for any error that occurs.
 @return YES if successful, NO otherwise.
 */
- (BOOL)verifySimulatorIsBooted:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
