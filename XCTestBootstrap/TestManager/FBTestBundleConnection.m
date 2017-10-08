/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTestBundleConnection.h"

#import <XCTest/XCTestDriverInterface-Protocol.h>
#import <XCTest/XCTestManager_DaemonConnectionInterface-Protocol.h>
#import <XCTest/XCTestManager_IDEInterface-Protocol.h>

#import <DTXConnectionServices/DTXConnection.h>
#import <DTXConnectionServices/DTXProxyChannel.h>
#import <DTXConnectionServices/DTXRemoteInvocationReceipt.h>
#import <DTXConnectionServices/DTXTransport.h>

#import <IDEiOSSupportCore/DVTAbstractiOSDevice.h>

#import <objc/runtime.h>

#import "XCTestBootstrapError.h"
#import "FBDeviceOperator.h"
#import "FBTestManagerContext.h"
#import "FBTestManagerAPIMediator.h"
#import "FBTestBundleResult.h"

static NSTimeInterval CrashCheckInterval = 0.5;

typedef NSString *FBTestBundleConnectionState NS_STRING_ENUM;
static FBTestBundleConnectionState const FBTestBundleConnectionStateNotConnected = @"not connected";
static FBTestBundleConnectionState const FBTestBundleConnectionStateConnecting = @"connecting";
static FBTestBundleConnectionState const FBTestBundleConnectionStateTestBundleReady = @"bundle ready";
static FBTestBundleConnectionState const FBTestBundleConnectionStateAwaitingStartOfTestPlan = @"awaiting start of test plan";
static FBTestBundleConnectionState const FBTestBundleConnectionStateExecutingTestPlan = @"executing test plan";
static FBTestBundleConnectionState const FBTestBundleConnectionStateEndedTestPlan = @"ended test plan";
static FBTestBundleConnectionState const FBTestBundleConnectionStateResultAvailable = @"result available";

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@interface FBTestBundleConnection () <XCTestManager_IDEInterface>

@property (nonatomic, nullable, strong, readonly) id<FBControlCoreLogger> logger;
@property (nonatomic, strong, readonly) FBTestManagerContext *context;
@property (nonatomic, weak, readonly) id<XCTestManager_IDEInterface, NSObject> interface;
@property (nonatomic, strong, readonly) dispatch_queue_t requestQueue;
@property (nonatomic, strong, readonly) id<FBiOSTarget> target;

@property (atomic, strong, readwrite) FBTestBundleConnectionState state;
@property (atomic, strong, readwrite) FBTestBundleResult *result;

@property (nonatomic, strong, nullable, readwrite) FBMutableFuture *connectFuture;
@property (nonatomic, strong, nullable, readwrite) FBMutableFuture *testPlanFuture;
@property (nonatomic, strong, nullable, readwrite) FBMutableFuture *disconnectFuture;

@property (atomic, assign, readwrite) long long testBundleProtocolVersion;
@property (atomic, nullable, strong, readwrite) id<XCTestDriverInterface> testBundleProxy;
@property (atomic, nullable, strong, readwrite) DTXConnection *testBundleConnection;
@property (atomic, nullable, strong, readwrite) NSDate *lastCrashCheckDate;
@property (atomic, nullable, strong, readwrite) NSDate *applicationLaunchDate;

@end

@implementation FBTestBundleConnection

+ (NSString *)clientProcessUniqueIdentifier
{
  static dispatch_once_t onceToken;
  static NSString *_clientProcessUniqueIdentifier;
  dispatch_once(&onceToken, ^{
    _clientProcessUniqueIdentifier = NSProcessInfo.processInfo.globallyUniqueString;
  });
  return _clientProcessUniqueIdentifier;
}

+ (NSString *)clientProcessDisplayPath
{
  static dispatch_once_t onceToken;
  static NSString *_clientProcessDisplayPath;
  dispatch_once(&onceToken, ^{
    NSString *path = NSBundle.mainBundle.bundlePath;
    if (![path.pathExtension isEqualToString:@"app"]) {
      path = NSBundle.mainBundle.executablePath;
    }
    _clientProcessDisplayPath = path;
  });
  return _clientProcessDisplayPath;
}

