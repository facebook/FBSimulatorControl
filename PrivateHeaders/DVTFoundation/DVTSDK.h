/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

@class DVTFilePath, DVTPlatform, DVTSearchPath, NSArray, NSDictionary, NSNumber, NSString, NSURL;

@interface DVTSDK : NSObject
{
    DVTPlatform *_platform;
    NSString *_canonicalName;
    NSString *_displayName;
    NSString *_operatingSystemVersion;
    DVTFilePath *_sdkPath;
    NSString *_docSetFeedName;
    NSURL *_docSetFeedURL;
    NSString *_alternateSDKName;
    NSArray *_supportedBuildToolComponents;
    NSArray *_librarySearchPaths;
    NSDictionary *_infoDictionary;
    NSString *_propertyConditionName;
    NSArray *_propertyConditionFallbackNames;
    NSString *_minimalDisplayName;
    NSDictionary *_defaultProperties;
    NSNumber *_isInternal;
    NSNumber *_isBaseSDK;
    DVTSearchPath *_commandLineToolSearchPath;
    NSArray *_headerSearchPaths;
    NSArray *_frameworkSearchPaths;
    NSDictionary *_versionInfo;
    NSArray *_toolchains;
    NSArray *_toolchainNames;
}

+ (id)sdksInDirectory:(id)arg1 forPlatform:(id)arg2;
+ (id)sdkInDirectory:(id)arg1 forPlatform:(id)arg2;
+ (id)sdkForPath:(id)arg1 forceCreate:(BOOL)arg2;
+ (id)sdkForPath:(id)arg1;
+ (BOOL)sdkForBootSystemRequiresSpecialTreatment;
+ (id)sdkForBootSystemOrNil;
+ (id)sdkForBootSystem;
+ (id)sdkForNameOrPath:(id)arg1 withBasePath:(id)arg2 forceCreate:(BOOL)arg3;
+ (id)_absolutePathForSDKPathString:(id)arg1;
+ (id)sdksForFamily:(id)arg1;
+ (id)sdkForCanonicalName:(id)arg1;
+ (void)_setSDK:(id)arg1 forCanonicalName:(id)arg2;
+ (id)_sdkForResolvedAbsolutePath:(id)arg1;
+ (void)_setSDK:(id)arg1 forResolvedAbsolutePath:(id)arg2;
+ (id)knownSDKs;
+ (BOOL)shouldAllowBootSystemSDK;
+ (void)initialize;
@property(readonly, copy) NSArray *toolchainNames; // @synthesize toolchainNames=_toolchainNames;
@property(readonly, copy) NSArray *propertyConditionFallbackNames; // @synthesize propertyConditionFallbackNames=_propertyConditionFallbackNames;
@property(readonly, copy) NSDictionary *defaultProperties; // @synthesize defaultProperties=_defaultProperties;
@property(readonly, copy) NSArray *toolchains; // @synthesize toolchains=_toolchains;
@property(readonly, copy) NSURL *docSetFeedURL; // @synthesize docSetFeedURL=_docSetFeedURL;
@property(readonly, copy) NSString *docSetFeedName; // @synthesize docSetFeedName=_docSetFeedName;
@property(readonly, copy) NSArray *librarySearchPaths; // @synthesize librarySearchPaths=_librarySearchPaths;
@property(readonly, copy) NSString *alternateSDKName; // @synthesize alternateSDKName=_alternateSDKName;
@property(readonly, copy) NSArray *supportedBuildToolComponents; // @synthesize supportedBuildToolComponents=_supportedBuildToolComponents;
@property(readonly, copy) NSString *propertyConditionName; // @synthesize propertyConditionName=_propertyConditionName;
@property(readonly, copy) NSString *minimalDisplayName; // @synthesize minimalDisplayName=_minimalDisplayName;
@property(readonly, copy) NSString *displayName; // @synthesize displayName=_displayName;
@property(readonly, copy) NSString *canonicalName; // @synthesize canonicalName=_canonicalName;
@property(readonly, copy) DVTFilePath *sdkPath; // @synthesize sdkPath=_sdkPath;
@property(readonly, copy) NSDictionary *infoDictionary; // @synthesize infoDictionary=_infoDictionary;
@property(readonly, copy) NSString *operatingSystemVersion; // @synthesize operatingSystemVersion=_operatingSystemVersion;

- (unsigned long long)hash;
- (BOOL)isEqual:(id)arg1;
- (id)description;
- (id)additionalFrameworkSearchPaths;
- (id)additionalHeaderSearchPaths;
- (id)commandLineToolSearchPath;
@property(readonly) NSDictionary *versionInfo; // @synthesize versionInfo=_versionInfo;
@property(readonly, getter=isBaseSDK) BOOL baseSDK;
@property(readonly, getter=isInternal) BOOL internal;
@property(retain) DVTPlatform *platform;
- (BOOL)isEmbedded;
- (id)initWithFilePath:(id)arg1;
- (id)initWithFilePath:(id)arg1 infoDictionary:(id)arg2;

@end

