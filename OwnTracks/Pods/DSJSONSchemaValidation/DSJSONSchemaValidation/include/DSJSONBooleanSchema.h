//
//  DSJSONBooleanSchema.h
//  DSJSONSchemaValidation
//
//  Created by Andrew Podkovyrin on 11/08/2018.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSJSONSchema.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSJSONBooleanSchema : DSJSONSchema

/**
 Creates and returns a schema configured using a NSNumber (boolean) containing the JSON Schema representation.
 @param schemaNumber Number containing the Boolean JSON Schema representation.
 @param baseURI Optional base resolution scope URI of the created schema (e.g., URL the schema was loaded from). Resolution scope of the created schema may be overriden by "id" property of the schema.
 @param specification Schema specification version. Serves as a configuration for validation process.
 @param options Schema validation options. Different options that allows to change default behaviour of the validator classes.
 @param error Error object to contain any error encountered during instantiation of the schema.
 @return Configured schema object, or nil if an error occurred.
 */
+ (nullable instancetype)schemaWithNumber:(NSNumber *)schemaNumber baseURI:(nullable NSURL *)baseURI specification:(DSJSONSchemaSpecification *)specification options:(DSJSONSchemaValidationOptions *)options error:(NSError * __autoreleasing *)error;

/**
 Designated initializer
 */
- (instancetype)initWithScopeURI:(NSURL *)uri schemaValue:(BOOL)schemaValue specification:(DSJSONSchemaSpecification *)specification options:(DSJSONSchemaValidationOptions *)options;

+ (nullable instancetype)schemaWithObject:(id)foundationObject baseURI:(nullable NSURL *)baseURI referenceStorage:(nullable DSJSONSchemaStorage *)referenceStorage specification:(DSJSONSchemaSpecification *)specification options:(nullable DSJSONSchemaValidationOptions *)options error:(NSError * __autoreleasing *)error NS_UNAVAILABLE;
+ (nullable instancetype)schemaWithData:(NSData *)schemaData baseURI:(nullable NSURL *)baseURI referenceStorage:(nullable DSJSONSchemaStorage *)referenceStorage specification:(DSJSONSchemaSpecification *)specification options:(nullable DSJSONSchemaValidationOptions *)options error:(NSError * __autoreleasing *)error NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
