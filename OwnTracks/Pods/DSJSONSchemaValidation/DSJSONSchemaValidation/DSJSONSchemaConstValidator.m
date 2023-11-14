//
//  DSJSONSchemaConstValidator.m
//  DSJSONSchemaValidation
//
//  Created by Andrew Podkovyrin on 13/08/2018.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSJSONSchemaConstValidator.h"
#import "DSJSONSchemaErrors.h"
#import "NSObject+DSJSONComparison.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DSJSONSchemaConstValidator

static NSString * const kSchemaKeywordConst = @"const";

- (instancetype)initWithValue:(id)value
{
    self = [super init];
    if (self) {
        _value = value;
    }
    return self;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"{ allowed value: %@ }", self.value];
}

+ (NSSet<NSString *> *)assignedKeywords
{
    return [NSSet setWithObject:kSchemaKeywordConst];
}

+ (nullable instancetype)validatorWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary schemaFactory:(__unused DSJSONSchemaFactory *)schemaFactory error:(NSError * __autoreleasing *)error
{
    id constObject = schemaDictionary[kSchemaKeywordConst];
    if (constObject) {
        return [[self alloc] initWithValue:constObject];
    }
    
    if (error != NULL) {
        *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaDictionary];
    }
    return nil;
}

- (nullable NSArray<DSJSONSchema *> *)subschemas
{
    return nil;
}

- (BOOL)validateInstance:(id)instance inContext:(DSJSONSchemaValidationContext *)context error:(NSError *__autoreleasing *)error
{
    if ([self.value vv_isJSONTypeStrictEqual:instance]) {
        return YES;
    } else {
        if (error != NULL) {
            NSString *failureReason = @"Object is not equals to the allowed value.";
            *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
        }
        return NO;
    }
}

@end

NS_ASSUME_NONNULL_END
