//
//  DSJSONSchemaValidationOptions.h
//  DSJSONSchemaValidationTests
//
//  Created by Andrew Podkovyrin on 22/08/2018.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Option to control the "additionalProperties" behavior.
 @see https://github.com/epoberezkin/ajv#filtering-data
 */
typedef NS_ENUM(NSUInteger, DSJSONSchemaValidationOptionsRemoveAdditional) {
    /** Default behavior. */
    DSJSONSchemaValidationOptionsRemoveAdditionalNone,
    /** Disallowed property will be removed if "additionalProperties" is boolean schema */
    DSJSONSchemaValidationOptionsRemoveAdditionalYes,
    
    // TODO: implement other removeAdditional options
//    /** All properties that disallowed by "additionalProperties" will be removed. */
//    DSJSONSchemaValidationOptionsRemoveAdditionalAll,
//    /** Disallowed property will be removed regardless of its value or if its value is failing the schema in the inner "additionalProperties". */
//    DSJSONSchemaValidationOptionsRemoveAdditionalFailing,
};

/** Different options that allows to change default behaviour of the validator classes. */
@interface DSJSONSchemaValidationOptions : NSObject

/**
 Allows filtering data during the validation.
 Changes the behavior of "additionalProperties" keyword validator.
 Default is `DSJSONSchemaValidationOptionsRemoveAdditionalNone`.
 @see https://github.com/epoberezkin/ajv#filtering-data
 */
@property (nonatomic, assign) DSJSONSchemaValidationOptionsRemoveAdditional removeAdditional;

@end

NS_ASSUME_NONNULL_END
