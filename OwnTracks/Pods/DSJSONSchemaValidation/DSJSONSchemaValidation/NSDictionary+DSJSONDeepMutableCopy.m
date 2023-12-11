//
//  NSDictionary+DSJSONDeepMutableCopy.m
//  libDSJSONSchemaValidation-iOS
//
//  Created by Andrew Podkovyrin on 07/09/2018.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "NSDictionary+DSJSONDeepMutableCopy.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSArray (DSJSONDeepMutableCopyArray)

- (NSMutableArray *)ds_deepMutableCopy;

@end

@implementation NSArray (DSJSONDeepMutableCopyArray)

- (NSMutableArray *)ds_deepMutableCopy {
    NSMutableArray *mutableSelf = [NSMutableArray arrayWithCapacity:self.count];
    for (id object in self) {
        if ([object isKindOfClass:NSArray.class] || [object isKindOfClass:NSDictionary.class]) {
            [mutableSelf addObject:[(NSArray *)object ds_deepMutableCopy]];
        }
        else {
            [mutableSelf addObject:object];
        }
    }
    return mutableSelf;
}

@end

@implementation NSDictionary (DSJSONDeepMutableCopy)

- (NSMutableDictionary *)ds_deepMutableCopy {
    NSMutableDictionary *mutableSelf = [NSMutableDictionary dictionaryWithCapacity:self.count];
    for (id key in self) {
        id mutableKey = key;
        if ([key isKindOfClass:NSArray.class] || [key isKindOfClass:NSDictionary.class]) {
            mutableKey = [(NSDictionary *)key ds_deepMutableCopy];
        }
        
        id mutableValue = self[key];
        if ([mutableValue isKindOfClass:NSArray.class] || [mutableValue isKindOfClass:NSDictionary.class]) {
            mutableValue = [(NSDictionary *)mutableValue ds_deepMutableCopy];
        }
        
        mutableSelf[mutableKey] = mutableValue;
    }
    return mutableSelf;
}

@end

NS_ASSUME_NONNULL_END
