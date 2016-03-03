/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSimulatorInteraction.h"
#import "FBSimulatorInteraction+Private.h"

#import <CoreSimulator/SimDevice.h>

#import "FBCollectionDescriptions.h"
#import "FBProcessLaunchConfiguration.h"
#import "FBProcessQuery+Simulators.h"
#import "FBSimulator+Helpers.h"
#import "FBSimulator.h"
#import "FBSimulatorApplication.h"
#import "FBSimulatorConfiguration+CoreSimulator.h"
#import "FBSimulatorConfiguration.h"
#import "FBSimulatorControl.h"
#import "FBSimulatorControlConfiguration.h"
#import "FBSimulatorControlGlobalConfiguration.h"
#import "FBSimulatorError.h"
#import "FBSimulatorEventSink.h"
#import "FBSimulatorPool.h"
#import "FBSimulatorTerminationStrategy.h"
#import "FBTaskExecutor.h"

@implementation FBSimulatorInteraction

#pragma mark Initializers

+ (instancetype)withSimulator:(FBSimulator *)simulator
{
  return [[self alloc] initWithInteraction:nil simulator:simulator];
}

- (instancetype)initWithInteraction:(id<FBInteraction>)interaction simulator:(FBSimulator *)simulator
{
  self = [super initWithInteraction:interaction];
  if (!self) {
    return nil;
  }

  _simulator = simulator;
  return self;
}

#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
  FBSimulatorInteraction *interaction = [super copyWithZone:zone];
  interaction->_simulator = self.simulator;
  return self;
}

#pragma mark Private

- (instancetype)interactWithSimulator:(BOOL (^)(id interaction, NSError **error, FBSimulator *simulator))block
{
  return [self interact:^ BOOL (NSError **error, FBSimulatorInteraction *interaction) {
    return block(interaction, error, interaction.simulator);
  }];
}

- (instancetype)interactWithSimulatorAtState:(FBSimulatorState)state block:(BOOL (^)(id interaction, NSError **error, FBSimulator *simulator))block
{
  return [self interactWithSimulator:^ BOOL (id interaction, NSError **error, FBSimulator *simulator) {
    if (simulator.state != state) {
      return [[[FBSimulatorError
        describeFormat:@"Expected Simulator %@ to be %@, but it was '%@'", simulator.udid, [FBSimulator stateStringFromSimulatorState:state], simulator.stateString]
        inSimulator:simulator]
        failBool:error];
    }
    return block(interaction, error, simulator);
  }];
}

- (instancetype)interactWithShutdownSimulator:(BOOL (^)(id interaction, NSError **error, FBSimulator *simulator))block
{
  return [self interactWithSimulatorAtState:FBSimulatorStateShutdown block:block];
}

- (instancetype)interactWithBootedSimulator:(BOOL (^)(id interaction, NSError **error, FBSimulator *simulator))block
{
  return [self interactWithSimulatorAtState:FBSimulatorStateBooted block:block];
}

- (instancetype)binary:(FBSimulatorBinary *)binary interact:(BOOL (^)(id interaction, NSError **error, FBSimulator *simulator, FBProcessInfo *process))block
{
  NSParameterAssert(binary);
  NSParameterAssert(block);

  return [self interactWithBootedSimulator:^ BOOL (id interaction, NSError **error, FBSimulator *simulator) {
    FBProcessInfo *processInfo = [[[simulator
      launchdSimSubprocesses]
      filteredArrayUsingPredicate:[FBProcessQuery processesForBinary:binary]]
      firstObject];

    if (!processInfo) {
      return [[[FBSimulatorError describeFormat:@"Could not find an active process for %@", binary] inSimulator:simulator] failBool:error];
    }
    return block(interaction, error, simulator, processInfo);
  }];
}

@end
