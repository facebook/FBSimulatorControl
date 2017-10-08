/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import <FBControlCore/FBControlCore.h>

NS_ASSUME_NONNULL_BEGIN

@class FBAgentLaunchConfiguration;
@class FBSimulator;
@class FBSimulatorAgentOperation;

/**
 Commands relating to the launching of Agents on a Simulator.
 */
@protocol FBSimulatorAgentCommands <NSObject, FBiOSTargetCommand>

/**
 Launches the provided Agent with the given Configuration.

 @param agentLaunch the Agent Launch Configuration to Launch.
 @param error an error out, for any error that occurs.
 @return YES if the command succeeds, NO otherwise,
 */
- (nullable FBSimulatorAgentOperation *)launchAgent:(FBAgentLaunchConfiguration *)agentLaunch error:(NSError **)error;

@end

/**
 An Implementation of FBSimulatorAgentCommands.
 */
@interface FBSimulatorAgentCommands : NSObject <FBSimulatorAgentCommands>

@end

NS_ASSUME_NONNULL_END
