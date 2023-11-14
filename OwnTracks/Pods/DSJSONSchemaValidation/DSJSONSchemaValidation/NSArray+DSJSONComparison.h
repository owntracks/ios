//
//  NSArray+DSJSONComparison.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 1/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (DSJSONComparison)

NS_ASSUME_NONNULL_BEGIN

/** Returns YES if receiver contains the same items as the other array, with numbers compared in a type-strict manner. */
- (BOOL)vv_isJSONEqualToArray:(NSArray *)otherArray;
/** Returns YES if receiver contains specified object, with numbers compared in a type-strict manner. */
- (BOOL)vv_containsObjectTypeStrict:(id)object;
/** Returns YES if receiver contains duplicate items, with numbers compared in a type-strict manner. */
- (BOOL)vv_containsDuplicateJSONItems;

@end

NS_ASSUME_NONNULL_END
