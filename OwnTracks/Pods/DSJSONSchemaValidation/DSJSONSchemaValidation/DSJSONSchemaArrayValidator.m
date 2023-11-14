//
//  DSJSONSchemaArrayValidator.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 1/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchemaArrayValidator.h"
#import "DSJSONSchemaErrors.h"
#import "NSNumber+DSJSONNumberTypes.h"
#import "NSArray+DSJSONComparison.h"

@implementation DSJSONSchemaArrayValidator

static NSString * const kSchemaKeywordMaxItems = @"maxItems";
static NSString * const kSchemaKeywordMinItems = @"minItems";
static NSString * const kSchemaKeywordUniqueItems = @"uniqueItems";

- (instancetype)initWithMaximumItems:(NSUInteger)maximumItems minimumItems:(NSUInteger)minimumItems uniqueItems:(BOOL)uniqueItems
{
    self = [super init];
    if (self) {
        _maximumItems = maximumItems;
        _minimumItems = minimumItems;
        _uniqueItems = uniqueItems;
    }
    
    return self;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"{ maximum items: %@, minimum items: %lu, unique: %@ }", (self.maximumItems != NSUIntegerMax ? @(self.maximumItems) : @"none"), (unsigned long)self.minimumItems, (self.uniqueItems ? @"YES" : @"NO")];
}

+ (NSSet<NSString *> *)assignedKeywords
{
    return [NSSet setWithArray:@[ kSchemaKeywordMaxItems, kSchemaKeywordMinItems, kSchemaKeywordUniqueItems ]];
}

+ (instancetype)validatorWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary schemaFactory:(__unused DSJSONSchemaFactory *)schemaFactory error:(NSError * __autoreleasing *)error
{
    if ([self validateSchemaFormat:schemaDictionary] == NO) {
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaDictionary];
        }
        return nil;
    }
    
    NSNumber *maxItems = schemaDictionary[kSchemaKeywordMaxItems];
    NSNumber *minItems = schemaDictionary[kSchemaKeywordMinItems];
    NSNumber *uniqueItems = schemaDictionary[kSchemaKeywordUniqueItems];
    
    NSUInteger maxItemsValue = (maxItems != nil ? [maxItems unsignedIntegerValue] : NSUIntegerMax);
    NSUInteger minItemsValue = (minItems != nil ? [minItems unsignedIntegerValue] : 0);
    BOOL uniqueItemsValue = (uniqueItems != nil ? [uniqueItems boolValue] : NO);
    
    return [[self alloc] initWithMaximumItems:maxItemsValue minimumItems:minItemsValue uniqueItems:uniqueItemsValue];
}

+ (BOOL)validateSchemaFormat:(NSDictionary<NSString *, id> *)schemaDictionary
{
    id maxItems = schemaDictionary[kSchemaKeywordMaxItems];
    id minItems = schemaDictionary[kSchemaKeywordMinItems];
    id uniqueItems = schemaDictionary[kSchemaKeywordUniqueItems];
    
    // maxItems must be a number and not a boolean, and must be greater than or equal to zero
    if (maxItems != nil) {
        if ([maxItems isKindOfClass:[NSNumber class]] == NO || [maxItems ds_isBoolean] || [(NSNumber *)maxItems compare:@0] == NSOrderedAscending) {
            return NO;
        }
    }
    // minItems must be a number and not a boolean, and must be greater than or equal to zero
    if (minItems != nil) {
        if ([minItems isKindOfClass:[NSNumber class]] == NO || [minItems ds_isBoolean] || [(NSNumber *)minItems compare:@0] == NSOrderedAscending) {
            return NO;
        }
    }
    // uniqueItems must be a boolean number
    if (uniqueItems != nil) {
        if ([uniqueItems isKindOfClass:[NSNumber class]] == NO || [uniqueItems ds_isBoolean] == NO) {
            return NO;
        }
    }
    
    return YES;
}

- (NSArray<DSJSONSchema *> *)subschemas
{
    return nil;
}

- (BOOL)validateInstance:(id)instance inContext:(DSJSONSchemaValidationContext *)context error:(NSError *__autoreleasing *)error
{
    // silently succeed if value of the instance is inapplicable
    if ([instance isKindOfClass:[NSArray class]] == NO) {
        return YES;
    }
    
    // check maximum and minimum counts
    NSUInteger itemsCount = [instance count];
    if (itemsCount > self.maximumItems || itemsCount < self.minimumItems) {
        if (error != NULL) {
            NSString *failureReason = [NSString stringWithFormat:@"Array contains %lu objects.", (unsigned long)itemsCount];
            *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
        }
        return NO;
    }
    
    // check items uniqueness if necessary
    if (self.uniqueItems) {
        if ([instance vv_containsDuplicateJSONItems]) {
            if (error != NULL) {
                NSString *failureReason = @"Array objects are not unique.";
                *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
            }
            return NO;
        }
    }
    
    return YES;
}

@end
