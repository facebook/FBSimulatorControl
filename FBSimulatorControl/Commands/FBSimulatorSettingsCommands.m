/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSimulatorSettingsCommands.h"

#import <CoreSimulator/SimDevice.h>

#import <FBControlCore/FBControlCore.h>

#import "FBSimulator.h"
#import "FBSimulatorError.h"
#import "FBSimulatorBootConfiguration.h"
#import "FBDefaultsModificationStrategy.h"

FBiOSTargetActionType const FBiOSTargetActionTypeApproval = @"approve";

@interface FBSimulatorSettingsCommands ()

@property (nonatomic, weak, readonly) FBSimulator *simulator;

@end

@implementation FBSimulatorSettingsCommands

+ (instancetype)commandsWithTarget:(FBSimulator *)target
{
  return [[self alloc] initWithSimulator:target];
}

- (instancetype)initWithSimulator:(FBSimulator *)simulator
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _simulator = simulator;
  return self;
}

- (BOOL)overridingLocalization:(FBLocalizationOverride *)localizationOverride error:(NSError **)error
{
  if (!localizationOverride) {
    return YES;
  }

  return [[FBLocalizationDefaultsModificationStrategy
    strategyWithSimulator:self.simulator]
    overrideLocalization:localizationOverride error:error];
}

- (BOOL)authorizeLocationSettings:(NSArray<NSString *> *)bundleIDs error:(NSError **)error
{
  return [[FBLocationServicesModificationStrategy
    strategyWithSimulator:self.simulator]
    approveLocationServicesForBundleIDs:bundleIDs error:error];
}

- (BOOL)overrideWatchDogTimerForApplications:(NSArray<NSString *> *)bundleIDs withTimeout:(NSTimeInterval)timeout error:(NSError **)error
{
  return [[FBWatchdogOverrideModificationStrategy
    strategyWithSimulator:self.simulator]
    overrideWatchDogTimerForApplications:bundleIDs timeout:timeout error:error];
}

- (FBFuture<NSNull *> *)grantAccess:(NSSet<NSString *> *)bundleIDs toServices:(NSSet<FBSettingsApprovalService> *)services
{
  // We need at least one approval in the array.
  NSParameterAssert(services.count >= 1);

  // Composing different futures due to differences in how these operate.
  NSMutableArray<FBFuture<NSNull *> *> *futures = [NSMutableArray array];
  if ([[NSSet setWithArray:FBSimulatorSettingsCommands.tccDatabaseMapping.allKeys] intersectsSet:services]) {
    [futures addObject:[self modifyTCCDatabaseWithBundleIDs:bundleIDs toServices:services]];
  }
  if ([services containsObject:FBSettingsApprovalServiceLocation]) {
    NSError *error = nil;
    if (![self authorizeLocationSettings:bundleIDs.allObjects error:&error]) {
      return [FBFuture futureWithError:error];
    }
    [futures addObject:[FBFuture futureWithResult:NSNull.null]];
  }
  // Don't wrap if there's only one future.
  if (futures.count == 0) {
    return futures.firstObject;
  }
  return [FBFuture futureWithFutures:futures];
}

- (BOOL)setupKeyboardWithError:(NSError **)error
{
  return [[FBKeyboardSettingsModificationStrategy
    strategyWithSimulator:self.simulator]
    setupKeyboardWithError:error];
}

#pragma mark Private

- (FBFuture<NSNull *> *)modifyTCCDatabaseWithBundleIDs:(NSSet<NSString *> *)bundleIDs toServices:(NSSet<FBSettingsApprovalService> *)services
{
  NSString *filePath = [self.simulator.dataDirectory stringByAppendingPathComponent:@"Library/TCC/TCC.db"];
  if (!filePath) {
    return [[FBSimulatorError
      describeFormat:@"Expected file to exist at path %@ but it was not there", filePath]
      failFuture];
  }
  NSArray<NSString *> *arguments = @[
    filePath,
    [NSString stringWithFormat:@"INSERT or REPLACE INTO access VALUES %@", [FBSimulatorSettingsCommands buildRowsForBundleIDs:bundleIDs services:services]],
  ];
  return [[[FBTaskBuilder
    withLaunchPath:@"/usr/bin/sqlite3" arguments:arguments]
    buildFuture]
    onQueue:self.simulator.asyncQueue map:^(FBTask *_) {
      return NSNull.null;
    }];
}

#pragma mark Private

+ (NSDictionary<FBSettingsApprovalService, NSString *> *)tccDatabaseMapping
{
  static dispatch_once_t onceToken;
  static NSDictionary<FBSettingsApprovalService, NSString *> *mapping;
  dispatch_once(&onceToken, ^{
    mapping = @{
      FBSettingsApprovalServiceContacts: @"kTCCServiceAddressBook",
      FBSettingsApprovalServicePhotos: @"kTCCServicePhotos",
      FBSettingsApprovalServiceCamera: @"kTCCServiceCamera",
    };
  });
  return mapping;
}

+ (NSSet<FBSettingsApprovalService> *)filteredTCCApprovals:(NSSet<FBSettingsApprovalService> *)approvals
{
  NSMutableSet<FBSettingsApprovalService> *filtered = [NSMutableSet setWithSet:approvals];
  [filtered intersectSet:[NSSet setWithArray:self.tccDatabaseMapping.allKeys]];
  return [filtered copy];
}

+ (NSString *)buildRowsForBundleIDs:(NSSet<NSString *> *)bundleIDs services:(NSSet<FBSettingsApprovalService> *)services
{
  NSParameterAssert(bundleIDs.count >= 1);
  NSParameterAssert(services.count >= 1);
  NSMutableArray<NSString *> *tuples = [NSMutableArray array];
  for (NSString *bundleID in bundleIDs) {
    for (FBSettingsApprovalService service in [self filteredTCCApprovals:services]) {
      NSString *serviceName = self.tccDatabaseMapping[service];
      [tuples addObject:[NSString stringWithFormat:@"('%@', '%@', 0, 1, 0, 0, 0)", serviceName, bundleID]];
    }
  }
  return [tuples componentsJoinedByString:@", "];
}

@end

@implementation FBSettingsApproval (FBiOSTargetAction)

+ (FBiOSTargetActionType)actionType
{
  return FBiOSTargetActionTypeApproval;
}

- (BOOL)runWithTarget:(id<FBiOSTarget>)target delegate:(id<FBiOSTargetActionDelegate>)delegate error:(NSError **)error
{
  id<FBSimulatorSettingsCommands> commands = (id<FBSimulatorSettingsCommands>) target;
  if (![target conformsToProtocol:@protocol(FBSimulatorSettingsCommands)]) {
    return [[FBControlCoreError
      describeFormat:@"%@ does not conform to FBSimulatorSettingsCommands", target]
      failBool:error];
  }
  return [[commands grantAccess:[NSSet setWithArray:self.bundleIDs] toServices:[NSSet setWithArray:self.services]] await:error] != nil;
}

@end
