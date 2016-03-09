/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import <FBSimulatorControl/FBDebugDescribeable.h>
#import <FBSimulatorControl/FBJSONConversion.h>

/**
 Defines the content & metadata of a log.
 Lazily converts between the backing store data formats.
 */
@interface FBDiagnostic : NSObject <NSCopying, NSCoding, FBJSONSerializable, FBDebugDescribeable>

/**
 The name of the Log for uniquely identifying the log.
 */
@property (nonatomic, readonly, copy) NSString *shortName;

/**
 The File Extension of the log. The extension is used when writing to file.
 */
@property (nonatomic, readonly, copy) NSString *fileType;

/**
 A String representing this log's human readable name, as shown in error reports
 */
@property (nonatomic, readonly, copy) NSString *humanReadableName;

/**
 A File Path repesenting the location where files will be stored if they are when they are converted to be backed by a file.
 */
@property (nonatomic, readonly, copy) NSString *storageDirectory;

/**
 A String used to define where the log has been persisted to.
 This represents a more permenant or remote destination, as the File Path represented by `asPath` may be temporary.
 Can also be used to represent a URL or other identifier of a remote resource.
 */
@property (nonatomic, readonly, copy) NSString *destination;

/**
 The content of the log, if representable as NSData.
 */
@property (nonatomic, readonly, copy) NSData *asData;

/**
 The content of the log, if representable by String.
 */
@property (nonatomic, readonly, copy) NSString *asString;

/**
 The content of the log, if representable as a File Path.
 */
@property (nonatomic, readonly, copy) NSString *asPath;

/**
 The content of the log, if representable as a JSON Object in Native Containers.
 */
@property (nonatomic, readonly, copy) id asJSON;

/**
 Whether the log has content or is missing/empty.
 */
@property (nonatomic, readonly, assign) BOOL hasLogContent;

/**
 Whether or not the log can be searched as Text.
 */
@property (nonatomic, readonly, assign) BOOL isSearchableAsText;

/**
 Writes the FBDiagnostic out to a file path in the most efficient way for the backing store of the log.

 @param path the File Path write to.
 @param error an error out for any error that occurs.
 @return YES if successful, NO otherwise.
 */
- (BOOL)writeOutToPath:(NSString *)path error:(NSError **)error;

@end

/**
 The Builder for a `FBDiagnostic` as `FBDiagnostic` is immutable.
 */
@interface FBDiagnosticBuilder : NSObject

/**
 Creates a new `FBDiagnosticBuilder` with an empty `diagnostic`.
 */
+ (instancetype)builder;

/**
 Creates a new `FBDiagnosticBuilder` copying all of the values from `diagnostic`.

 @param diagnostic the original Diagnostic to copy values from.
 @return the reciever, for chaining.
 */
+ (instancetype)builderWithDiagnostic:(FBDiagnostic *)diagnostic;

/**
 Updates the Diagnostic in the builder.

 @param diagnostic the original Diagnostic to copy values from.
 @return the reciever, for chaining.
 */
- (instancetype)updateDiagnostic:(FBDiagnostic *)diagnostic;

/**
 Updates the `shortName` of the underlying `FBDiagnostic`.

 @param shortName the Short Name to update with.
 @return the reciever, for chaining.
 */
- (instancetype)updateShortName:(NSString *)shortName;

/**
 Updates the `fileType` of the underlying `FBDiagnostic`.

 @param fileType the File Type to update with.
 @return the reciever, for chaining.
 */
- (instancetype)updateFileType:(NSString *)fileType;

/**
 Updates the `humanReadableName` of the underlying `FBDiagnostic`.

 @param humanReadableName the Human Readable Name to update with.
 @return the reciever, for chaining.
 */
- (instancetype)updateHumanReadableName:(NSString *)humanReadableName;

/**
 Updates the `storageDirectory` of the underlying `FBDiagnostic`.

 @param storageDirectory the Human Readable Name to update with.
 @return the reciever, for chaining.
 */
- (instancetype)updateStorageDirectory:(NSString *)storageDirectory;

/**
 Updates the `destination` of the underlying `FBDiagnostic`.

 @param destination the Destination to update with.
 @return the reciever, for chaining.
 */
- (instancetype)updateDestination:(NSString *)destination;

/**
 Updates the underlying `FBDiagnostic` with Data.
 Will replace any previous path or string that represent the log.

 @param data the Date to update with.
 @return the reciever, for chaining.
 */
- (instancetype)updateData:(NSData *)data;

/**
 Updates the underlying `FBDiagnostic` with a String.
 Will replace any previous data or path that represent the log.

 @param string the String to update with.
 @return the reciever, for chaining.
 */
- (instancetype)updateString:(NSString *)string;

/**
 Updates the underlying `FBDiagnostic` with a File Path.
 Will replace any data or string associated with the log.

 @param path the File Path to update with.
 @return the reciever, for chaining.
 */
- (instancetype)updatePath:(NSString *)path;

/**
 Updates the underlying `FBDiagnostic` with JSON Encoded String.
 Will replace any data, string or path associated with the log.

 @param jsonSerializable Can be either an FBJSONSerializable 
                         or an object that meets the requirements of NSJSONSerialization.
 @return the reciever, for chaining.
 */
- (instancetype)updateJSONSerializable:(id)jsonSerializable;

/**
 Returns a File Path suitable for writing data into.
 Once writing to the file has been successful, the builder should be updated with `updatePath`.

 @return a path to write data into.
 */
- (NSString *)createPath;

/**
 Updates the underlying `FBDiagnostic` by applying a block that will write data into a file path.
 The block should:
 1) Be non-null
 2) Write data into the path provided.
 3) If writing was successful, YES should be returned.
 4) If writing was not successful, NO should be returned.
 If writing to the file was succesful, YES

 @param block a block to populate a file path with.
 @return the reciever, for chaining.
 */
- (instancetype)updatePathFromBlock:( BOOL (^)(NSString *path) )block;

/**
 Returns a new `FBDiagnostic` with the reciever's updates applied.
 */
- (FBDiagnostic *)build;

@end
