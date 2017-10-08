/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBApplicationDataPackage.h"

#import <FBControlCore/FBControlCore.h>

#import "FBTestBundle.h"
#import "FBTestConfiguration.h"
#import "XCTestBootstrapError.h"

static NSString *const FBTestPlanDirectoryName = @"TestPlans";

@interface FBApplicationDataPackage ()
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *bundlePath;
@property (nonatomic, copy) NSString *bundlePathOnDevice;
@property (nonatomic, strong) FBTestConfiguration *testConfiguration;
@property (nonatomic, strong) FBTestBundle *testBundle;
@property (nonatomic, strong) FBProductBundle *XCTestFramework;
@property (nonatomic, strong) FBProductBundle *IDEBundleInjectionFramework;
@end

@implementation FBApplicationDataPackage
@end


@interface FBApplicationDataPackageBuilder ()
@property (nonatomic, strong) id<FBFileManager> fileManager;
@property (nonatomic, strong) id<FBCodesignProvider> codesignProvider;
@property (nonatomic, strong) FBTestBundle *testBundle;
@property (nonatomic, copy) NSString *packagePath;
@property (nonatomic, copy) NSString *workingDirectory;
@property (nonatomic, copy) NSString *deviceDataDirectory;
@property (nonatomic, copy) NSString *platformDirectory;
@end

@implementation FBApplicationDataPackageBuilder

+ (instancetype)builder
{
  return [self.class builderWithFileManager:[NSFileManager defaultManager]];
}

+ (instancetype)builderWithFileManager:(id<FBFileManager>)fileManager
{
  FBApplicationDataPackageBuilder *builder = [self.class new];
  builder.fileManager = fileManager;
  return builder;
}

- (instancetype)withWorkingDirectory:(NSString *)workingDirectory
{
  self.workingDirectory = workingDirectory;
  return self;
}

- (instancetype)withPackagePath:(NSString *)packagePath
{
  self.packagePath = packagePath;
  return self;
}

- (instancetype)withDeviceDataDirectory:(NSString *)deviceDataDirectory
{
  self.deviceDataDirectory = deviceDataDirectory;
  return self;
}

- (instancetype)withPlatformDirectory:(NSString *)platformDirectory
{
  self.platformDirectory = platformDirectory;
  return self;
}

- (instancetype)withCodesignProvider:(id<FBCodesignProvider>)codesignProvider
{
  self.codesignProvider = codesignProvider;
  return self;
}

- (instancetype)withTestBundle:(FBTestBundle *)testBundle
{
  self.testBundle = testBundle;
  return self;
}

