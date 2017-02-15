//
//     Generated by class-dump 3.5 (64 bit) (Debug version compiled Nov 22 2016 05:57:16).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2015 by Steve Nygard.
//

#import <DVTFoundation/CDStructures.h>

@class DVTFilePath, IDERunnable, IDESchemeCommand, NSArray, NSDictionary, NSSet, NSString;
@protocol IDEBuildableProduct, IDETestingSpecifier;

@interface IDETestRunSpecification : NSObject
{
    BOOL _useDestinationArtifacts;
    BOOL _useInternalIOSLaunchStyleRsync;
    BOOL _isAppHostedTestBundle;
    BOOL _isUITestBundle;
    BOOL _useUITargetAppProvidedByTests;
    BOOL _treatMissingBaselinesAsFailures;
    id <IDETestingSpecifier> _testingSpecifier;
    NSSet *_testIdentifiersToRun;
    NSSet *_testIdentifiersToSkip;
    DVTFilePath *_testBundleFilePath;
    NSString *_testBundleDestinationRelativePathString;
    IDERunnable *_testHostRunnable;
    NSString *_bundleIdForTestHost;
    NSArray *_filePathsForDependentProducts;
    NSSet *_bundleIDsForCrashReportEmphasis;
    NSString *_productModuleName;
    NSArray *_toolchainsSettingValue;
    NSArray *_commandLineArguments;
    NSDictionary *_environmentVariables;
    NSDictionary *_testingEnvironmentVariables;
    IDESchemeCommand *_schemeCommand;
    NSString *_UITestingTargetAppBundleId;
    NSString *_UITestingTargetAppPath;
    DVTFilePath *_baselinePlistFilePath;
    NSString *_blueprintProviderRelativePath;
    NSString *_blueprintName;
    id <IDEBuildableProduct> _buildableProductForUIRecordingManager;
    id <IDEBuildableProduct> _buildableProductForDebugger;
    NSString *_clangProfileFilePathString;
    NSString *_clangProfileDataGenerationFilePathString;
}

