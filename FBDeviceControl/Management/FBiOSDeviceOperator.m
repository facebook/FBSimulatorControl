/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBiOSDeviceOperator.h"

#import <objc/runtime.h>

#import <DTDeviceKitBase/DTDKRemoteDeviceConsoleController.h>
#import <DTDeviceKitBase/DTDKRemoteDeviceToken.h>

#import <DTXConnectionServices/DTXChannel.h>
#import <DTXConnectionServices/DTXMessage.h>
#import <DTXConnectionServices/DTXSocketTransport.h>

#import <DVTFoundation/DVTDeviceManager.h>
#import <DVTFoundation/DVTFuture.h>

#import <IDEiOSSupportCore/DVTiOSDevice.h>

#import <FBControlCore/FBControlCore.h>

#import <XCTestBootstrap/XCTestBootstrap.h>

#import <objc/runtime.h>

#import "FBDevice.h"
#import "FBDevice+Private.h"
#import "FBDeviceSet.h"
#import "FBDeviceControlError.h"
#import "FBAMDevice+Private.h"
#import "FBDeviceControlError.h"
#import "FBDeviceControlFrameworkLoader.h"

#import <FBControlCore/FBControlCore.h>

@protocol DVTApplication <NSObject>
- (NSString *)installedPath;
- (NSString *)containerPath;
- (NSString *)identifier;
- (NSString *)executableName;
@end

@interface FBiOSDeviceOperator ()

@property (nonatomic, strong, readonly) FBDevice *device;

// The DVTDevice corresponding to the receiver.
@property (nonatomic, nullable, strong, readonly) DVTiOSDevice *dvtDevice;

@end

@implementation FBiOSDeviceOperator

@synthesize dvtDevice = _dvtDevice;
- (DVTiOSDevice *)dvtDevice
{
  if (_dvtDevice == nil) {
    _dvtDevice = [self dvtDeviceWithUDID:self.udid];
  }
  return _dvtDevice;
}

+ (instancetype)forDevice:(FBDevice *)device
{
  return [[self alloc] initWithDevice:device];
}

- (instancetype)initWithDevice:(FBDevice *)device;
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _device = device;

  return self;
}

- (NSString *)udid
{
  return self.device.udid;
}

#pragma mark - Device specific operations

- (NSString *)containerPathForApplicationWithBundleID:(NSString *)bundleID error:(NSError **)error
{
  id<DVTApplication> app = [self installedApplicationWithBundleIdentifier:bundleID];
  return [app containerPath];
}

- (NSString *)applicationPathForApplicationWithBundleID:(NSString *)bundleID error:(NSError **)error
{
  id<DVTApplication> app = [self installedApplicationWithBundleIdentifier:bundleID];
  return [app installedPath];
}

- (void)fetchApplications
{
  if (!self.dvtDevice.applications) {
    [FBRunLoopSpinner spinUntilBlockFinished:^id{
      DVTFuture *future = self.dvtDevice.token.fetchApplications;
      [future waitUntilFinished];
      return nil;
    }];
  }
}

- (id<DVTApplication>)installedApplicationWithBundleIdentifier:(NSString *)bundleID
{
  [self fetchApplications];
  return [self.dvtDevice installedApplicationWithBundleIdentifier:bundleID];
}

- (FBProductBundle *)applicationBundleWithBundleID:(NSString *)bundleID error:(NSError **)error
{
  id<DVTApplication> application = [self installedApplicationWithBundleIdentifier:bundleID];
  if (!application) {
    return nil;
  }

  FBProductBundle *productBundle =
  [[[[[FBProductBundleBuilder builder]
      withBundlePath:[application installedPath]]
     withBundleID:[application identifier]]
    withBinaryName:[application executableName]]
   buildWithError:error];

  return productBundle;
}

