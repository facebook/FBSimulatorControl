/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import <FBSimulatorControl/FBSimulatorControl.h>

#import "FBSimulatorControlFixtures.h"

@interface FBLogSearchTests : XCTestCase

@end

@implementation FBLogSearchTests

- (void)testFindsFirstMatchingLineInFileDiagnostic
{
  FBLogSearch *searcher = [FBLogSearch withDiagnostic:self.simulatorSystemLog predicate:[FBLogSearchPredicate substrings:@[
    @"LOLIDK",
    @"Installed apps did change",
    @"Couldn't find the digitizer HID service, this is probably bad"
  ]]];
  XCTAssertEqualObjects(searcher.firstMatchingLine, @"Mar  7 16:50:18 some-hostname SpringBoard[24911]: Installed apps did change.");
}

- (void)testFailsToFindAbsentSubstrings
{
  FBLogSearch *searcher = [FBLogSearch withDiagnostic:self.simulatorSystemLog predicate:[FBLogSearchPredicate substrings:@[
    @"LOLIDK",
    @"LOLIDK1",
    @"LOLIDK2"
  ]]];
  XCTAssertNil(searcher.firstMatchingLine);
}

- (void)testFindsFirstMatchingLineInFileRegex
{
  FBLogSearch *searcher = [FBLogSearch withDiagnostic:self.simulatorSystemLog predicate:[FBLogSearchPredicate regex:
    @"layer position \\d+ \\d+ bounds \\d+ \\d+ \\d+ \\d+"
  ]];
  XCTAssertEqualObjects(searcher.firstMatchingLine, @"Mar  7 16:50:18 some-hostname backboardd[24912]: layer position 375 667 bounds 0 0 750 1334");
}

- (void)testFailsToFindAbsentRegex
{
  FBLogSearch *searcher = [FBLogSearch withDiagnostic:self.simulatorSystemLog predicate:[FBLogSearchPredicate regex:
    @"layer position \\D+ \\d+ bounds \\d+ \\d+ \\d+ \\d+"
  ]];
  XCTAssertNil(searcher.firstMatchingLine);
}

- (void)testDoesNotFindInBinaryDiagnostics
{
  FBLogSearch *searcher = [FBLogSearch withDiagnostic:self.photoDiagnostic predicate:[FBLogSearchPredicate substrings:@[
    @"LOLIDK",
    @"Installed apps did change",
    @"Couldn't find the digitizer HID service, this is probably bad"
  ]]];
  XCTAssertNil(searcher.firstMatchingLine);
}

@end
