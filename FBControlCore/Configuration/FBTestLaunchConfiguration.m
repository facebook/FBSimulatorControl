/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTestLaunchConfiguration.h"

#import <FBControlCore/FBControlCore.h>

@implementation FBTestLaunchConfiguration

- (instancetype)initWithTestBundlePath:(NSString *)testBundlePath applicationLaunchConfiguration:(FBApplicationLaunchConfiguration *)applicationLaunchConfiguration testHostPath:(NSString *)testHostPath timeout:(NSTimeInterval)timeout initializeUITesting:(BOOL)initializeUITesting testsToRun:(NSSet<NSString *> *)testsToRun testsToSkip:(NSSet<NSString *> *)testsToSkip targetApplicationPath:(NSString *)targetApplicationPath targetApplicationBundleID:(NSString *)targetApplicaitonBundleID xcTestRunProperties:(NSDictionary *)xcTestRunProperties resultBundlePath:(NSString *)resultBundlePath
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _testBundlePath = testBundlePath;
  _applicationLaunchConfiguration = applicationLaunchConfiguration;
  _testHostPath = testHostPath;
  _timeout = timeout;
  _shouldInitializeUITesting = initializeUITesting;
  _testsToRun = testsToRun;
  _testsToSkip = testsToSkip;
  _targetApplicationPath = targetApplicationPath;
  _targetApplicationBundleID = targetApplicaitonBundleID;
  _xcTestRunProperties = xcTestRunProperties;
  _resultBundlePath = resultBundlePath;

  return self;
}

+ (instancetype)configurationWithTestBundlePath:(NSString *)testBundlePath
{
  NSParameterAssert(testBundlePath);
  return [[FBTestLaunchConfiguration alloc]
    initWithTestBundlePath:testBundlePath
    applicationLaunchConfiguration:nil
    testHostPath:nil
    timeout:0
    initializeUITesting:NO
    testsToRun:nil
    testsToSkip:[NSSet set]
    targetApplicationPath:nil
    targetApplicationBundleID:nil
    xcTestRunProperties:nil
    resultBundlePath:nil];
}

- (instancetype)withApplicationLaunchConfiguration:(FBApplicationLaunchConfiguration *)applicationLaunchConfiguration
{
  return [[FBTestLaunchConfiguration alloc]
    initWithTestBundlePath:self.testBundlePath
    applicationLaunchConfiguration:applicationLaunchConfiguration
    testHostPath:self.testHostPath
    timeout:self.timeout
    initializeUITesting:self.shouldInitializeUITesting
    testsToRun:self.testsToRun
    testsToSkip:self.testsToSkip
    targetApplicationPath:self.targetApplicationPath
    targetApplicationBundleID:self.targetApplicationBundleID
    xcTestRunProperties: self.xcTestRunProperties
    resultBundlePath:self.resultBundlePath];
}

- (instancetype)withTestHostPath:(NSString *)testHostPath
{
  return [[FBTestLaunchConfiguration alloc]
    initWithTestBundlePath:self.testBundlePath
    applicationLaunchConfiguration:self.applicationLaunchConfiguration
    testHostPath:testHostPath
    timeout:self.timeout
    initializeUITesting:self.shouldInitializeUITesting
    testsToRun:self.testsToRun
    testsToSkip:self.testsToSkip
    targetApplicationPath:self.targetApplicationPath
    targetApplicationBundleID:self.targetApplicationBundleID
    xcTestRunProperties: self.xcTestRunProperties
    resultBundlePath:self.resultBundlePath];

}

- (instancetype)withTimeout:(NSTimeInterval)timeout
{
  return [[FBTestLaunchConfiguration alloc]
    initWithTestBundlePath:self.testBundlePath
    applicationLaunchConfiguration:self.applicationLaunchConfiguration
    testHostPath:self.testHostPath
    timeout:timeout
    initializeUITesting:self.shouldInitializeUITesting
    testsToRun:self.testsToRun
    testsToSkip:self.testsToSkip
    targetApplicationPath:self.targetApplicationPath
    targetApplicationBundleID:self.targetApplicationBundleID
    xcTestRunProperties: self.xcTestRunProperties
    resultBundlePath:self.resultBundlePath];
}

