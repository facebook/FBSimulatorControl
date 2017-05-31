/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import <FBControlCore/FBControlCore.h>

#import "FBiOSTargetDouble.h"

NS_ASSUME_NONNULL_BEGIN

@interface FBiOSTargetActionDouble : NSObject <FBiOSTargetAction>

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, assign, readonly) BOOL succeed;

@end

@implementation FBiOSTargetActionDouble

- (instancetype)initWithIdentifier:(NSString *)identifier succeed:(BOOL)succeed
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _identifier = identifier;
  _succeed = succeed;

  return self;
}

+ (FBiOSTargetActionType)actionType
{
  return @"test-double";
}

static NSString *const KeyIdentifier = @"identifier";
static NSString *const KeySucceed = @"succeed";

+ (nullable instancetype)inflateFromJSON:(id)json error:(NSError **)error
{
  NSString *identifier = json[KeyIdentifier];
  if (![identifier isKindOfClass:NSString.class]) {
    return [[FBControlCoreError
      describeFormat:@"%@ is not a String for %@", identifier, KeyIdentifier]
      fail:error];
  }
  NSNumber *succeed = json[KeySucceed];
  if (![succeed isKindOfClass:NSNumber.class]) {
    return [[FBControlCoreError
      describeFormat:@"%@ is not a Number for %@", succeed, KeySucceed]
      fail:error];
  }
  return [[FBiOSTargetActionDouble alloc] initWithIdentifier:identifier succeed:succeed.boolValue];
}

- (id)jsonSerializableRepresentation
{
  return @{
    KeyIdentifier: self.identifier,
    KeySucceed: @(self.succeed),
  };
}

- (BOOL)runWithTarget:(id<FBiOSTarget>)target delegate:(id<FBiOSTargetActionDelegate>)delegate error:(NSError **)error
{
  return self.succeed;
}

- (BOOL)isEqual:(FBiOSTargetActionDouble *)object
{
  if (![object isKindOfClass:self.class]) {
    return NO;
  }
  return [self.identifier isEqualToString:object.identifier] && self.succeed == object.succeed;
}

- (NSUInteger)hash
{
  return self.identifier.hash;
}

@end

@interface FBiOSActionReaderTests : XCTestCase <FBiOSActionReaderDelegate>

@property (nonatomic, strong, readwrite) FBiOSTargetDouble *target;
@property (nonatomic, strong, readwrite) FBiOSActionRouter *router;
@property (nonatomic, strong, readwrite) FBiOSActionReader *reader;
@property (nonatomic, strong, readwrite) NSPipe *pipe;
@property (nonatomic, strong, readwrite) NSMutableArray<id<FBiOSTargetAction>> *startedActions;
@property (nonatomic, strong, readwrite) NSMutableArray<id<FBiOSTargetAction>> *finishedActions;
@property (nonatomic, strong, readwrite) NSMutableArray<id<FBiOSTargetAction>> *failedActions;
@property (nonatomic, strong, readwrite) NSMutableArray<NSString *> *badInput;

@end

@implementation FBiOSActionReaderTests

- (NSData *)actionLine:(id<FBiOSTargetAction>)action
{
  NSMutableData *actionData = [[NSJSONSerialization dataWithJSONObject:[self.router jsonFromAction:action] options:0 error:nil] mutableCopy];
  [actionData appendData:[NSData dataWithBytes:"\n" length:1]];
  return actionData;
}

- (void)setUp
{
  self.target = [FBiOSTargetDouble new];
  self.router = [FBiOSActionRouter routerForTarget:self.target actionClasses:@[FBiOSTargetActionDouble.class]];
  self.pipe = NSPipe.pipe;
  self.reader = [FBiOSActionReader fileReaderForRouter:self.router delegate:self readHandle:self.pipe.fileHandleForReading writeHandle:self.pipe.fileHandleForWriting];
  self.startedActions = [NSMutableArray array];
  self.finishedActions = [NSMutableArray array];
  self.failedActions = [NSMutableArray array];
  self.badInput = [NSMutableArray array];

  NSError *error;
  BOOL success = [self.reader startListeningWithError:&error];
  XCTAssertNil(error);
  XCTAssertTrue(success);
}

- (void)testPassingAction
{
  FBiOSTargetActionDouble *inputAction = [[FBiOSTargetActionDouble alloc] initWithIdentifier:@"Foo" succeed:YES];
  [self.pipe.fileHandleForWriting writeData:[self actionLine:inputAction]];

  BOOL succeeded = [NSRunLoop.currentRunLoop spinRunLoopWithTimeout:FBControlCoreGlobalConfiguration.fastTimeout untilTrue:^BOOL{
    return [self.startedActions containsObject:inputAction] && [self.finishedActions containsObject:inputAction];
  }];
  XCTAssertTrue(succeeded);
}

- (void)testFailingAction
{
  FBiOSTargetActionDouble *inputAction = [[FBiOSTargetActionDouble alloc] initWithIdentifier:@"Foo" succeed:NO];
  [self.pipe.fileHandleForWriting writeData:[self actionLine:inputAction]];

  BOOL succeeded = [NSRunLoop.currentRunLoop spinRunLoopWithTimeout:FBControlCoreGlobalConfiguration.fastTimeout untilTrue:^BOOL{
    return [self.startedActions containsObject:inputAction] && [self.failedActions containsObject:inputAction];
  }];
  XCTAssertTrue(succeeded);
}

- (void)testInterpretedInputWithGarbageInput
{
  NSData *data = [@"asdaad asasd asda d\n" dataUsingEncoding:NSUTF8StringEncoding];
  [self.pipe.fileHandleForWriting writeData:data];

  BOOL succeeded = [NSRunLoop.currentRunLoop spinRunLoopWithTimeout:FBControlCoreGlobalConfiguration.fastTimeout untilTrue:^BOOL{
    return self.badInput.count == 1;
  }];
  XCTAssertTrue(succeeded);
}

#pragma mark Delegate

- (void)readerDidFinishReading:(FBiOSActionReader *)reader
{
}

- (nullable NSString *)reader:(FBiOSActionReader *)reader failedToInterpretInput:(NSString *)input error:(NSError *)error
{
  [self.badInput addObject:input];
  return nil;
}

- (nullable NSString *)reader:(FBiOSActionReader *)reader willStartPerformingAction:(id<FBiOSTargetAction>)action onTarget:(id<FBiOSTarget>)target
{
  [self.startedActions addObject:action];
  return nil;
}

- (nullable NSString *)reader:(FBiOSActionReader *)reader didProcessAction:(id<FBiOSTargetAction>)action onTarget:(id<FBiOSTarget>)target
{
  [self.finishedActions addObject:action];
  return nil;
}

- (nullable NSString *)reader:(FBiOSActionReader *)reader didFailToProcessAction:(id<FBiOSTargetAction>)action onTarget:(id<FBiOSTarget>)target error:(NSError *)error
{
  [self.failedActions addObject:action];
  return nil;
}

@end

NS_ASSUME_NONNULL_END
