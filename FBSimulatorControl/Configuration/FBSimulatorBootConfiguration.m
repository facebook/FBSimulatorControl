/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSimulatorBootConfiguration.h"

#import "FBFramebufferConfiguration.h"
#import "FBSimulator.h"
#import "FBSimulatorError.h"

FBiOSTargetActionType const FBiOSTargetActionTypeBoot = @"boot";

@implementation FBSimulatorBootConfiguration

@synthesize scale = _scale;

#pragma mark Initializers

+ (instancetype)defaultConfiguration
{
  static dispatch_once_t onceToken;
  static FBSimulatorBootConfiguration *configuration;
  dispatch_once(&onceToken, ^{
    configuration = [self new];
  });
  return configuration;
}

static FBSimulatorBootOptions const DefaultBootOptions = FBSimulatorBootOptionsAwaitServices | FBSimulatorBootOptionsUseNSWorkspace;

- (instancetype)init
{
  return [self initWithOptions:DefaultBootOptions scale:nil localizationOverride:nil framebuffer:nil];
}

- (instancetype)initWithOptions:(FBSimulatorBootOptions)options scale:(FBScale)scale localizationOverride:(FBLocalizationOverride *)localizationOverride framebuffer:(FBFramebufferConfiguration *)framebuffer
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _options = options;
  _scale = scale;
  _localizationOverride = localizationOverride;
  _framebuffer = framebuffer;

  return self;
}

#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
  return [[self.class alloc] initWithOptions:self.options scale:self.scale localizationOverride:self.localizationOverride framebuffer:self.framebuffer];
}

#pragma mark NSObject

- (BOOL)isEqual:(FBSimulatorBootConfiguration *)configuration
{
  if (![configuration isKindOfClass:self.class]) {
    return NO;
  }

  return self.options == configuration.options &&
         (self.scale == configuration.scale || [self.scale isEqualToString:configuration.scale]) &&
         (self.localizationOverride == configuration.localizationOverride || [self.localizationOverride isEqual:configuration.localizationOverride]) &&
         (self.framebuffer == configuration.framebuffer || [self.framebuffer isEqual:configuration.framebuffer]);
}

- (NSUInteger)hash
{
  return self.options ^ self.scale.hash ^ self.localizationOverride.hash ^ self.framebuffer.hash;
}

#pragma mark FBDebugDescribeable

