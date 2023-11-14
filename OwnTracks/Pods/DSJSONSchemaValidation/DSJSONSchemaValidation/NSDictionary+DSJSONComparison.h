//
//  NSDictionary+DSJSONComparison.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 1/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary (DSJSONComparison)

/** Returns YES if receiver contains the same items as the other dictionary, with numbers compared in a type-strict manner. */
- (BOOL)vv_isJSONEqualToDictionary:(NSDictionary *)otherDictionary;

@end

NS_ASSUME_NONNULL_END
