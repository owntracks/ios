//
//  DSJSONSchemaStorage.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 7/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSJSONSchema;

/**
 Serves as a storage of schemas, allowing for quick access to any schema or subschema stored in it by its scope URI.
 @discussion Instances of this class are immutable. To create a mutable storage, use `DSMutableJSONSchemaStorage` class.
 Note that schemas added into a storage should have their base scope URI explicitly specified either during instantiation or using "id" schema keyword. Otherwise, if this URI is empty, it might conflict with other schemas or make retrieving those schemas by URI more difficult.
 */
@interface DSJSONSchemaStorage : NSObject <NSCopying, NSMutableCopying>

/**
 Creates and returns an empty storage.
 @return An empty storage.
 */
+ (instancetype)storage;
/**
 Creates and returns a storage with the specified schema and all its subschemas added into it.
 @param schema Schema to initialize the storage with.
 @return Created storage, or nil if specified schema contained subschemas with duplicate scope URIs.
 */
+ (nullable instancetype)storageWithSchema:(DSJSONSchema *)schema;
/**
 Creates and returns a storage with the specified schemas and all their respective subschemas added into it.
 @param schemas Array of schemas to initialize the storage with.
 @return Created storage, or nil if specified schemas contained duplicate scope URIs.
 */
+ (nullable instancetype)storageWithSchemasArray:(NSArray<DSJSONSchema *> *)schemas;

/**
 Returns a new storage containing existing schemas in the receiver and the specified schema.
 @param schema Schema added to the newly created storage.
 @return A new storage, or nil if specified schema contained duplicate scope URIs, whether by itself or with respect to existing schemas in the receiver.
 */
- (nullable instancetype)storageByAddingSchema:(DSJSONSchema *)schema;

/**
 Returns a stored schema by its scope URI.
 @param schemaURI Scope URI of the schema or subschema to return.
 @return Schema with the specified scope URI, or nil if such schema was not found in the receiver.
 */
- (nullable DSJSONSchema *)schemaForURI:(NSURL *)schemaURI;

@end

/**
 Mutable counterpart of `DSJSONSchemaStorage` class.
 */
@interface DSMutableJSONSchemaStorage : DSJSONSchemaStorage

/**
 Adds the specified schema and all its subschemas into receiver.
 @param schema Schema to add into the receiver.
 @return YES if the specified schema and all its subschemas were added successfully, NO if it contained duplicate scope URIs, whether by itself or with respect to existing schemas in the receiver.
 */
- (BOOL)addSchema:(DSJSONSchema *)schema;

@end

NS_ASSUME_NONNULL_END