- (FBApplicationDataPackage *)buildWithError:(NSError **)error
{
  NSAssert(self.testBundle, @"testBundle is required to create data package");
  NSAssert(self.deviceDataDirectory, @"deviceDataDirectory is required to create data package");
  NSAssert(self.fileManager, @"fileManager is required to create data package");
  NSAssert(self.workingDirectory || self.packagePath, @"workingDirectory or packagePath is required to create data package");

  NSString *packagePath = self.packagePath;
  if (!packagePath) {
    packagePath = [[self.workingDirectory stringByAppendingPathComponent:self.testBundle.name] stringByAppendingPathExtension:@"xcappdata"];
  }
  NSString *packageBundlePath = [packagePath stringByAppendingPathComponent:@"AppData/tmp"];
  NSString *packageBundlePathOnDevice = [self.deviceDataDirectory stringByAppendingPathComponent:@"tmp"];
  NSString *localTestPlanDirPath = [packageBundlePath stringByAppendingPathComponent:FBTestPlanDirectoryName];
  NSString *deviceTestBundlePath = [packageBundlePathOnDevice stringByAppendingPathComponent:self.testBundle.filename];
  NSString *testConfigurationFileName = [self.testBundle.name stringByAppendingPathExtension:@"xctest.xctestconfiguration"];
  NSString *testBundlePath = [packageBundlePath stringByAppendingPathComponent:self.testBundle.path.lastPathComponent];
  NSString *XCTestFrameworkPath = [packageBundlePath stringByAppendingPathComponent:@"XCTest.framework"];
  NSString *IDEBundleInjectionFrameworkPath = [packageBundlePath stringByAppendingPathComponent:@"IDEBundleInjection.framework"];
  NSString *workingDirectory = nil;

  if (self.workingDirectory) {
    NSAssert(self.platformDirectory, @"platformDirectory is required to create data package");
    XCTestFrameworkPath = [self.platformDirectory stringByAppendingPathComponent:@"Developer/Library/Frameworks/XCTest.framework"];
    IDEBundleInjectionFrameworkPath = [self.platformDirectory stringByAppendingPathComponent:@"Developer/Library/PrivateFrameworks/IDEBundleInjection.framework"];
    testBundlePath = self.testBundle.path;
    workingDirectory = packageBundlePath;
  }

  FBApplicationDataPackage *package = [FBApplicationDataPackage new];
  package.path = packagePath;
  package.bundlePath = packageBundlePath;
  package.bundlePathOnDevice = packageBundlePathOnDevice;

  if (![self.fileManager createDirectoryAtPath:localTestPlanDirPath withIntermediateDirectories:YES attributes:nil error:error]) {
    return nil;
  }
  NSError *innerError;
  package.testConfiguration = [FBTestConfiguration
   configurationWithFileManager:self.fileManager
   sessionIdentifier:self.testBundle.configuration.sessionIdentifier\
   moduleName:self.testBundle.name
   testBundlePath:deviceTestBundlePath
   uiTesting:self.testBundle.configuration.shouldInitializeForUITesting
   testsToRun:nil
   testsToSkip:nil
   targetApplicationPath:nil
   targetApplicationBundleID:nil
   savePath:[localTestPlanDirPath stringByAppendingPathComponent:testConfigurationFileName]
   error:&innerError];
  if (!package.testConfiguration) {
    return [[[XCTestBootstrapError
      describe:@"Failed to generate test configuration"]
      causedBy:innerError]
      fail:error];
  }

  package.testBundle =
  [[[[[[[FBTestBundleBuilder builderWithFileManager:self.fileManager]
        withBundlePath:testBundlePath]
       withSessionIdentifier:self.testBundle.configuration.sessionIdentifier]
      withWorkingDirectory:workingDirectory]
     withCodesignProvider:self.codesignProvider]
    withUITesting:self.testBundle.configuration.shouldInitializeForUITesting]
   buildWithError:&innerError];
  if (!package.testBundle) {
    return
    [[[XCTestBootstrapError describe:@"Failed to generate test bundle"]
      causedBy:innerError]
     fail:error];
  }

  package.XCTestFramework =
  [[[[[FBProductBundleBuilder builderWithFileManager:self.fileManager]
      withBundlePath:XCTestFrameworkPath]
     withWorkingDirectory:workingDirectory]
    withCodesignProvider:self.codesignProvider]
   buildWithError:&innerError];
  if (!package.XCTestFramework) {
    return
    [[[XCTestBootstrapError describe:@"Failed to generate XCTestFramework bundle"]
      causedBy:innerError]
     fail:error];
  }

  package.IDEBundleInjectionFramework =
  [[[[[FBProductBundleBuilder builderWithFileManager:self.fileManager]
      withBundlePath:IDEBundleInjectionFrameworkPath]
     withWorkingDirectory:workingDirectory]
    withCodesignProvider:self.codesignProvider]
   buildWithError:&innerError];
  if (!package.IDEBundleInjectionFramework) {
    return
    [[[XCTestBootstrapError describe:@"Failed to generate IDEBundleInjectionFramework bundle"]
      causedBy:innerError]
     fail:error];
  }
  return package;
}

@end
