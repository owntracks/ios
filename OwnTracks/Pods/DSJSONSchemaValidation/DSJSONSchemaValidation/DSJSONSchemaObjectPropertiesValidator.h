//
//  DSJSONSchemaObjectPropertiesValidator.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 1/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSJSONSchemaValidator.h"

NS_ASSUME_NONNULL_BEGIN

@class DSJSONSchema;

/**
 Implements "properties", "additionalProperties" and "patternProperties" keywords. Applicable to object instances.
 */
@interface DSJSONSchemaObjectPropertiesValidator : NSObject <DSJSONSchemaValidator>

/**
 Dictionary of schemas each corresponding property of a valid object instance must validate against. Keys are property names, values are schemas.
 */
@property (nonatomic, nullable, readonly, copy) NSDictionary<NSString *, DSJSONSchema *> *propertySchemas;

/** Schema to validate any object properties with keys beyond those contained in `propertySchemas`, if it is not nil. */
@property (nonatomic, nullable, readonly, strong) DSJSONSchema *additionalPropertiesSchema;
/**
 If NO, a valid object instance must contain no other keys other than those contained in `propertySchemas`. If the latter is nil, this property is not applicable.
 If YES, all properties in a valid object instance with names other than keys contained in `propertySchemas` must validate against `additionalPropertiesSchema`, unless the latter is nil.
 */
@property (nonatomic, readonly, assign) BOOL additionalPropertiesAllowed;

/**
 Dictionary of schemas each corresponding property of a valid object instance must validate against. Keys are regular expressions to match against property names, values are schemas.
 */
@property (nonatomic, nullable, readonly, copy) NSDictionary<NSRegularExpression *, DSJSONSchema *> *patternBasedPropertySchemas;

@end

NS_ASSUME_NONNULL_END
