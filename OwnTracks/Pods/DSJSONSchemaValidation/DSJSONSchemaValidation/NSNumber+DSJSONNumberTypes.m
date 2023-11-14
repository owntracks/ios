//
//  NSNumber+DSNumberTypes.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 30/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "NSNumber+DSJSONNumberTypes.h"

@implementation NSNumber (DSJSONNumberTypes)

- (BOOL)ds_isInteger
{
    if (self.ds_isBoolean == NO) {
        return self.ds_isFloat == NO;
    } else {
        return NO;
    }
}

- (BOOL)ds_isFloat
{
    CFNumberRef underlyingNumberRef = (__bridge CFNumberRef)self;
    return (CFNumberIsFloatType(underlyingNumberRef) == true);
}

- (BOOL)ds_isBoolean
{
    // this is a bit fragile, but works!
    return [self isKindOfClass:[@YES class]];
}

- (BOOL)ds_isStrictEqualToNumber:(NSNumber *)otherNumber
{
    if ([self isEqualToNumber:otherNumber]) {
        // no need to check for "is integer" since it's itself derived from boolean and float checks
        return self.ds_isFloat == otherNumber.ds_isFloat && self.ds_isBoolean == otherNumber.ds_isBoolean;
    } else {
        return NO;
    }
}

@end
