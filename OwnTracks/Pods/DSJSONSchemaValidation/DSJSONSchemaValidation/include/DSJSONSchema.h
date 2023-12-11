//
//  DSJSONSchema.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 28/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSJSONSchemaValidator.h"
#import "DSJSONSchemaStorage.h"
#import "DSJSONSchemaErrors.h"
#import "DSJSONSchemaSpecification.h"
#import "DSJSONSchemaValidationOptions.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Defines an object describing a JSON Schema, capable of validating objects against its configuration.
 @discussion Basic setup of this class allows validating JSON-decoded objects with schemas authored in JSON Schema, draft 4 format. To create a schema object, use one of the provided factory methods, specifying the root schema object to parse, either JSON-encoded or decoded. Note that creating schema objects is a resource-heavy process, so created schemas should be cached as possible.
 
 Root schema parsing process uses $schema property to check that specified schema object was created using an expected schema format. If it is not present or not recognized, default (JSON Schema, draft 4) is implied. If an incompatible schema format is encountered, creating the schema instance will fail.
 
 To extend the functionality of schema validation beyond the standard keywords, users of this class may register validator classes with custom keywords that will be used as necessary. To make sure that custom keywords are processed, specified root schema must contain a $schema property with a value equal to the one specified when the custom validator was registered.
 
 @warning There are a few caveats of using this class:
 
 - Regular expression patterns are validated using NSRegularExpression, which uses ICU implementation, not ECMA 262. Thus, some features like look-behind are not supported.
 - Loading schema references from external locations is not supported. Please use `DSJSONSchemaStorage` class to provide external references manually.
 - Schema keywords defined inside a schema reference (object with "$ref" property) are ignored as per JSON Reference specification draft.
 
 */
@interface DSJSONSchema : NSObject

/** Normalized URI resolution scope of the receiver. */
@property (nonatomic, readonly, strong) NSURL *uri;
/** Title of the receiver. */
@property (nonatomic, nullable, readonly, copy) NSString *title;
/** Description of the receiver. */
@property (nonatomic, nullable, readonly, copy) NSString *schemaDescription;
/** Instance validators defined in the receiver. */
@property (nonatomic, nullable, readonly, copy) NSArray<id<DSJSONSchemaValidator>> *validators;
/**
 Subschemas defined in the receiver that are not bound to any keywords.
 @discussion These nested schemas are not used directly for validation, but they could be referenced by other schemas.
 */
@property (nonatomic, nullable, readonly, copy) NSArray<DSJSONSchema *> *subschemas;
/** Schema specification version. */
@property (nonatomic, readonly, strong) DSJSONSchemaSpecification *specification;
/** Schema validation options. */
@property (nonatomic, readonly, strong) DSJSONSchemaValidationOptions *options;

/**
 Creates and returns a schema configured using a Foundation object (NSDictionary, NSNumber, ...) containing the JSON Schema representation.
 @param foundationObject Foundation object the JSON Schema representation. @param baseURI Optional base resolution scope URI of the created schema (e.g., URL the schema was loaded from). Resolution scope of the created schema may be overriden by "id" property of the schema.
 @param referenceStorage Optional schema storage to resolve external references. This storage must contain all external schemas referenced by the instantiated schema (if there are any), otherwise instantiation will fail.
 @param specification Schema specification version. Serves as a configuration for validation process.
 @param options Schema validation options. Different options that allows to change default behaviour of the validator classes.
 @param error Error object to contain any error encountered during instantiation of the schema.
 @return Configured schema object, or nil if an error occurred.
 */
+ (nullable instancetype)schemaWithObject:(id)foundationObject baseURI:(nullable NSURL *)baseURI referenceStorage:(nullable DSJSONSchemaStorage *)referenceStorage specification:(DSJSONSchemaSpecification *)specification options:(nullable DSJSONSchemaValidationOptions *)options error:(NSError * __autoreleasing *)error;
/**
 Acts similarly to `+schemaWithObject:baseURI:referenceStorage:specification:error:`, but retrieves the schema object from the specified JSON-encoded data.
 */