- (NSString *)description
{
  return [NSString stringWithFormat:
    @"Scale %@ | %@ | Options %@ | %@",
    self.scale,
    self.localizationOverride ? self.localizationOverride : @"No Locale Override",
    [FBCollectionInformation oneLineDescriptionFromArray:[FBSimulatorBootConfiguration stringsFromBootOptions:self.options]],
    self.framebuffer ?: @"No Framebuffer"
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

static NSString *const KeyScale = @"scale";
static NSString *const KeyLocalizationOverride = @"localization_override";
static NSString *const KeyOptions = @"options";
static NSString *const KeyFramebuffer = @"framebuffer";

+ (nullable instancetype)inflateFromJSON:(NSDictionary<NSString *, id> *)json error:(NSError **)error
{
  FBScale scale = [FBCollectionOperations nullableValueForDictionary:json key:KeyScale];
  if (![scale isKindOfClass:NSString.class]) {
    return [[FBSimulatorError
      describeFormat:@"%@ is not a String %@", scale, KeyScale]
      fail:error];
  }
  FBLocalizationOverride *override = nil;
  NSDictionary<NSString *, id> *localizationDictionary = [FBCollectionOperations nullableValueForDictionary:json key:KeyLocalizationOverride];
  if (localizationDictionary) {
    override = [FBLocalizationOverride inflateFromJSON:localizationDictionary error:error];
    if (!override) {
      return nil;
    }
  }
  NSDictionary<NSString *, id> *framebufferDictionary = [FBCollectionOperations nullableValueForDictionary:json key:KeyFramebuffer];
  FBFramebufferConfiguration *framebuffer = nil;
  if (framebufferDictionary) {
    framebuffer = [FBFramebufferConfiguration inflateFromJSON:framebufferDictionary error:error];
    if (!framebuffer) {
      return nil;
    }
  }
  NSArray<NSString *> *bootOptionsStrings = json[KeyOptions];
  if (![FBCollectionInformation isArrayHeterogeneous:bootOptionsStrings withClass:NSString.class]) {
    return [[FBSimulatorError
      describeFormat:@"%@ is not Array<String> | nil | %@", bootOptionsStrings, KeyOptions]
      fail:error];
  }
  FBSimulatorBootOptions bootOptions = [self bootOptionsFromStrings:bootOptionsStrings];

  return [[self alloc] initWithOptions:bootOptions scale:scale localizationOverride:override framebuffer:framebuffer];
}

- (NSDictionary *)jsonSerializableRepresentation
{
  return @{
    KeyScale : self.scale ?: NSNull.null,
    KeyLocalizationOverride : self.localizationOverride.jsonSerializableRepresentation ?: NSNull.null,
    KeyOptions : [FBSimulatorBootConfiguration stringsFromBootOptions:self.options],
    KeyFramebuffer : self.framebuffer.jsonSerializableRepresentation ?: NSNull.null,
  };
}

#pragma mark Accessors

- (nullable NSDecimalNumber *)scaleValue
{
  return self.scale ? [NSDecimalNumber decimalNumberWithString:self.scale] : nil;
}

#pragma mark Options

+ (instancetype)withOptions:(FBSimulatorBootOptions)options
{
  return [self.defaultConfiguration withOptions:options];
}

- (instancetype)withOptions:(FBSimulatorBootOptions)options
{
  return [[self.class alloc] initWithOptions:options scale:self.scale localizationOverride:self.localizationOverride framebuffer:self.framebuffer];
}

#pragma mark Scale

+ (instancetype)withScale:(FBScale)scale
{
  return [self.defaultConfiguration withScale:scale];
}

- (instancetype)withScale:(FBScale)scale
{
  if (!scale) {
    return self;
  }
  FBFramebufferConfiguration *framebuffer = [self.framebuffer withScale:scale];
  return [[self.class alloc] initWithOptions:self.options scale:scale localizationOverride:self.localizationOverride framebuffer:framebuffer];
}

#pragma mark Locale

+ (instancetype)withLocalizationOverride:(nullable FBLocalizationOverride *)localizationOverride
{
  return [self.defaultConfiguration withLocalizationOverride:localizationOverride];
}

- (instancetype)withLocalizationOverride:(nullable FBLocalizationOverride *)localizationOverride
{
  return [[self.class alloc] initWithOptions:self.options scale:self.scale localizationOverride:localizationOverride framebuffer:self.framebuffer];
}

#pragma mark Video

+ (instancetype)withFramebuffer:(FBFramebufferConfiguration *)framebuffer
{
  return [self.defaultConfiguration withFramebuffer:framebuffer];
}

- (instancetype)withFramebuffer:(FBFramebufferConfiguration *)framebuffer
{
  return [[self.class alloc] initWithOptions:self.options scale:self.scale localizationOverride:self.localizationOverride framebuffer:framebuffer];
}

#pragma mark Utility

static NSString *const BootOptionStringConnectBridge = @"Connect Bridge";
static NSString *const BootOptionStringDirectLaunch = @"Direct Launch";
static NSString *const BootOptionStringUseNSWorkspace = @"Use NSWorkspace";

+ (NSArray<NSString *> *)stringsFromBootOptions:(FBSimulatorBootOptions)options
{
  NSMutableArray<NSString *> *strings = [NSMutableArray array];
  if ((options & FBSimulatorBootOptionsConnectBridge) == FBSimulatorBootOptionsConnectBridge) {
    [strings addObject:BootOptionStringConnectBridge];
  }
  if ((options & FBSimulatorBootOptionsEnableDirectLaunch) == FBSimulatorBootOptionsEnableDirectLaunch) {
    [strings addObject:BootOptionStringDirectLaunch];
  }
  if ((options & FBSimulatorBootOptionsUseNSWorkspace) == FBSimulatorBootOptionsUseNSWorkspace) {
    [strings addObject:BootOptionStringUseNSWorkspace];
  }
  return [strings copy];
}

+ (FBSimulatorBootOptions)bootOptionsFromStrings:(NSArray<NSString *> *)strings
{
  FBSimulatorBootOptions options = 0;
  for (NSString *string in strings) {
    if ([string isEqualToString:BootOptionStringConnectBridge]) {
      options = options | FBSimulatorBootOptionsConnectBridge;
    } else if ([string isEqualToString:BootOptionStringDirectLaunch]) {
      options = options | FBSimulatorBootOptionsEnableDirectLaunch;
    } else if ([string isEqualToString:BootOptionStringUseNSWorkspace]) {
      options = options | FBSimulatorBootOptionsUseNSWorkspace;
    }
  }
  return options;
}

#pragma mark FBiOSTargetAction

+ (FBiOSTargetActionType)actionType
{
  return FBiOSTargetActionTypeBoot;
}

- (BOOL)runWithTarget:(id<FBiOSTarget>)target delegate:(id<FBiOSTargetActionDelegate>)delegate error:(NSError **)error
{
  if (![target isKindOfClass:FBSimulator.class]) {
    return [[FBSimulatorError
      describeFormat:@"%@ cannot be booted", target]
      failBool:error];
  }
  FBSimulator *simulator = (FBSimulator *) target;
  return [simulator boot:self error:error];
}

@end
