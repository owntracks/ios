//
//  DSJSONSchemaTypeValidator.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 30/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSJSONSchemaValidator.h"

NS_ASSUME_NONNULL_BEGIN

/** Defines JSON instance types used as bitmask flags. */
typedef NS_OPTIONS(NSUInteger, DSJSONSchemaInstanceTypes) {
    DSJSONSchemaInstanceTypesNone = 0,
    DSJSONSchemaInstanceTypesObject = 1 << 0,
    DSJSONSchemaInstanceTypesArray = 1 << 1,
    DSJSONSchemaInstanceTypesString = 1 << 2,
    DSJSONSchemaInstanceTypesInteger = 1 << 3,
    DSJSONSchemaInstanceTypesNumber = 1 << 4,
    DSJSONSchemaInstanceTypesBoolean = 1 << 5,
    DSJSONSchemaInstanceTypesNull = 1 << 6
};

/**
 Implements "type" keyword. Applicable to all instance types.
 */
@interface DSJSONSchemaTypeValidator : NSObject <DSJSONSchemaValidator>

/** Bitmask of valid JSON instance types for the receiver. */
@property (nonatomic, readonly, assign) DSJSONSchemaInstanceTypes types;

@end

NS_ASSUME_NONNULL_END
