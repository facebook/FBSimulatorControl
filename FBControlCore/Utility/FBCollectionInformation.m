/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBCollectionInformation.h"

#import "FBJSONConversion.h"

@implementation FBCollectionInformation

+ (NSString *)oneLineDescriptionFromArray:(NSArray *)array
{
  return [self oneLineDescriptionFromArray:array atKeyPath:@"description"];
}

+ (NSString *)oneLineDescriptionFromArray:(NSArray *)array atKeyPath:(NSString *)keyPath
{
  return [NSString stringWithFormat:@"[%@]", [[array valueForKeyPath:keyPath] componentsJoinedByString:@", "]];
}

+ (NSString *)oneLineJSONDescription:(id<FBJSONSerializable>)object
{
  return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:object.jsonSerializableRepresentation options:0 error:nil] encoding:NSUTF8StringEncoding];
}

+ (NSString *)oneLineDescriptionFromDictionary:(NSDictionary *)dictionary
{
  NSMutableString *string = [NSMutableString stringWithString:@"{"];
  for (NSString *key in dictionary.allKeys) {
    [string stringByAppendingFormat:@"%@ => %@, ", key, dictionary[key]];
  }
  [string appendString:@"}"];
  return string;
}

+ (BOOL)isArrayHeterogeneous:(NSArray *)array withClass:(Class)cls
{
  NSParameterAssert(cls);
  if (![array isKindOfClass:NSArray.class]) {
    return NO;
  }
  for (id object in array) {
    if (![object isKindOfClass:cls]) {
      return NO;
    }
  }
  return YES;
}

+ (BOOL)isDictionaryHeterogeneous:(NSDictionary *)dictionary keyClass:(Class)keyCls valueClass:(Class)valueCls
{
  NSParameterAssert(keyCls);
  NSParameterAssert(valueCls);
  if (![dictionary isKindOfClass:NSDictionary.class]) {
    return NO;
  }
  for (id object in dictionary.allKeys) {
    if (![object isKindOfClass:keyCls]) {
      return NO;
    }
  }
  for (id object in dictionary.allValues) {
    if (![object isKindOfClass:valueCls]) {
      return NO;
    }
  }
  return YES;
}

@end