+ (id)groupLongTestIdentifiersFor:(id)arg1;
+ (id)langaugeAgnosticIdentifersFor:(id)arg1;
+ (id)languageAgnosticIdentifierFor:(id)arg1;
+ (CDUnknownBlockType)launchParametersBlockForShouldDebugXPCServices:(BOOL)arg1 shouldDebugAppExtensions:(BOOL)arg2 workspace:(id)arg3 pgoController:(id)arg4 schemeIdentifier:(id)arg5 workingDirectory:(id)arg6 selectedLauncherIdentifier:(id)arg7 selectedDebuggerIdentifier:(id)arg8 buildConfiguration:(id)arg9 buildParameters:(id)arg10 internalIOSLaunchStyle:(int)arg11 debugProcessAsUID:(unsigned int)arg12;
+ (id)buildableProductForTestingSpecifier:(id)arg1;
+ (id)pathForBuildableProduct:(id)arg1 buildParameters:(id)arg2 runDestination:(id)arg3;
+ (id)testHostRunnableForUsesXCTRunner:(BOOL)arg1 runDestination:(id)arg2 buildableProduct:(id)arg3 buildParameters:(id)arg4 testingSpecifier:(id)arg5 outError:(id *)arg6;
+ (id)computedHostApplicationForBuildableProduct:(id)arg1 forRunDestination:(id)arg2 buildParameters:(id)arg3 testHostBuildSetting:(id)arg4 workspace:(id)arg5;
+ (id)_hostBuildableProductForBuildableProduct:(id)arg1 buildParameters:(id)arg2 testHostBuildSetting:(id)arg3 workspace:(id)arg4;
+ (BOOL)_isTestableBlueprint:(id)arg1;
+ (id)bundleIDsForDependentProductsForBuildOperation:(id)arg1 buildParameters:(id)arg2;
+ (id)filePathsForDependentProductsForBuildOperation:(id)arg1 buildParameters:(id)arg2 runDestination:(id)arg3;
+ (id)filePathsForDependentProductsForBuildables:(id)arg1 buildParameters:(id)arg2 runDestination:(id)arg3;
+ (id)_dependentProductsForBuildables:(id)arg1;
+ (id)baselinePlistFilePathForTestingSpecifier:(id)arg1 buildableProduct:(id)arg2 runDestination:(id)arg3 workspace:(id)arg4 withError:(id *)arg5;
+ (id)environmentVariablesForBuildParameters:(id)arg1 runDestination:(id)arg2 hostApplication:(id)arg3 testHostBuildSetting:(id)arg4 testingSpecifier:(id)arg5 usesXCTRunner:(BOOL)arg6 testBundleFilePath:(id)arg7;
+ (id)environmentVariablesForBuildParameters:(id)arg1 runDestination:(id)arg2 testHost:(id)arg3 testingSpecifier:(id)arg4 usesXCTRunner:(BOOL)arg5 isAppHosted:(BOOL)arg6 testHostBuildSetting:(id)arg7;
+ (id)blueprintNameForTestingSpecifier:(id)arg1;
+ (id)blueprintProviderRelativePathForTestingSpecifier:(id)arg1;
+ (id)removePathPlaceholdersIn:(id)arg1 forTestRootPath:(id)arg2 workspace:(id)arg3;
+ (id)insertPathPlaceholdersIn:(id)arg1 forTestRootPath:(id)arg2 workspace:(id)arg3;
+ (void)applyTestIdentifiersToRun:(id)arg1 toSpecifications:(id)arg2;
+ (void)applyTestIdentifiersToSkip:(id)arg1 toSpecifications:(id)arg2;
+ (BOOL)writeTestRunSpecifications:(id)arg1 toFilePath:(id)arg2 workspace:(id)arg3 error:(id *)arg4;
+ (id)testRunSpecificationsAtFilePath:(id)arg1 workspace:(id)arg2 error:(id *)arg3;
+ (id)testRunSpecificationsForTestingSpecifiers:(id)arg1 executionEnvironment:(id)arg2 buildOperation:(id)arg3 withBuildParameters:(id)arg4 environmentVariables:(id)arg5 commandLineArguments:(id)arg6 includeClangProfileParameters:(BOOL)arg7 doingCodeCoverage:(BOOL)arg8 enableAddressSanitizer:(BOOL)arg9 enableThreadSanitizer:(BOOL)arg10 shouldDebugAppExtensions:(BOOL)arg11 error:(id *)arg12;
+ (id)outputDirectoriesForBuildables:(id)arg1 buildParameters:(id)arg2;
@property(retain) NSString *clangProfileDataGenerationFilePathString; // @synthesize clangProfileDataGenerationFilePathString=_clangProfileDataGenerationFilePathString;
@property(retain) NSString *clangProfileFilePathString; // @synthesize clangProfileFilePathString=_clangProfileFilePathString;
@property(retain) id <IDEBuildableProduct> buildableProductForDebugger; // @synthesize buildableProductForDebugger=_buildableProductForDebugger;
@property(retain) id <IDEBuildableProduct> buildableProductForUIRecordingManager; // @synthesize buildableProductForUIRecordingManager=_buildableProductForUIRecordingManager;
@property BOOL treatMissingBaselinesAsFailures; // @synthesize treatMissingBaselinesAsFailures=_treatMissingBaselinesAsFailures;
@property(copy) NSString *blueprintName; // @synthesize blueprintName=_blueprintName;
@property(copy) NSString *blueprintProviderRelativePath; // @synthesize blueprintProviderRelativePath=_blueprintProviderRelativePath;
@property(copy) DVTFilePath *baselinePlistFilePath; // @synthesize baselinePlistFilePath=_baselinePlistFilePath;
// Xcode >=8.3: DVTFilePath <8.3: NSString
@property(copy) id UITestingTargetAppPath; // @synthesize UITestingTargetAppPath=_UITestingTargetAppPath;
@property(copy) NSString *UITestingTargetAppBundleId; // @synthesize UITestingTargetAppBundleId=_UITestingTargetAppBundleId;
@property BOOL useUITargetAppProvidedByTests; // @synthesize useUITargetAppProvidedByTests=_useUITargetAppProvidedByTests;
@property BOOL isUITestBundle; // @synthesize isUITestBundle=_isUITestBundle;
@property(retain) IDESchemeCommand *schemeCommand; // @synthesize schemeCommand=_schemeCommand;
@property(copy) NSDictionary *testingEnvironmentVariables; // @synthesize testingEnvironmentVariables=_testingEnvironmentVariables;
@property(copy) NSDictionary *environmentVariables; // @synthesize environmentVariables=_environmentVariables;
@property(copy) NSArray *commandLineArguments; // @synthesize commandLineArguments=_commandLineArguments;
@property(copy) NSArray *toolchainsSettingValue; // @synthesize toolchainsSettingValue=_toolchainsSettingValue;
@property(copy) NSString *productModuleName; // @synthesize productModuleName=_productModuleName;
@property(copy) NSSet *bundleIDsForCrashReportEmphasis; // @synthesize bundleIDsForCrashReportEmphasis=_bundleIDsForCrashReportEmphasis;
@property(copy) NSArray *filePathsForDependentProducts; // @synthesize filePathsForDependentProducts=_filePathsForDependentProducts;
@property BOOL isAppHostedTestBundle; // @synthesize isAppHostedTestBundle=_isAppHostedTestBundle;
@property BOOL useInternalIOSLaunchStyleRsync; // @synthesize useInternalIOSLaunchStyleRsync=_useInternalIOSLaunchStyleRsync;
@property BOOL useDestinationArtifacts; // @synthesize useDestinationArtifacts=_useDestinationArtifacts;
@property(copy) NSString *bundleIdForTestHost; // @synthesize bundleIdForTestHost=_bundleIdForTestHost;
@property(retain) IDERunnable *testHostRunnable; // @synthesize testHostRunnable=_testHostRunnable;
@property(copy) NSString *testBundleDestinationRelativePathString; // @synthesize testBundleDestinationRelativePathString=_testBundleDestinationRelativePathString;
@property(copy) DVTFilePath *testBundleFilePath; // @synthesize testBundleFilePath=_testBundleFilePath;
@property(copy, nonatomic) NSSet *testIdentifiersToSkip; // @synthesize testIdentifiersToSkip=_testIdentifiersToSkip;
@property(copy, nonatomic) NSSet *testIdentifiersToRun; // @synthesize testIdentifiersToRun=_testIdentifiersToRun;
@property(retain) id <IDETestingSpecifier> testingSpecifier; // @synthesize testingSpecifier=_testingSpecifier;
- (void)updateFromDictionaryRepresentation:(id)arg1;
- (id)dictionaryRepresentation;
- (BOOL)validateRunDestination:(id)arg1 error:(id *)arg2;

@end

