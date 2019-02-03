//
//  NSBundle+privateLocalization.m
//  OwnTracks
//
//  Created by Christoph Krey on 21.04.16.
//  Copyright © 2016 -2019 OwnTracks. All rights reserved.
//
//  The MIT License (MIT)
//
//  Copyright (c) 2015 Corneliu Maftuleac
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//

#import "NSBundle+privateLocalization.h"
#import "Settings.h"
#import <objc/runtime.h>

#import <CocoaLumberjack/CocoaLumberjack.h>
static const DDLogLevel ddLogLevel = DDLogLevelWarning;


@implementation NSBundle (privateLocalization)

+ (void)load {
// based on https://github.com/cmaftuleac/BundleLocalization.git
//
// The MIT License (MIT)
//
//    Copyright (c) 2015 Corneliu Maftuleac
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//        The above copyright notice and this permission notice shall be included in all
//        copies or substantial portions of the Software.

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{

        Class class = [self class];
        SEL originalSelector = @selector(localizedStringForKey:value:table:);
        SEL swizzledSelector = @selector(privateLocalizedStringForKey:value:table:);
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

        BOOL didAddMethod =
        class_addMethod(class,
                        originalSelector,
                        method_getImplementation(swizzledMethod),
                        method_getTypeEncoding(swizzledMethod));

        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

- (NSString *)privateLocalizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)table {
    DDLogVerbose(@"privateLocalizedStringForKey: %@", key);
#ifdef xxx
    if ([Settings boolForKey:@"pl"]) {
        NSString *string = [Settings stringForKey:[NSString stringWithFormat:@"pl_%@", key]];
        if (string) {
            DDLogVerbose(@"privateLocalizedStringForKey: %@ = %@", key, string);
            return string;
        }
    }
#endif
    return [self privateLocalizedStringForKey:key value:value table:table];
}

@end
