//
//  NSURL+DSJSONReferencing.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 29/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "NSURL+DSJSONReferencing.h"

@implementation NSURL (DSJSONReferencing)

- (BOOL)vv_isNormalized
{
    return self.host != nil && self.fragment != nil;
}

- (instancetype)vv_normalizedURI
{
    if (self.vv_isNormalized) {
        return [self absoluteURL];
    }
    
    NSURLComponents *components = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:YES];
    if (components.host == nil) {
        components.host = @"";
    }
    if (components.fragment == nil) {
        components.fragment = @"";
    }
    
    return [components URL] ?: self;
}

- (instancetype)vv_URIByAppendingFragmentComponent:(NSString *)fragmentComponent
{
    if (fragmentComponent.length == 0) {
        return self;
    }
    
    NSURLComponents *components = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:YES];
    if (components.fragment.length == 0) {
        components.fragment = @"/";
    }
    components.fragment = [components.fragment stringByAppendingPathComponent:fragmentComponent];
    
    return [components URL] ?: self;
}

@end