- (BOOL)uploadApplicationDataAtPath:(NSString *)path bundleID:(NSString *)bundleID error:(NSError **)error
{
  __block NSError *innerError = nil;
  BOOL result = [[FBRunLoopSpinner spinUntilBlockFinished:^id{
    return @([self.dvtDevice uploadApplicationDataWithPath:path forInstalledApplicationWithBundleIdentifier:bundleID error:&innerError]);
  }] boolValue];
  *error = innerError;
  return result;
}

- (BOOL)cleanApplicationStateWithBundleIdentifier:(NSString *)bundleIdentifier error:(NSError **)error
{
  id returnObject =
  [FBRunLoopSpinner spinUntilBlockFinished:^id{
    if ([self.dvtDevice installedApplicationWithBundleIdentifier:bundleIdentifier]) {
      return [self.dvtDevice uninstallApplicationWithBundleIdentifierSync:bundleIdentifier];
    }
    return nil;
  }];
  if ([returnObject isKindOfClass:NSError.class]) {
    if (error != nil) {
      *error = returnObject;
    }
    return NO;
  }
  return YES;
}

#pragma mark - DVTDevice support

- (nullable DVTiOSDevice *)dvtDeviceWithUDID:(NSString *)udid
{
  [self primeDVTDeviceManager];
  NSDictionary<NSString *, DVTiOSDevice *> *dvtDevices = [[self class] keyDVTDevicesByUDID:[objc_lookUpClass("DVTiOSDevice") alliOSDevices]];
  return dvtDevices[udid];
}

+ (NSDictionary<NSString *, DVTiOSDevice *> *)keyDVTDevicesByUDID:(NSArray<DVTiOSDevice *> *)devices
{
  NSMutableDictionary<NSString *, DVTiOSDevice *> *dictionary = [NSMutableDictionary dictionary];
  for (DVTiOSDevice *device in devices) {
    dictionary[device.identifier] = device;
  }
  return [dictionary copy];
}

static const NSTimeInterval FBiOSDeviceOperatorDVTDeviceManagerTickleTime = 2;
- (void)primeDVTDeviceManager
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    // It seems that searching for a device that does not exist will cause all available devices/simulators etc. to be cached.
    // There's probably a better way of fetching all the available devices, but this appears to work well enough.
    // This means that all the cached available devices can then be found.
    [FBDeviceControlFrameworkLoader.xcodeFrameworks loadPrivateFrameworksOrAbort];

    DVTDeviceManager *deviceManager = [objc_lookUpClass("DVTDeviceManager") defaultDeviceManager];
    [deviceManager searchForDevicesWithType:nil options:@{@"id" : @"I_DONT_EXIST_AT_ALL"} timeout:FBiOSDeviceOperatorDVTDeviceManagerTickleTime error:nil];
  });
}

#pragma mark - FBDeviceOperator protocol

- (DTXTransport *)makeTransportForTestManagerServiceWithLogger:(id<FBControlCoreLogger>)logger error:(NSError **)error
{
  if ([NSThread isMainThread]) {
    return
    [[[FBDeviceControlError
       describe:@"'makeTransportForTestManagerService' method may block and should not be called on the main thread"]
      logger:logger]
     fail:error];
  }
  NSError *innerError;
  CFTypeRef connection = [self.device.amDevice startTestManagerServiceWithError:&innerError];
  if (!connection) {
    return
    [[[[FBDeviceControlError
        describe:@"Failed to start test manager daemon service."]
       logger:logger]
      causedBy:innerError]
     fail:error];
  }
  int socket = FBAMDServiceConnectionGetSocket(connection);
  if (socket <= 0) {
    return
    [[[FBDeviceControlError
       describe:@"Invalid socket returned from AMDServiceConnectionGetSocket"]
      logger:logger]
     fail:error];
  }
  return
  [[objc_lookUpClass("DTXSocketTransport") alloc] initWithConnectedSocket:socket disconnectAction:^{
    [logger log:@"Disconnected from test manager daemon socket"];
    FBAMDServiceConnectionInvalidate(connection);
  }];
}

