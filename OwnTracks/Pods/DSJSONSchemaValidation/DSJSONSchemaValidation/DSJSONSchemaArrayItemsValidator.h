//
//  DSJSONSchemaArrayItemsValidator.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 1/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSJSONSchemaValidator.h"

@class DSJSONSchema;

NS_ASSUME_NONNULL_BEGIN

/**
 Implements "items" and "additionalItems" keywords. Applicable to array instances.
 */
@interface DSJSONSchemaArrayItemsValidator : NSObject <DSJSONSchemaValidator>

/** Schema all items in a valid array instance must validate against. */
@property (nonatomic, nullable, readonly, strong) DSJSONSchema *itemsSchema;
/** Array of schemas to validate each corresponding item of a valid array against. */
@property (nonatomic, nullable, readonly, copy) NSArray<DSJSONSchema *> *itemSchemas;

/** Schema to validate any array items beyond the number of schemas in `itemSchemas` against, if it is not nil. */
@property (nonatomic, nullable, readonly, strong) DSJSONSchema *additionalItemsSchema;
/**
 If NO, a valid array instance must contain no more items than schemas in `itemSchemas`. If the latter is nil, this property is not applicable.
 If YES, all items in a valid array instance beyond the number of schemas in `itemSchemas` must validate against `additionalItemsSchema`. If the latter is nil, those items are assumed valid.
 */
@property (nonatomic, readonly, assign) BOOL additionalItemsAllowed;

@end

NS_ASSUME_NONNULL_END
