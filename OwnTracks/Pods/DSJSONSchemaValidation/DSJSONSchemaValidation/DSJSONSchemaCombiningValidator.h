//
//  DSJSONSchemaCombiningValidator.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 2/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSJSONSchemaValidator.h"

NS_ASSUME_NONNULL_BEGIN

@class DSJSONSchema;

/**
 Implements "allOf", "anyOf", "oneOf" and "not" keywords. Applicable to all instance types.
 */
@interface DSJSONSchemaCombiningValidator : NSObject <DSJSONSchemaValidator>

/** A valid instance must be valid against all schemas in this property, unless it is nil. */
@property (nonatomic, nullable, readonly, copy) NSArray<DSJSONSchema *> *allOfSchemas;
/** A valid instance must be valid against at least one schema in this property, unless it is nil. */
@property (nonatomic, nullable, readonly, copy) NSArray<DSJSONSchema *> *anyOfSchemas;
/** A valid instance must be valid against exactly one schema in this property, unless it is nil. */
@property (nonatomic, nullable, readonly, copy) NSArray<DSJSONSchema *> *oneOfSchemas;
/** A valid instance must *not* be valid against this schema, unless it is nil. */
@property (nonatomic, nullable, readonly, copy) DSJSONSchema *notSchema;

@end

NS_ASSUME_NONNULL_END
