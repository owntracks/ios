//
//  DSJSONSchemaValidationOptions.m
//  DSJSONSchemaValidationTests
//
//  Created by Andrew Podkovyrin on 22/08/2018.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSJSONSchemaValidationOptions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DSJSONSchemaValidationOptions

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"{ removeAdditional: %@ }", @(self.removeAdditional)];
}

@end

NS_ASSUME_NONNULL_END
