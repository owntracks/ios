//
//  NSObject+DSJSONComparison.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 1/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "NSObject+DSJSONComparison.h"
#import "NSNumber+DSJSONNumberTypes.h"
#import "NSArray+DSJSONComparison.h"
#import "NSDictionary+DSJSONComparison.h"

@implementation NSObject (DSJSONComparison)

- (BOOL)vv_isJSONTypeStrictEqual:(id)object
{
    // use type-strict comparison for numbers, arrays and dictionaries; otherwise, use plain old isEqual:
    if ([self isKindOfClass:[NSNumber class]] && [object isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)self ds_isStrictEqualToNumber:object];
    } else if ([self isKindOfClass:[NSArray class]] && [object isKindOfClass:[NSArray class]]) {
        return [(NSArray *)self vv_isJSONEqualToArray:object];
    } else if ([self isKindOfClass:[NSDictionary class]] && [object isKindOfClass:[NSDictionary class]]) {
        return [(NSDictionary *)self vv_isJSONEqualToDictionary:object];
    } else {
        return [self isEqual:object];
    }
}

@end
