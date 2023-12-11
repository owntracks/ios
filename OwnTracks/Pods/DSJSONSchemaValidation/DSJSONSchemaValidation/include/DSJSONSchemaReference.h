//
//  DSJSONSchemaReference.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 28/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchema.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Defines a "proxy" schema, representing a reference to another schema via an URI.
 @discussion Instances of this class delegate validation to the actual referenced schema. They are usually created as a part of root schema parsing process to represent JSON references to nested schemas, and are also resolved later on in that process. If an unresolvable reference or a reference loop is encountered, parsing process is stopped and an error is reported.
 @warning Attempting to validate an object using unresolved schema reference throws an exception.
 */
@interface DSJSONSchemaReference : DSJSONSchema

/** URI of the referenced schema. */
@property (nonatomic, readonly, strong) NSURL *referenceURI;
/** The referenced schema. The value of this property is nil until receiver is dereferenced. */
@property (nonatomic, readonly, weak) DSJSONSchema *referencedSchema;

/** Initializes the receiver with scope URI and reference URI, leaving title, description and own set of validators as nil. */
- (instancetype)initWithScopeURI:(NSURL *)uri referenceURI:(NSURL *)referenceURI subschemas:(nullable NSArray<DSJSONSchema *> *)subschemas specification:(DSJSONSchemaSpecification *)specification options:(DSJSONSchemaValidationOptions *)options;

/**
 Resolves receiver's reference URI with the specified schema.
 @warning Schema references are usually resolved automatically during the root schema parsing process. Calling this method second time will throw an exception.
 */
- (void)resolveReferenceWithSchema:(DSJSONSchema *)schema;

+ (nullable instancetype)schemaWithObject:(id)foundationObject baseURI:(nullable NSURL *)baseURI referenceStorage:(nullable DSJSONSchemaStorage *)referenceStorage specification:(DSJSONSchemaSpecification *)specification options:(nullable DSJSONSchemaValidationOptions *)options error:(NSError * __autoreleasing *)error NS_UNAVAILABLE;
+ (nullable instancetype)schemaWithData:(NSData *)schemaData baseURI:(nullable NSURL *)baseURI referenceStorage:(nullable DSJSONSchemaStorage *)referenceStorage specification:(DSJSONSchemaSpecification *)specification options:(nullable DSJSONSchemaValidationOptions *)options error:(NSError * __autoreleasing *)error NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
