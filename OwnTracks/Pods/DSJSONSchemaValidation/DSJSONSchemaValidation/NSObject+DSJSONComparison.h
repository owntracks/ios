//
//  NSObject+DSJSONComparison.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 1/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (DSJSONComparison)

/**
 Returns YES if receiver is equal to the other object, with numbers compared in a type-strict manner.
 @discussion This method delegates actual comparison to class-specific methods defined in separate categories for classes `NSNumber`, `NSArray` and `NSDictionary`. In other cases it just calls `-isEqual:`. Note that for this reason its performance could be lower than of `-isEqual:`, so its usage should be limited.
 */
- (BOOL)vv_isJSONTypeStrictEqual:(id)object;

@end

NS_ASSUME_NONNULL_END