+ (instancetype)connectionWithContext:(FBTestManagerContext *)context target:(id<FBiOSTarget>)target interface:(id<XCTestManager_IDEInterface, NSObject>)interface requestQueue:(dispatch_queue_t)requestQueue logger:(nullable id<FBControlCoreLogger>)logger
{
  return [[self alloc] initWithWithContext:context target:target interface:interface requestQueue:requestQueue logger:logger];
}

- (instancetype)initWithWithContext:(FBTestManagerContext *)context target:(id<FBiOSTarget>)target interface:(id<XCTestManager_IDEInterface, NSObject>)interface requestQueue:(dispatch_queue_t)requestQueue logger:(nullable id<FBControlCoreLogger>)logger
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _context = context;
  _target = target;
  _interface = interface;
  _requestQueue = requestQueue;
  _logger = [logger withPrefix:[NSString stringWithFormat:@"%@:", target.udid]];

  _state = FBTestBundleConnectionStateNotConnected;
  _lastCrashCheckDate = NSDate.distantPast;
  _applicationLaunchDate = NSDate.date;

  _connectFuture = FBMutableFuture.new;
  _testPlanFuture = FBMutableFuture.new;
  _disconnectFuture = FBMutableFuture.new;

  return self;
}

#pragma mark NSObject

- (NSString *)description
{
  return [NSString stringWithFormat: @"Test Bundle Connection '%@'", self.state];
}

#pragma mark Message Forwarding