- (BOOL)requiresTestDaemonMediationForTestHostConnection
{
  return self.dvtDevice.requiresTestDaemonMediationForTestHostConnection;
}

- (BOOL)waitForDeviceToBecomeAvailableWithError:(NSError **)error
{
  if (![[[[[FBRunLoopSpinner new]
           timeout:5 * 60]
          timeoutErrorMessage:@"Device was locked"]
         reminderMessage:@"Please unlock device!"]
        spinUntilTrue:^BOOL{ return ![self.dvtDevice isPasscodeLocked]; } error:error])
  {
    return NO;
  }

  if (![[[[[FBRunLoopSpinner new]
           timeout:5 * 60]
          timeoutErrorMessage:@"Device did not become available"]
         reminderMessage:@"Waiting for device to become available!"]
        spinUntilTrue:^BOOL{ return [self.dvtDevice isAvailable]; }])
  {
    return NO;
  }

  if (![[[[[FBRunLoopSpinner new]
           timeout:5 * 60]
          timeoutErrorMessage:@"Failed to gain access to device"]
         reminderMessage:@"Allow device access!"]
        spinUntilTrue:^BOOL{ return [self.dvtDevice deviceReady]; } error:error])
  {
    return NO;
  }

  __block NSUInteger preLaunchLogLength;
  __block NSString *preLaunchConsoleString;
  if (![[[[FBRunLoopSpinner new]
          timeout:60]
         timeoutErrorMessage:@"Failed to load device console entries"]
        spinUntilTrue:^BOOL{
          NSString *log = self.consoleString.copy;
          if (log.length == 0) {
            return NO;
          }
          // Waiting for console to load all entries
          if (log.length != preLaunchLogLength) {
            preLaunchLogLength = log.length;
            return NO;
          }
          preLaunchConsoleString = log;
          return YES;
        } error:error])
  {
    return NO;
  }

  if (!self.dvtDevice.supportsXPCServiceDebugging) {
    return [[FBDeviceControlError
      describe:@"Device does not support XPC service debugging"]
      failBool:error];
  }

  if (!self.dvtDevice.serviceHubProcessControlChannel) {
    return [[FBDeviceControlError
      describe:@"Failed to create HUB control channel"]
      failBool:error];
  }
  return YES;
}

- (pid_t)processIDWithBundleID:(NSString *)bundleID error:(NSError **)error
{
  return
  [[self executeHubProcessControlSelector:NSSelectorFromString(@"processIdentifierForBundleIdentifier:")
                                    error:error
                                arguments:bundleID, nil]
   intValue];
}

- (nullable FBDiagnostic *)attemptToFindCrashLogForProcess:(pid_t)pid bundleID:(NSString *)bundleID sinceDate:(NSDate *)date
{
  return nil;
}

- (NSString *)consoleString
{
  return [self.dvtDevice.token.deviceConsoleController consoleString];
}

- (BOOL)observeProcessWithID:(NSInteger)processID error:(NSError **)error
{
  NSAssert(error, @"error is required for hub commands");
  [self executeHubProcessControlSelector:NSSelectorFromString(@"startObservingPid:")
                                   error:error
                               arguments:@(processID), nil];
  return (*error == nil);
}

- (BOOL)killProcessWithID:(NSInteger)processID error:(NSError **)error
{
  NSAssert(error, @"error is required for hub commands");
  [self executeHubProcessControlSelector:NSSelectorFromString(@"killPid:")
                                   error:error
                               arguments:@(processID), nil];
  return (*error == nil);
}

- (NSArray<NSDictionary<NSString *, id> *> *)installedApplicationsData
{
  NSMutableArray *applications = [[NSMutableArray alloc] init];

  __block CFDictionaryRef cf_apps;

  NSNumber *return_code = [self.device.amDevice handleWithBlockDeviceSession:^id(CFTypeRef device) {
    return @(FBAMDeviceLookupApplications(device, 0, &cf_apps));
  } error: nil];

  NSDictionary *apps = CFBridgingRelease(cf_apps);

  if (return_code == nil || [return_code intValue] != 0) {
    return
    [[FBDeviceControlError
      describe:@"Failed to get list of applications"]
     fail:nil];
  }

  [applications addObjectsFromArray:[apps allValues]];

  return applications;
}

