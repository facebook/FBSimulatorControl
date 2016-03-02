/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import <FBSimulatorControl/FBDebugDescribeable.h>
#import <FBSimulatorControl/FBJSONSerializationDescribeable.h>

@class FBProcessQuery;
@class FBSimulator;
@class FBSimulatorConfiguration;
@class FBSimulatorControl;
@class FBSimulatorControlConfiguration;
@class SimDeviceSet;
@protocol FBSimulatorLogger;

/**
 Complements SimDeviceSet with additional functionality and more resiliant behaviours.
 Performs the preconditions necessary to call certain SimDeviceSet/SimDevice methods.
 */
@interface FBSimulatorSet : NSObject <FBDebugDescribeable, FBJSONSerializationDescribeable>

/**
 Creates and returns an FBSimulatorSet, performing the preconditions defined in the configuration.

 @param configuration the configuration to use. Must not be nil.
 @param logger the logger to use to verbosely describe what is going on. May be nil.
 @param error any error that occurred during the creation of the pool.
 @returns a new FBSimulatorPool.
 */
+ (instancetype)setWithConfiguration:(FBSimulatorControlConfiguration *)configuration control:(FBSimulatorControl *)control logger:(id<FBSimulatorLogger>)logger error:(NSError **)error;

/**
 Creates and returns a FBSimulator fbased on a configuration.

 @param configuration the Configuration of the Device to Allocate. Must not be nil.
 @param error an error out for any error that occured.
 @return a FBSimulator if one could be allocated with the provided options, nil otherwise
 */
- (FBSimulator *)createSimulatorWithConfiguration:(FBSimulatorConfiguration *)configuration error:(NSError **)error;

/**
 Deletes a Simulator in the Set.
 The Set to which the Simulator belongs must be the reciever.

 @param simulator the Simulator to delete. Must not be nil.
 @param error an error out for any error that occurs.
 @return an array of the Simulators that this were killed if successful, nil otherwise.
 */
- (BOOL)deleteSimulator:(FBSimulator *)simulator error:(NSError **)error;

/**
 Kills a Simulator in the Set.
 The Set to which the Simulator belongs must be the reciever.

 @param simulator the Simulator to delete. Must not be nil.
 @param error an error out for any error that occurs.
 @return an array of the Simulators that this were killed if successful, nil otherwise.
 */
- (BOOL)killSimulator:(FBSimulator *)simulator error:(NSError **)error;

/**
 Kills all of the Simulators the reciever's Device Set.

 @param error an error out if any error occured.
 @return an array of the Simulators that this were killed if successful, nil otherwise.
 */
- (NSArray *)killAllWithError:(NSError **)error;

/**
 Delete all of the Simulators Managed by this Pool, killing them first.

 @param error an error out if any error occured.
 @return an Array of the names of the Simulators that were deleted if successful, nil otherwise.
 */
- (NSArray *)deleteAllWithError:(NSError **)error;

/**
 Fetches a Simulator from the Set with the Provided UDID.
 
 @param udid the UDID of the Simulator to obtain.
 @return A FBSimulator instance or nil if one could not be obtained.
 */
- (FBSimulator *)simulatorWithUDID:(NSString *)udid;

/**
 The Logger to use.
 */
@property (nonatomic, strong, readonly) id<FBSimulatorLogger> logger;

/**
 Returns the configuration for the reciever.
 */
@property (nonatomic, copy, readonly) FBSimulatorControlConfiguration *configuration;

/**
 The FBSimulatorControl Instance to which the Set Belongs.
 */
@property (nonatomic, weak, readonly) FBSimulatorControl *control;

/**
 The SimDeviceSet to that is owned by the reciever.
 */
@property (nonatomic, strong, readonly) SimDeviceSet *deviceSet;

/**
 The FBProcessQuery that is used to obtain Simulator Process Information.
 */
@property (nonatomic, strong, readonly) FBProcessQuery *processQuery;

/**
 An NSArray<FBSimulator> of all Simulators in the Set.
*/
@property (nonatomic, copy, readonly) NSArray *allSimulators;

@end
