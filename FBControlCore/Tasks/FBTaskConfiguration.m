/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTaskConfiguration.h"

#import "FBCollectionInformation.h"

@implementation FBTaskConfiguration

- (instancetype)initWithLaunchPath:(NSString *)launchPath arguments:(NSArray<NSString *> *)arguments environment:(NSDictionary<NSString *, NSString *> *)environment acceptableStatusCodes:(NSSet<NSNumber *> *)acceptableStatusCodes stdOut:(nullable id)stdOut stdErr:(nullable id)stdErr connectStdIn:(BOOL)connectStdIn
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _launchPath = launchPath;
  _arguments = arguments;
  _environment = environment;
  _acceptableStatusCodes = acceptableStatusCodes;
  _stdOut = stdOut;
  _stdErr = stdErr;
  _connectStdIn = connectStdIn;

  return self;
}

- (NSString *)description
{
  return [NSString stringWithFormat:
    @"Launch Path %@ | Arguments %@",
    self.launchPath,
    [FBCollectionInformation oneLineDescriptionFromArray:self.arguments]
  ];
}

@end