#pragma mark FBApplicationCommands Implementation

- (BOOL)isApplicationInstalledWithBundleID:(NSString *)bundleID error:(NSError **)error
{
  return [self installedApplicationWithBundleIdentifier:bundleID] != nil;
}

- (BOOL)launchApplication:(FBApplicationLaunchConfiguration *)configuration error:(NSError **)error
{
  NSAssert(error, @"error is required for hub commands");
  NSString *remotePath = [self applicationPathForApplicationWithBundleID:configuration.bundleID error:error];
  NSDictionary *options = @{@"StartSuspendedKey" : @NO};
  SEL aSelector = NSSelectorFromString(@"launchSuspendedProcessWithDevicePath:bundleIdentifier:environment:arguments:options:");
  NSNumber *PID =
  [self executeHubProcessControlSelector:aSelector
                                   error:error
                               arguments:remotePath, configuration.bundleID, configuration.environment, configuration.arguments, options, nil];
  if (!PID) {
    return NO;
  }
  __block NSError *innerError = nil;
  dispatch_async(dispatch_get_main_queue(), ^{
    [self observeProcessWithID:PID.integerValue error:&innerError];
  });
  *error = innerError;
  return YES;
}

- (BOOL)killApplicationWithBundleID:(NSString *)bundleID error:(NSError **)error
{
  pid_t PID = [self processIDWithBundleID:bundleID error:error];
  if (PID < 1) {
    return NO;
  }
  return [self killProcessWithID:PID error:error];
}

- (nullable NSArray<FBInstalledApplication *> *)installedApplicationsWithError:(NSError **)error
{
  NSMutableArray<FBInstalledApplication *> *installedApplications = [[NSMutableArray alloc] init];

  for (NSDictionary *app in [self installedApplicationsData]) {
    if (app == nil) {
      continue;
    }
    FBApplicationBundle *bundle = [FBApplicationBundle
      applicationWithName:[app valueForKey:FBApplicationInstallInfoKeyBundleName] ?: @""
      path:[app valueForKey:FBApplicationInstallInfoKeyPath] ?: @""
      bundleID:app[FBApplicationInstallInfoKeyBundleIdentifier]];
    FBInstalledApplication *application = [FBInstalledApplication
      installedApplicationWithBundle:bundle
      installType:[FBInstalledApplication installTypeFromString:
                   [app valueForKey:FBApplicationInstallInfoKeyApplicationType] ?: @""]];

    [installedApplications addObject:application];
  }

  return [installedApplications copy];
}

#pragma mark - Helpers

- (id)executeHubProcessControlSelector:(SEL)aSelector
                                 error:(NSError *_Nullable *)error
                             arguments:(id)arg, ...
{
  va_list _arguments;
  va_start(_arguments, arg);
  va_list *arguments = &_arguments;

  __block NSError *innerError = nil;
  id result = [FBRunLoopSpinner spinUntilBlockFinished:^id{
    __block id responseObject;

    DTXChannel *channel = self.dvtDevice.serviceHubProcessControlChannel;
    DTXMessage *message = [[objc_lookUpClass("DTXMessage") alloc] initWithSelector:aSelector firstArg:arg remainingObjectArgs:(__bridge id)(*arguments)];
    [channel sendControlSync:message replyHandler:^(DTXMessage *responseMessage){
      if (responseMessage.errorStatus) {
        innerError = responseMessage.error;
        return;
      }
      responseObject = responseMessage.object;
    }];
    return responseObject;
  }];
  va_end(_arguments);
  if (error) {
    *error = innerError;
  }
  return result;
}

@end
