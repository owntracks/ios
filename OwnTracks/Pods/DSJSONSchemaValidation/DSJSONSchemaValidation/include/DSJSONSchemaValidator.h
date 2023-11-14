//
//  DSJSONSchemaValidator.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 28/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSJSONSchema;
@class DSJSONSchemaFactory;
@class DSJSONSchemaValidationContext;

/**
 Describes an object that can be used to validate a JSON instance.
 @discussion To define a custom validator with one or more keywords assigned to it, create a class that conforms to this protocol and register it with `DSJSONSchema` class using its `+registerValidatorClass:forMetaschemaURI:withError:` method. You don't need to instantiate validators manually - it is done as part of the schema parsing process.
 @warning To ensure thread-safety, all validators must be immutable: do not allow changing their configuration after they are created using `+validatorWithDictionary:schemaFactory:error:` method. Additionally, calling `-subschemas` or `-validateInstance:withError:` methods must have no side-effects on the validator.
 */
@protocol DSJSONSchemaValidator <NSObject>

/** Returns a set of JSON Schema keywords assigned to the receiver. */
+ (NSSet<NSString *> *)assignedKeywords;

/**
 Creates and returns a validator configured using a dictionary containing data from JSON Schema.
 @param schemaDictionary Dictionary of schema properties relevant to the created validator instance.
 @param schemaFactory Factory used to instantiate nested schemas for the validator.
 @param error Error object to contain any error encountered during initialization of the receiver.
 @return Configured validator object, or nil if there was an error during initialization of the instance.
 */
+ (nullable instancetype)validatorWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary schemaFactory:(DSJSONSchemaFactory *)schemaFactory error:(NSError * __autoreleasing *)error;

/** Returns an array of all nested schemas used in the receiver. */
- (nullable NSArray<DSJSONSchema *> *)subschemas;

/**
 Attempts to validate the specified JSON instance.
 @param instance The validated JSON instance.
 @param context Current validation context used for infinite loops detection and validation path collection. Custom validators usually pass it to the subschemas' validation method as-is, if necessary; however, if the validator uses a subschema to validate an item inside the provided instance (e.g., an object property or an array item), it must push the key for that item as a path component into the context before validating it against the subschema, and pop the path component afterwards. This will ensure correct generation of validation paths used in validation errors.
 @param error Error object to contain the first encountered validation error.
 @return YES, if validation passed successfully, otherwise NO.
 */
- (BOOL)validateInstance:(id)instance inContext:(DSJSONSchemaValidationContext *)context error:(NSError * __autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
