//
//  NSDictionary+DSJSONComparison.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 1/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "NSDictionary+DSJSONComparison.h"
#import "NSObject+DSJSONComparison.h"

@implementation NSDictionary (DSJSONComparison)

- (BOOL)vv_isJSONEqualToDictionary:(NSDictionary *)otherDictionary
{
    if (self.count != otherDictionary.count) {
        return NO;
    }
    
    __block BOOL isEqual = YES;
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        id otherItem = otherDictionary[key];
        if (otherItem == nil || [obj vv_isJSONTypeStrictEqual:otherItem] == NO) {
            isEqual = NO;
            *stop = YES;
        }
    }];
    
    return isEqual;
}

@end