- (instancetype)withUITesting:(BOOL)shouldInitializeUITesting
{
  return [[FBTestLaunchConfiguration alloc]
    initWithTestBundlePath:self.testBundlePath
    applicationLaunchConfiguration:self.applicationLaunchConfiguration
    testHostPath:self.testHostPath
    timeout:self.timeout
    initializeUITesting:shouldInitializeUITesting
    testsToRun:self.testsToRun
    testsToSkip:self.testsToSkip
    targetApplicationPath:self.targetApplicationPath
    targetApplicationBundleID:self.targetApplicationBundleID
    xcTestRunProperties: self.xcTestRunProperties
    resultBundlePath:self.resultBundlePath];
}

- (instancetype)withTestsToRun:(NSSet<NSString *> *)testsToRun
{
  return [[FBTestLaunchConfiguration alloc]
    initWithTestBundlePath:self.testBundlePath
    applicationLaunchConfiguration:self.applicationLaunchConfiguration
    testHostPath:self.testHostPath
    timeout:self.timeout
    initializeUITesting:self.shouldInitializeUITesting
    testsToRun:testsToRun
    testsToSkip:self.testsToSkip
    targetApplicationPath:self.targetApplicationPath
    targetApplicationBundleID:self.targetApplicationBundleID
    xcTestRunProperties: self.xcTestRunProperties
    resultBundlePath:self.resultBundlePath];
}

- (instancetype)withTestsToSkip:(NSSet<NSString *> *)testsToSkip
{
  return [[FBTestLaunchConfiguration alloc]
    initWithTestBundlePath:self.testBundlePath
    applicationLaunchConfiguration:self.applicationLaunchConfiguration
    testHostPath:self.testHostPath
    timeout:self.timeout
    initializeUITesting:self.shouldInitializeUITesting
    testsToRun:self.testsToRun
    testsToSkip:testsToSkip
    targetApplicationPath:self.targetApplicationPath
    targetApplicationBundleID:self.targetApplicationBundleID
    xcTestRunProperties: self.xcTestRunProperties
    resultBundlePath:self.resultBundlePath];
}

- (instancetype)withTargetApplicationPath:(NSString *)targetApplicationPath
{
  return [[FBTestLaunchConfiguration alloc]
          initWithTestBundlePath:self.testBundlePath
          applicationLaunchConfiguration:self.applicationLaunchConfiguration
          testHostPath:self.testHostPath
          timeout:self.timeout
          initializeUITesting:self.shouldInitializeUITesting
          testsToRun:self.testsToRun
          testsToSkip:self.testsToSkip
          targetApplicationPath:targetApplicationPath
          targetApplicationBundleID:self.targetApplicationBundleID
          xcTestRunProperties: self.xcTestRunProperties
          resultBundlePath:self.resultBundlePath];

}

- (instancetype)withTargetApplicationBundleID:(NSString *)targetApplicationBundleID
{
  return [[FBTestLaunchConfiguration alloc]
          initWithTestBundlePath:self.testBundlePath
          applicationLaunchConfiguration:self.applicationLaunchConfiguration
          testHostPath:self.testHostPath
          timeout:self.timeout
          initializeUITesting:self.shouldInitializeUITesting
          testsToRun:self.testsToRun
          testsToSkip:self.testsToSkip
          targetApplicationPath:self.targetApplicationPath
          targetApplicationBundleID:targetApplicationBundleID
          xcTestRunProperties: self.xcTestRunProperties
          resultBundlePath:self.resultBundlePath];
}

- (instancetype)withXCTestRunProperties:(NSDictionary<NSString *, id> *)xcTestRunProperties;
{
  return [[FBTestLaunchConfiguration alloc]
          initWithTestBundlePath:self.testBundlePath
          applicationLaunchConfiguration:self.applicationLaunchConfiguration
          testHostPath:self.testHostPath
          timeout:self.timeout
          initializeUITesting:self.shouldInitializeUITesting
          testsToRun:self.testsToRun
          testsToSkip:self.testsToSkip
          targetApplicationPath:self.targetApplicationPath
          targetApplicationBundleID:self.targetApplicationPath
          xcTestRunProperties: xcTestRunProperties
          resultBundlePath:self.resultBundlePath];
}

