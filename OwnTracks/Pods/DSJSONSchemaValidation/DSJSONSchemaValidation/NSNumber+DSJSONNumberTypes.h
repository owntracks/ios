//
//  NSNumber+DSJSONNumberTypes.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 30/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSNumber (DSJSONNumberTypes)

/** Returns YES if receiver is an integer number. */
- (BOOL)ds_isInteger;
/** Returns YES if receiver is an floating-point number. */
- (BOOL)ds_isFloat;
/** Returns YES if receiver is a boolean number. */
- (BOOL)ds_isBoolean;

/**
 Returns YES if receiver has the same value AND number type (integer/float/boolean) as the other number.
 @discussion Since `-[NSNumber isEqual:]` checks for mathematical equality, it would also consider "1", "1.0" and "true" instances from JSON same numbers. This behavior is unwanted in a few cases. This method checks that two numbers have the same underlying type before deeming them equal.
 */
- (BOOL)ds_isStrictEqualToNumber:(NSNumber *)otherNumber;

@end

NS_ASSUME_NONNULL_END
