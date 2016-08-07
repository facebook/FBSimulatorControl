/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTestManagerTestReporterTestSuite.h"
#import "FBTestManagerTestReporterTestCase.h"

@interface FBTestManagerTestReporterTestSuite ()

@property (nonatomic) NSMutableArray<FBTestManagerTestReporterTestCase *> *mutableTestCases;
@property (nonatomic) NSMutableArray<FBTestManagerTestReporterTestSuite *> *mutableTestSuites;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *startTime;
@property (nonatomic, weak) FBTestManagerTestReporterTestSuite *parent;

@end

@implementation FBTestManagerTestReporterTestSuite

+ (instancetype)withName:(NSString *)name startTime:(NSString *)startTime
{
  return [[self alloc] initWithName:name startTime:startTime];
}

- (instancetype)initWithName:(NSString *)name startTime:(NSString *)startTime
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _name = [name copy];
  _startTime = [startTime copy];
  _mutableTestCases = [NSMutableArray array];
  _mutableTestSuites = [NSMutableArray array];

  return self;
}

- (NSArray<FBTestManagerTestReporterTestCase *> *)testCases
{
  return [self.mutableTestCases copy];
}

- (NSArray<FBTestManagerTestReporterTestSuite *> *)testSuites
{
  return [self.mutableTestSuites copy];
}

- (void)addTestCase:(FBTestManagerTestReporterTestCase *)testCase
{
  [self.mutableTestCases addObject:testCase];
}

- (void)addTestSuite:(FBTestManagerTestReporterTestSuite *)testSuite
{
  testSuite.parent = self;
  [self.mutableTestSuites addObject:testSuite];
}

#pragma mark -

- (NSString *)description
{
  return [NSString stringWithFormat:@"TestSuite %@ | Test Cases %zd | Test Suites %zd", self.name, self.testCases.count,
                                    self.testSuites.count];
}

@end
