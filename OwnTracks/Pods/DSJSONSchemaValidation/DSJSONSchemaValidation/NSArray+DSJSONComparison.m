//
//  NSArray+DSJSONComparison.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 1/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "NSArray+DSJSONComparison.h"
#import "NSObject+DSJSONComparison.h"

@implementation NSArray (DSJSONComparison)

- (BOOL)vv_isJSONEqualToArray:(NSArray *)otherArray
{
    NSUInteger count = self.count;
    if (count != otherArray.count) {
        return NO;
    }
    
    for (NSUInteger i = 0; i < count; i++) {
        if ([self[i] vv_isJSONTypeStrictEqual:otherArray[i]] == NO) {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)vv_containsObjectTypeStrict:(id)object
{
    for (id item in self) {
        if ([item vv_isJSONTypeStrictEqual:object]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)vv_containsDuplicateJSONItems
{
    BOOL containsDuplicates = NO;
    NSUInteger count = self.count;
    for (NSUInteger i = 0; i < count; i++) {
        for (NSUInteger j = i + 1; j < count; j++) {
            if ([self[i] vv_isJSONTypeStrictEqual:self[j]]) {
                containsDuplicates = YES;
                break;
            }
        }
        
        if (containsDuplicates) {
            break;
        }
    }
    
    return containsDuplicates;
}

@end