- (instancetype)withResultBundlePath:(NSString *)resultBundlePath
{
  return [[FBTestLaunchConfiguration alloc]
          initWithTestBundlePath:self.testBundlePath
          applicationLaunchConfiguration:self.applicationLaunchConfiguration
          testHostPath:self.testHostPath
          timeout:self.timeout
          initializeUITesting:self.shouldInitializeUITesting
          testsToRun:self.testsToRun
          testsToSkip:self.testsToSkip
          targetApplicationPath:self.targetApplicationPath
          targetApplicationBundleID:self.targetApplicationPath
          xcTestRunProperties: self.xcTestRunProperties
          resultBundlePath:resultBundlePath];
}

#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
  return self;
}

#pragma mark NSObject

- (BOOL)isEqual:(FBTestLaunchConfiguration *)configuration
{
  if (![configuration isKindOfClass:self.class]) {
    return NO;
  }

  return (self.testBundlePath == configuration.testBundlePath || [self.testBundlePath isEqualToString:configuration.testBundlePath]) &&
         (self.applicationLaunchConfiguration == configuration.applicationLaunchConfiguration  || [self.applicationLaunchConfiguration isEqual:configuration.applicationLaunchConfiguration]) &&
         (self.testHostPath == configuration.testHostPath || [self.testHostPath isEqualToString:configuration.testHostPath]) &&
         (self.targetApplicationBundleID == configuration.targetApplicationBundleID || [self.targetApplicationBundleID isEqualToString:configuration.targetApplicationBundleID]) &&
         (self.targetApplicationPath == configuration.targetApplicationPath || [self.targetApplicationPath isEqualToString:configuration.targetApplicationPath]) &&
         (self.testsToRun == configuration.testsToRun || [self.testsToRun isEqual:configuration.testsToRun]) &&
         (self.testsToSkip == configuration.testsToSkip || [self.testsToSkip isEqual:configuration.testsToSkip]) &&
         self.timeout == configuration.timeout &&
         self.shouldInitializeUITesting == configuration.shouldInitializeUITesting &&
         (self.xcTestRunProperties == configuration.xcTestRunProperties || [self.xcTestRunProperties isEqual:configuration.xcTestRunProperties]) &&
         (self.resultBundlePath == configuration.resultBundlePath || [self.resultBundlePath isEqual:self.resultBundlePath]);
}

- (NSUInteger)hash
{
  return self.testBundlePath.hash ^ self.applicationLaunchConfiguration.hash ^ self.testHostPath.hash ^ (unsigned long) self.timeout ^ (unsigned long) self.shouldInitializeUITesting ^ self.testsToRun.hash ^ self.testsToSkip.hash ^ self.targetApplicationPath.hash ^ self.targetApplicationBundleID.hash ^ self.xcTestRunProperties.hash ^ self.resultBundlePath.hash;
}

#pragma mark FBDebugDescribeable

- (NSString *)description
{
  return [NSString stringWithFormat:
    @"FBTestLaunchConfiguration TestBundlePath %@ | AppConfig %@ | HostPath %@ | UITesting %d | TestsToRun %@ | TestsToSkip %@ | Target application path %@ | Target application bundle id %@ xcTestRunProperties %@ | ResutltBundlePath %@",
    self.testBundlePath,
    self.applicationLaunchConfiguration,
    self.testHostPath,
    self.shouldInitializeUITesting,
    self.testsToRun,
    self.testsToSkip,
    self.targetApplicationPath,
    self.targetApplicationBundleID,
    self.xcTestRunProperties,
    self.resultBundlePath
  ];
}

- (NSString *)shortDescription
{
  return [self description];
}

- (NSString *)debugDescription
{
  return [self description];
}

#pragma mark FBJSONSerializable

