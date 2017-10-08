/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSimulatorControlFrameworkLoader.h"

#import <FBControlCore/FBControlCore.h>

#import <CoreSimulator/NSUserDefaults-SimDefaults.h>

@interface FBSimulatorControlFrameworkLoader_Essential : FBSimulatorControlFrameworkLoader

@end

@implementation FBSimulatorControlFrameworkLoader

#pragma mark Initializers

+ (FBSimulatorControlFrameworkLoader *)essentialFrameworks
{
  static dispatch_once_t onceToken;
  static FBSimulatorControlFrameworkLoader *loader;
  dispatch_once(&onceToken, ^{
    loader = [FBSimulatorControlFrameworkLoader loaderWithName:@"FBSimulatorControl" frameworks:@[
      FBWeakFramework.CoreSimulator,
    ]];
  });
  return loader;
}

+ (FBSimulatorControlFrameworkLoader *)xcodeFrameworks
{
  static dispatch_once_t onceToken;
  static FBSimulatorControlFrameworkLoader *loader;
  dispatch_once(&onceToken, ^{
    loader = [FBSimulatorControlFrameworkLoader loaderWithName:@"FBSimulatorControl" frameworks:@[
      FBWeakFramework.SimulatorKit,
    ]];
  });
  return loader;
}

@end

@implementation FBSimulatorControlFrameworkLoader_Essential

#pragma mark Public Methods

- (BOOL)loadPrivateFrameworks:(nullable id<FBControlCoreLogger>)logger error:(NSError **)error
{
  if (self.hasLoadedFrameworks) {
    return YES;
  }
  BOOL loaded = [super loadPrivateFrameworks:logger error:error];
  if (loaded) {
    // Set CoreSimulator Logging since it is now loaded.
    [FBSimulatorControlFrameworkLoader_Essential setCoreSimulatorLoggingEnabled:FBControlCoreGlobalConfiguration.debugLoggingEnabled];
  }
  return loaded;
}

#pragma mark Private Methods

+ (void)setCoreSimulatorLoggingEnabled:(BOOL)enabled
{
  if (![NSUserDefaults instancesRespondToSelector:@selector(simulatorDefaults)]) {
    return;
  }
  NSUserDefaults *simulatorDefaults = [NSUserDefaults simulatorDefaults];
  [simulatorDefaults setBool:enabled forKey:@"DebugLogging"];
}

@end

