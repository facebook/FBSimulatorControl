// Copyright 2004-present Facebook. All Rights Reserved.

#import <Foundation/Foundation.h>

@class FBApplicationDescriptor;

@interface FBXCTestKitFixtures : NSObject

/**
 Creates a new temporary directory.

 @return path to temporary directory.
 */
+ (NSString *)createTemporaryDirectory;

/**
 A build of Apple's 'Table Search' Sample Application.
 Source is available at:
 https://developer.apple.com/library/ios/samplecode/TableSearch_UISearchController/Introduction/Intro.html#//apple_ref/doc/uid/TP40014683

 @return path to the application.
 */
+ (NSString *)tableSearchApplicationPath;

/**
 An Application Test xctest bundle.

 @return path to the Application Test Bundle.
 */
+ (NSString *)simpleTestTargetPath;

@end
