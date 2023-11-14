//
//  DSJSONSchemaEnumValidator.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 31/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchemaEnumValidator.h"
#import "DSJSONSchemaErrors.h"
#import "NSArray+DSJSONComparison.h"

@implementation DSJSONSchemaEnumValidator

static NSString * const kSchemaKeywordEnum = @"enum";

- (instancetype)initWithValueOptions:(NSArray<id> *)valueOptions
{
    self = [super init];
    if (self) {
        _valueOptions = [valueOptions copy];
    }
    
    return self;
}

- (NSString *)description
{
    NSString *optionsList = [[self.valueOptions valueForKey:@"description"] componentsJoinedByString:@", "];
    return [[super description] stringByAppendingFormat:@"{ allowed values: %@ }", optionsList];
}

+ (NSSet<NSString *> *)assignedKeywords
{
    return [NSSet setWithObject:kSchemaKeywordEnum];
}

+ (instancetype)validatorWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary schemaFactory:(__unused DSJSONSchemaFactory *)schemaFactory error:(NSError * __autoreleasing *)error
{
    id enumObject = schemaDictionary[kSchemaKeywordEnum];
    
    // enum must be an array
    if ([enumObject isKindOfClass:[NSArray class]]) {
        // enum array must not contain zero elements or have duplicate elements
        if ([enumObject count] != 0 && [enumObject vv_containsDuplicateJSONItems] == NO) {
            return [[self alloc] initWithValueOptions:enumObject];
        }
    }
    
    if (error != NULL) {
        *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaDictionary];
    }
    return nil;
}

- (NSArray<DSJSONSchema *> *)subschemas
{
    return nil;
}

- (BOOL)validateInstance:(id)instance inContext:(DSJSONSchemaValidationContext *)context error:(NSError *__autoreleasing *)error
{
    if ([self.valueOptions vv_containsObjectTypeStrict:instance]) {
        return YES;
    } else {
        if (error != NULL) {
            NSString *failureReason = @"Object is not one of the allowed options.";
            *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
        }
        return NO;
    }
}

@end
