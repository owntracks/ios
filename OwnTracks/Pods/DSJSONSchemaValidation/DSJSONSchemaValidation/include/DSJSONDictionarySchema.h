//
//  DSJSONDictionarySchema.h
//  DSJSONSchemaValidation
//
//  Created by Andrew Podkovyrin on 11/08/2018.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSJSONSchema.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSJSONDictionarySchema : DSJSONSchema

/**
 Creates and returns a schema configured using a dictionary containing the JSON Schema representation.
 @param schemaDictionary Dictionary containing the JSON Schema representation.
 @param baseURI Optional base resolution scope URI of the created schema (e.g., URL the schema was loaded from). Resolution scope of the created schema may be overriden by "id" property of the schema.
 @param referenceStorage Optional schema storage to resolve external references. This storage must contain all external schemas referenced by the instantiated schema (if there are any), otherwise instantiation will fail.
 @param specification Schema specification version. Serves as a configuration for validation process.
 @param options Schema validation options. Different options that allows to change default behaviour of the validator classes.
 @param error Error object to contain any error encountered during instantiation of the schema.
 @return Configured schema object, or nil if an error occurred.
 */
+ (nullable instancetype)schemaWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary baseURI:(nullable NSURL *)baseURI referenceStorage:(nullable DSJSONSchemaStorage *)referenceStorage specification:(DSJSONSchemaSpecification *)specification options:(DSJSONSchemaValidationOptions *)options error:(NSError * __autoreleasing *)error;

+ (nullable instancetype)schemaWithObject:(id)foundationObject baseURI:(nullable NSURL *)baseURI referenceStorage:(nullable DSJSONSchemaStorage *)referenceStorage specification:(DSJSONSchemaSpecification *)specification options:(nullable DSJSONSchemaValidationOptions *)options error:(NSError * __autoreleasing *)error NS_UNAVAILABLE;
+ (nullable instancetype)schemaWithData:(NSData *)schemaData baseURI:(nullable NSURL *)baseURI referenceStorage:(nullable DSJSONSchemaStorage *)referenceStorage specification:(DSJSONSchemaSpecification *)specification options:(nullable DSJSONSchemaValidationOptions *)options error:(NSError * __autoreleasing *)error NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