static NSString *const KeyAppLaunch = @"test_app_launch";
static NSString *const KeyBundlePath = @"test_bundle_path";
static NSString *const KeyHostPath = @"test_host_path";
static NSString *const KeyInitializeUITesting = @"ui_testing";
static NSString *const KeyTestsToRun = @"tests_to_run";
static NSString *const KeyTestsToSkip = @"tests_to_skip";
static NSString *const KeyTimeout = @"timeout";
static NSString *const KeyTargetApplicationPath = @"targetApplicationPath";
static NSString *const KeyTargetApplicationBundleID = @"targetApplicationBundleID";
static NSString *const KeyXcTestRunProperties = @"xcTestRunProperties";
static NSString *const KeyResultBundlePath = @"resultBundlePath";

- (NSDictionary *)jsonSerializableRepresentation
{
  return @{
    KeyBundlePath : self.testBundlePath ?: NSNull.null,
    KeyAppLaunch : self.applicationLaunchConfiguration.jsonSerializableRepresentation ?: NSNull.null,
    KeyHostPath : self.testHostPath ?: NSNull.null,
    KeyTimeout : @(self.timeout),
    KeyInitializeUITesting : @(self.shouldInitializeUITesting),
    KeyTestsToRun : self.testsToRun.allObjects ?: NSNull.null,
    KeyTestsToSkip : self.testsToSkip.allObjects ?: NSNull.null,
    KeyTargetApplicationPath : self.targetApplicationPath ?: NSNull.null,
    KeyTargetApplicationBundleID : self.targetApplicationBundleID ?: NSNull.null,
    KeyXcTestRunProperties : self.xcTestRunProperties ?: NSNull.null,
    KeyResultBundlePath : self.resultBundlePath ?: NSNull.null,
  };
}

