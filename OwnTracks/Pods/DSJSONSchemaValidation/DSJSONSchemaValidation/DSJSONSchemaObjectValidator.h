//
//  DSJSONSchemaObjectValidator.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 1/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSJSONSchemaValidator.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Implements "maxProperties", "minProperties" and "required" keywords. Applicable to object instances.
 */
@interface DSJSONSchemaObjectValidator : NSObject <DSJSONSchemaValidator>

/** Maximum number of properties a valid object instance must have. Unapplicable value is NSUIntegerMax. */
@property (nonatomic, readonly, assign) NSUInteger maximumProperties;
/** Minimum number of properties a valid object instance must have. Unapplicable value is 0. */
@property (nonatomic, readonly, assign) NSUInteger minimumProperties;
/** A set of keys a valid object instance must contain. If nil, no keys are required. */
@property (nonatomic, nullable, readonly, copy) NSSet<NSString *> *requiredProperties;

@end

NS_ASSUME_NONNULL_END