- (BOOL)respondsToSelector:(SEL)selector
{
  return [super respondsToSelector:selector] || [self.interface respondsToSelector:selector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
  return [super methodSignatureForSelector:selector] ?: [(id)self.interface methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
  if ([self.interface respondsToSelector:invocation.selector]) {
    [invocation invokeWithTarget:self.interface];
  } else {
    [super forwardInvocation:invocation];
  }
}

#pragma mark Public

- (FBFuture<FBTestBundleResult *> *)connect
{
  // Fail-fast if the connection state is incorrect.
  if (self.state != FBTestBundleConnectionStateNotConnected) {
    XCTestBootstrapError *error = [XCTestBootstrapError
      describeFormat:@"Cannot connect, state must be %@ but is %@", FBTestBundleConnectionStateNotConnected, self.state];
    [self concludeWithResult:[FBTestBundleResult failedInError:error]];
    return self.connectFuture;
  }

  [self doConnect];
  return self.connectFuture;
}

- (FBFuture<FBTestBundleResult *> *)startTestPlan
{
  // Fail-fast if the connection state is incorrect.
  if (self.state != FBTestBundleConnectionStateTestBundleReady) {
    XCTestBootstrapError *error = [XCTestBootstrapError
      describeFormat:@"State should be '%@' got '%@", FBTestBundleConnectionStateTestBundleReady, self.state];
    [self concludeWithResult:[FBTestBundleResult failedInError:error]];
    return self.testPlanFuture;
  }

  [self.logger log:@"Bundle Connection scheduling start of Test Plan"];
  self.state = FBTestBundleConnectionStateAwaitingStartOfTestPlan;
  dispatch_async(self.requestQueue, ^{
    [self.testBundleProxy _IDE_startExecutingTestPlanWithProtocolVersion:@(FBProtocolVersion)];
  });
  return self.testPlanFuture;
}

- (FBFuture<FBTestBundleResult *> *)completeTestRun
{
  return self.testPlanFuture;
}

- (FBFuture<FBTestBundleResult *> *)disconnect
{
  [self.logger logFormat:@"Disconnecting Test Bundle in state '%@'", self.state];

  FBTestBundleResult *result = nil;
  if (self.state == FBTestBundleConnectionStateEndedTestPlan) {
    result = [self concludeWithResult:FBTestBundleResult.success];
  } else {
    result = [self concludeWithResult:FBTestBundleResult.clientRequestedDisconnect];
  }
  [self.testBundleConnection suspend];
  [self.testBundleConnection cancel];
  self.testBundleConnection = nil;
  self.testBundleProxy = nil;
  self.testBundleProtocolVersion = 0;

  return self.disconnectFuture;
}

#pragma mark Private

- (void)doConnect
{
  self.state = FBTestBundleConnectionStateConnecting;
  [self.logger log:@"Connecting Test Bundle"];

  dispatch_async(self.requestQueue, ^{
    NSError *error;
    DTXTransport *transport = [self.target.deviceOperator makeTransportForTestManagerServiceWithLogger:self.logger error:&error];
    if (error || !transport) {
      XCTestBootstrapError *realError = [[XCTestBootstrapError
        describe:@"Failed to create transport"]
        causedBy:error];
      [self concludeWithResult:[FBTestBundleResult failedInError:realError]];
      return;
    }
    DTXConnection *connection = [self setupTestBundleConnectionWithTransport:transport];
    dispatch_async(self.target.workQueue, ^{
      [self sendStartSessionRequestWithConnection:connection];
    });
  });
}

- (DTXConnection *)setupTestBundleConnectionWithTransport:(DTXTransport *)transport
{
  [self.logger logFormat:@"Creating the test bundle connection."];
  DTXConnection *connection = [[objc_lookUpClass("DTXConnection") alloc] initWithTransport:transport];
  [connection registerDisconnectHandler:^{
    [self bundleDisconnectedWithState:self.state];
  }];

  [self.logger logFormat:@"Listening for proxy connection request from the test bundle (all platforms)"];
  [connection
   handleProxyRequestForInterface:@protocol(XCTestManager_IDEInterface)
   peerInterface:@protocol(XCTestDriverInterface)
   handler:^(DTXProxyChannel *channel){
     [self.logger logFormat:@"Got proxy channel request from test bundle"];
     [channel setExportedObject:self queue:self.target.workQueue];
     id<XCTestDriverInterface> interface = channel.remoteObjectProxy;
     self.testBundleProxy = interface;
   }];
  [self.logger logFormat:@"Resuming the test bundle connection."];
  self.testBundleConnection = connection;
  [self.testBundleConnection resume];
  return self.testBundleConnection;
}

- (void)sendStartSessionRequestWithConnection:(DTXConnection *)connection
{
  [self.logger log:@"Checking test manager availability..."];
  DTXProxyChannel *proxyChannel = [self.testBundleConnection
    makeProxyChannelWithRemoteInterface:@protocol(XCTestManager_DaemonConnectionInterface)
    exportedInterface:@protocol(XCTestManager_IDEInterface)];
  [proxyChannel setExportedObject:self queue:self.target.workQueue];
  id<XCTestManager_DaemonConnectionInterface> remoteProxy = (id<XCTestManager_DaemonConnectionInterface>) proxyChannel.remoteObjectProxy;

  [self.logger logFormat:@"Starting test session with ID %@", self.context.sessionIdentifier.UUIDString];

  DTXRemoteInvocationReceipt *receipt = [remoteProxy
    _IDE_initiateSessionWithIdentifier:self.context.sessionIdentifier
    forClient:self.class.clientProcessUniqueIdentifier
    atPath:self.class.clientProcessDisplayPath
    protocolVersion:@(FBProtocolVersion)];
  [receipt handleCompletion:^(NSNumber *version, NSError *error){
    if (error || !version) {
      [self.logger logFormat:@"Client Daemon Interface failed, trying legacy format."];
      [self setupLegacyProtocolConnectionViaRemoteProxy:remoteProxy proxyChannel:proxyChannel];
      return;
    }

    [self.logger logFormat:@"testmanagerd handled session request using protcol version %ld.", (long)FBProtocolVersion];
    [proxyChannel cancel];
  }];
}

- (DTXRemoteInvocationReceipt *)setupLegacyProtocolConnectionViaRemoteProxy:(id<XCTestManager_DaemonConnectionInterface>)remoteProxy proxyChannel:(DTXProxyChannel *)proxyChannel
{
  DTXRemoteInvocationReceipt *receipt = [remoteProxy
    _IDE_beginSessionWithIdentifier:self.context.sessionIdentifier
    forClient:self.class.clientProcessUniqueIdentifier
    atPath:self.class.clientProcessDisplayPath];
  [receipt handleCompletion:^(NSNumber *version, NSError *error) {
    if (error) {
      [self concludeWithResult:[FBTestBundleResult failedInError:[[XCTestBootstrapError describe:@"Client Daemon Interface failed"] causedBy:error]]];
      return;
    }

    [self.logger logFormat:@"testmanagerd handled session request using legacy protocol."];
    [proxyChannel cancel];
  }];
  return receipt;
}

- (void)bundleDisconnectedWithState:(FBTestBundleConnectionState)state
{
  dispatch_async(self.target.workQueue, ^{
    [self.logger logFormat:@"Bundle Connection Disconnected in state '%@'", state];

    if (self.result) {
      return;
    }
    if (self.state == FBTestBundleConnectionStateEndedTestPlan) {
      [self concludeWithResult:FBTestBundleResult.success];
      return;
    }

    if ([self checkForCrashedProcess]) {
      return;
    }
    XCTestBootstrapError *error = [[XCTestBootstrapError
      describeFormat:@"Lost connection to test process with state '%@'", state]
      code:XCTestBootstrapErrorCodeLostConnection];
    [self concludeWithResult:[FBTestBundleResult failedInError:error]];
  });
}

- (BOOL)shouldCheckForCrashedProcess
{
  if (!FBXcodeConfiguration.isXcode8OrGreater) {
    return NO;
  }

  return [NSDate.date compare:[self.lastCrashCheckDate dateByAddingTimeInterval:CrashCheckInterval]] != NSOrderedAscending;
}

- (nullable FBTestBundleResult *)checkForCrashedProcess
{
  // Set the Crash Date Check.
  self.lastCrashCheckDate = NSDate.date;

  NSError *innerError;
  pid_t pid = [self.target.deviceOperator processIDWithBundleID:self.context.testRunnerBundleID error:&innerError];
  if (pid >= 1) {
    return nil;
  }
  // It make some time for the diagnostic to appear.
  FBDiagnostic *diagnostic = [NSRunLoop.currentRunLoop spinRunLoopWithTimeout:FBControlCoreGlobalConfiguration.fastTimeout untilExists:^ FBDiagnostic * {
    return [self.target.deviceOperator
      attemptToFindCrashLogForProcess:self.context.testRunnerPID
      bundleID:self.context.testRunnerBundleID
      sinceDate:self.applicationLaunchDate];
  }];
  if (!diagnostic.hasLogContent) {
    XCTestBootstrapError *error = [[XCTestBootstrapError
      describe:@"Test Process likely crashed but a crash log could not be obtained"]
      code:XCTestBootstrapErrorCodeLostConnection];
    return [self concludeWithResult:[FBTestBundleResult failedInError:error]];
  }
  FBTestBundleResult *result = [FBTestBundleResult bundleCrashedDuringTestRun:diagnostic];
  return [self concludeWithResult:result];
}

- (FBTestBundleResult *)concludeWithResult:(FBTestBundleResult *)result
{
  [self.logger logFormat:@"Test Completed with Result: %@", result];
  self.result = result;
  self.state = FBTestBundleConnectionStateResultAvailable;

  // Fire the futures
  NSError *error = result.error;
  if (error) {
    [self.connectFuture resolveWithError:error];
    [self.testPlanFuture resolveWithError:error];
    [self.disconnectFuture resolveWithError:error];
  } else {
    [self.connectFuture resolveWithResult:result];
    [self.testPlanFuture resolveWithResult:result];
    [self.disconnectFuture resolveWithResult:result];
  }

  return result;
}

#pragma mark XCTestDriverInterface

- (id)_XCT_didBeginExecutingTestPlan
{
  if (self.state != FBTestBundleConnectionStateAwaitingStartOfTestPlan) {
    XCTestBootstrapError *error = [XCTestBootstrapError
      describeFormat:@"Test Plan Started, but state is %@", self.state];
    [self concludeWithResult:[FBTestBundleResult failedInError:error]];
    return nil;
  }
  [self.logger logFormat:@"Test Plan Started"];
  self.state = FBTestBundleConnectionStateExecutingTestPlan;
  return [self.interface _XCT_didBeginExecutingTestPlan];
}

- (id)_XCT_didFinishExecutingTestPlan
{
  if (self.state != FBTestBundleConnectionStateExecutingTestPlan) {
    XCTestBootstrapError *error = [XCTestBootstrapError
      describeFormat:@"Test Plan Ended, but state is %@", self.state];
    [self concludeWithResult:[FBTestBundleResult failedInError:error]];
    return nil;
  }
  [self.logger logFormat:@"Test Plan Ended"];
  self.state = FBTestBundleConnectionStateEndedTestPlan;
  [self.testPlanFuture resolveWithResult:FBTestBundleResult.success];
  return [self.interface _XCT_didFinishExecutingTestPlan];
}

- (id)_XCT_testBundleReadyWithProtocolVersion:(NSNumber *)protocolVersion minimumVersion:(NSNumber *)minimumVersion
{
  NSInteger protocolVersionInt = protocolVersion.integerValue;
  NSInteger minimumVersionInt = minimumVersion.integerValue;

  self.testBundleProtocolVersion = protocolVersionInt;

  [self.logger logFormat:@"Test bundle is ready, running protocol %ld, requires at least version %ld. IDE is running %ld and requires at least %ld", protocolVersionInt, minimumVersionInt, FBProtocolVersion, FBProtocolMinimumVersion];
  if (minimumVersionInt > FBProtocolVersion) {
    XCTestBootstrapError *error = [[XCTestBootstrapError
      describeFormat:@"Protocol mismatch: test process requires at least version %ld, IDE is running version %ld", minimumVersionInt, FBProtocolVersion]
      code:XCTestBootstrapErrorCodeStartupFailure];
    [self concludeWithResult:[FBTestBundleResult failedInError:error]];
    return nil;
  }
  if (protocolVersionInt < FBProtocolMinimumVersion) {
    XCTestBootstrapError *error = [[XCTestBootstrapError
      describeFormat:@"Protocol mismatch: IDE requires at least version %ld, test process is running version %ld", FBProtocolMinimumVersion,protocolVersionInt]
      code:XCTestBootstrapErrorCodeStartupFailure];
    [self concludeWithResult:[FBTestBundleResult failedInError:error]];
    return nil;
  }
  if (!self.target.deviceOperator.requiresTestDaemonMediationForTestHostConnection) {
    XCTestBootstrapError *error = [[XCTestBootstrapError
      describe:@"Test Bundle Connection cannot handle a Device that doesn't require daemon mediation"]
      code:XCTestBootstrapErrorCodeStartupFailure];
    [self concludeWithResult:[FBTestBundleResult failedInError:error]];
    return nil;
  }

  [self.logger logFormat:@"Test Bundle is Ready"];
  self.state = FBTestBundleConnectionStateTestBundleReady;
  [self.connectFuture resolveWithResult:FBTestBundleResult.success];
  return [self.interface _XCT_testBundleReadyWithProtocolVersion:protocolVersion minimumVersion:minimumVersion];
}

- (id)_XCT_didBeginInitializingForUITesting
{
  [self.logger log:@"Started initilizing for UI testing."];
  return nil;
}

- (id)_XCT_initializationForUITestingDidFailWithError:(NSError *)error
{
  XCTestBootstrapError *trueError = [[[XCTestBootstrapError
    describe:@"Failed to initilize for UI testing"]
    causedBy:error]
   code:XCTestBootstrapErrorCodeStartupFailure];
  [self concludeWithResult:[FBTestBundleResult failedInError:trueError]];
  return nil;
}

@end

#pragma clang diagnostic pop