+ (nullable instancetype)inflateFromJSON:(NSDictionary<NSString *, id> *)json error:(NSError **)error
{
  NSString *targetApplicationPath = [FBCollectionOperations nullableValueForDictionary:json key:KeyTargetApplicationPath];
  if (targetApplicationPath && ![targetApplicationPath isKindOfClass:NSString.class]) {
    return [[FBControlCoreError
      describeFormat:@"%@ is not a String | Null for %@", targetApplicationPath, KeyBundlePath]
      fail:error];
  }
  NSString *targetApplicationBundleID = [FBCollectionOperations nullableValueForDictionary:json key:KeyTargetApplicationBundleID];
  if (targetApplicationBundleID && ![targetApplicationBundleID isKindOfClass:NSString.class]) {
    return [[FBControlCoreError
             describeFormat:@"%@ is not a String | Null for %@", targetApplicationBundleID, KeyBundlePath]
            fail:error];
  }
  NSString *bundlePath = [FBCollectionOperations nullableValueForDictionary:json key:KeyBundlePath];
  if (bundlePath && ![bundlePath isKindOfClass:NSString.class]) {
    return [[FBControlCoreError
             describeFormat:@"%@ is not a String | Null for %@", bundlePath, KeyBundlePath]
            fail:error];
  }
  NSDictionary<NSString *, id> *appLaunchDictionary = [FBCollectionOperations nullableValueForDictionary:json key:KeyAppLaunch];
  FBApplicationLaunchConfiguration *appLaunch = nil;
  if (appLaunchDictionary) {
    appLaunch = [FBApplicationLaunchConfiguration inflateFromJSON:appLaunchDictionary error:error];
    if (!appLaunch) {
      return nil;
    }
  }
  NSString *testHostPath = [FBCollectionOperations nullableValueForDictionary:json key:KeyHostPath];
  if (testHostPath && ![testHostPath isKindOfClass:NSString.class]) {
    return [[FBControlCoreError
      describeFormat:@"%@ is not a String | Null for %@", testHostPath, KeyHostPath]
      fail:error];
  }
  NSNumber *timeoutNumber = [FBCollectionOperations nullableValueForDictionary:json key:KeyTimeout];
  if (timeoutNumber && ![timeoutNumber isKindOfClass:NSNumber.class]) {
    return [[FBControlCoreError
      describeFormat:@"%@ is not a Number | Null for %@", timeoutNumber, KeyTimeout]
      fail:error];
  }
  NSTimeInterval timeout = timeoutNumber ? timeoutNumber.doubleValue : 0;
  NSNumber *initializeUITestingNumber = [FBCollectionOperations nullableValueForDictionary:json key:KeyInitializeUITesting];
  if (initializeUITestingNumber && ![initializeUITestingNumber isKindOfClass:NSNumber.class]) {
    return [[FBControlCoreError
      describeFormat:@"%@ is not a Number | Null for %@", initializeUITestingNumber, KeyInitializeUITesting]
      fail:error];
  }
  BOOL initializeUITesting = initializeUITestingNumber ? initializeUITestingNumber.boolValue : NO;
  NSArray<NSString *> *testsToRunArray = [FBCollectionOperations nullableValueForDictionary:json key:KeyTestsToRun];
  if (testsToRunArray && ![FBCollectionInformation isArrayHeterogeneous:testsToRunArray withClass:NSString.class]) {
    return [[FBControlCoreError
      describeFormat:@"%@ is not a Array<String> | Null for %@", testsToRunArray, KeyTestsToRun]
      fail:error];
  }
  NSSet<NSString *> *testsToRun = testsToRunArray ? [NSSet setWithArray:testsToRunArray] : nil;
  NSArray<NSString *> *testsToSkipArray = [FBCollectionOperations nullableValueForDictionary:json key:KeyTestsToSkip];
  if (testsToRunArray && ![FBCollectionInformation isArrayHeterogeneous:testsToRunArray withClass:NSString.class]) {
    return [[FBControlCoreError
      describeFormat:@"%@ is not a Array<String> | Null for %@", testsToSkipArray, KeyTestsToSkip]
      fail:error];
  }
  NSSet<NSString *> *testsToSkip = testsToSkipArray ? [NSSet setWithArray:testsToSkipArray] : nil;
  NSDictionary *xcTestRunProperties = [FBCollectionOperations nullableValueForDictionary:json key:KeyXcTestRunProperties];
  if (xcTestRunProperties && ![xcTestRunProperties isKindOfClass:NSDictionary .class]) {
    return [[FBControlCoreError
             describeFormat:@"%@ is not a Dictionary | Null for %@", xcTestRunProperties, KeyXcTestRunProperties]
            fail:error];
  }
  NSString *resultBundlePath = [FBCollectionOperations nullableValueForDictionary:json key:KeyResultBundlePath];
  if (resultBundlePath && ![resultBundlePath isKindOfClass:NSString.class]) {
    return [[FBControlCoreError
             describeFormat:@"%@ is not a String | Null for %@", resultBundlePath, KeyResultBundlePath]
            fail:error];
  }

  return [[self alloc]
    initWithTestBundlePath:bundlePath
    applicationLaunchConfiguration:appLaunch
    testHostPath:testHostPath
    timeout:timeout
    initializeUITesting:initializeUITesting
    testsToRun:testsToRun
    testsToSkip:testsToSkip
    targetApplicationPath:targetApplicationPath
    targetApplicationBundleID:targetApplicationBundleID
    xcTestRunProperties:xcTestRunProperties
    resultBundlePath:resultBundlePath];
}

#pragma mark FBiOSTargetAction

+ (FBiOSTargetActionType)actionType
{
  return FBiOSTargetActionTypeTestLaunch;
}

- (BOOL)runWithTarget:(id<FBiOSTarget>)target delegate:(id<FBiOSTargetActionDelegate>)delegate error:(NSError **)error
{
  id<FBXCTestCommands> commands = (id<FBXCTestCommands> ) target;
  if (![commands conformsToProtocol:@protocol(FBXCTestCommands)]) {
    return [[FBControlCoreError
      describeFormat:@"%@ does not conform to %@", target, NSStringFromProtocol(@protocol(FBXCTestCommands))]
      failBool:error];
  }

  id<FBXCTestOperation> operation = [commands startTestWithLaunchConfiguration:self reporter:nil error:error];
  if (!operation) {
    return NO;
  }
  if (self.timeout > 0) {
    if (![NSRunLoop.currentRunLoop awaitCompletionOfFuture:operation.completed timeout:self.timeout error:error]) {
      return NO;
    }
  }
  [delegate action:self target:target didGenerateTerminationHandle:operation];
  return YES;
}

@end