+ (nullable instancetype)schemaWithData:(NSData *)schemaData baseURI:(nullable NSURL *)baseURI referenceStorage:(nullable DSJSONSchemaStorage *)referenceStorage specification:(DSJSONSchemaSpecification *)specification options:(nullable DSJSONSchemaValidationOptions *)options error:(NSError * __autoreleasing *)error;

/**
 Attempts to validate the specified object against the configuration of the receiver.
 @discussion Internally, this method calls `-validateObject:inContext:error:` method with nil context.
 @param object The validated object.
 @param error Error object to contain the first encountered validation error.
 @return YES, if validation passed successfully, otherwise NO.
 */
- (BOOL)validateObject:(id)object withError:(NSError * __autoreleasing *)error;
/**
 Acts similarly to `-validateObject:withError:`, but retrieves the validated object from the specified JSON-encoded data.
 */
- (BOOL)validateObjectWithData:(NSData *)data error:(NSError * __autoreleasing *)error;

/**
 Recursively enumerates all subschemas starting with the receiver.
 @param block The block executed for the enumeration, taking two parameters: the current block being enumerated and a reference to a Boolean value that the block can use to stop the enumeration by setting `*stop = YES`.
 @return Whether enumeration has been interrupted using `stop`.
 */
- (BOOL)visitUsingBlock:(void (^)(DSJSONSchema *subschema, BOOL *stop))block;

#pragma mark - Internal methods

/**
 Designated initializer.
 @discussion This initializer is used by the implementation and subclasses. Use one of the convenience factory methods instead.
 */
- (instancetype)initWithScopeURI:(NSURL *)uri title:(nullable NSString *)title description:(nullable NSString *)description validators:(nullable NSArray<id<DSJSONSchemaValidator>> *)validators subschemas:(nullable NSArray<DSJSONSchema *> *)subschemas specification:(DSJSONSchemaSpecification *)specification options:(nullable DSJSONSchemaValidationOptions *)options;

/**
 Attempts to validate the specified object against the configuration of the receiver.
 @discussion This method should be used by validator objects to validate JSON object against their subschemas. The `context` object should usually be passed in this method as-is: it is used by the schemas to detect infinite loops in the validation.
 @param object The validated object.
 @param context Current validation context. If nil, this method will create a new context.
 @param error Error object to contain the first encountered validation error. Validation errors contain references to the failed validator, failed object and a JSON Pointer path to that object. See DSJSONSchemaErrors.h for more details.
 @return YES, if validation passed successfully, otherwise NO.
 */
- (BOOL)validateObject:(id)object inContext:(nullable DSJSONSchemaValidationContext *)context error:(NSError * __autoreleasing *)error;

/**
 Registers the specified validator to be used with the specified metaschema URI.
 @discussion This method allows extending basic functionality of the schema validators by registering custom validators to be used with custom schema keywords. Set of keywords used in any particular case is determined by the $schema property of the root schema: if it's not present or its value corresponds to the standard schema format, only default validators are used; if other value is present, custom validators registered for that value will be used in addition to the standard validators.
 @warning Specifying nil or one of the standard values for `metaschemaURI` parameter results in the validator class being registered for all schemas and is thus discouraged. Attempting to register a validator class that handles a keyword (or keywords) already handled by another class will fail.
 @param validatorClass Validator class to register.
 @param metaschemaURI URI of the custom metaschema. This URI is only used for comparing purposes: the metaschema itself is not fetched from the URI.
 @param error Error object to contain any error encountered during registration of the validator class.
 @return YES, if validator class has been registered successfully, otherwise NO.
 */
+ (BOOL)registerValidatorClass:(Class<DSJSONSchemaValidator>)validatorClass forMetaschemaURI:(nullable NSURL *)metaschemaURI specification:(DSJSONSchemaSpecification *)specification withError:(NSError * __autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
