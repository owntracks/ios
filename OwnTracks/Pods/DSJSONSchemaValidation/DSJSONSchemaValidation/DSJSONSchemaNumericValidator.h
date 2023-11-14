//
//  DSJSONSchemaNumericValidator.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 30/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSJSONSchemaValidator.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Implements "multipleOf", "maximum", "exclusiveMaximum", "minimum" and "exclusiveMinimum" keywords. Applicable to integer and number instances.
 */
@interface DSJSONSchemaNumericValidator : NSObject <DSJSONSchemaValidator>

/** A number that validated number must be a multiple of. If nil, multiplier is not validated. */
@property (nonatomic, nullable, readonly, strong) NSDecimalNumber *multipleOf;

/** Maximum value of the validated number. If nil, maximum is not validated. */
@property (nonatomic, nullable, readonly, strong) NSNumber *maximum;
/** If YES, validated number must be strictly less than `maximum`, otherwise - less than or equal. */
@property (nonatomic, readonly, assign) BOOL exclusiveMaximum;

/** Minimum value of the validated number. If nil, minimum is not validated. */
@property (nonatomic, nullable, readonly, strong) NSNumber *minimum;
/** If YES, validated number must be strictly greater than `minimum`, otherwise - greater than or equal. */
@property (nonatomic, readonly, assign) BOOL exclusiveMinimum;

@end

NS_ASSUME_NONNULL_END
