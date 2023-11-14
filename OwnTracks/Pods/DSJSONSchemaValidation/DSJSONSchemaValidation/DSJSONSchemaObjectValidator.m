//
//  DSJSONSchemaObjectValidator.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 1/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchemaObjectValidator.h"
#import "DSJSONSchemaErrors.h"
#import "DSJSONSchemaFactory.h"
#import "DSJSONSchemaSpecification.h"
#import "NSNumber+DSJSONNumberTypes.h"

@implementation DSJSONSchemaObjectValidator

static NSString * const kSchemaKeywordMaxProperties = @"maxProperties";
static NSString * const kSchemaKeywordMinProperties = @"minProperties";
static NSString * const kSchemaKeywordRequired = @"required";

- (instancetype)initWithMaximumProperties:(NSUInteger)maximumProperties minimumProperties:(NSUInteger)minimumProperties requiredProperties:(NSSet<NSString *> *)requiredProperties
{
    self = [super init];
    if (self) {
        _maximumProperties = maximumProperties;
        _minimumProperties = minimumProperties;
        _requiredProperties = [requiredProperties copy];
    }
    
    return self;
}

- (NSString *)description
{
    NSString *requiredPropertiesDescription = (self.requiredProperties != nil ? [self.requiredProperties.allObjects componentsJoinedByString:@", "] : @"none");
    return [[super description] stringByAppendingFormat:@"{ maximum properties: %@, minimum properties: %lu, required properties: %@ }", (self.maximumProperties != NSUIntegerMax ? @(self.maximumProperties) : @"none"), (unsigned long)self.minimumProperties, requiredPropertiesDescription];
}

+ (NSSet<NSString *> *)assignedKeywords
{
    return [NSSet setWithArray:@[ kSchemaKeywordMaxProperties, kSchemaKeywordMinProperties, kSchemaKeywordRequired ]];
}

+ (instancetype)validatorWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary schemaFactory:(DSJSONSchemaFactory *)schemaFactory error:(NSError * __autoreleasing *)error
{
    if ([self validateSchemaFormat:schemaDictionary specification:schemaFactory.specification] == NO) {
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaDictionary];
        }
        return nil;
    }
    
    NSNumber *maxProperties = schemaDictionary[kSchemaKeywordMaxProperties];
    NSNumber *minProperties = schemaDictionary[kSchemaKeywordMinProperties];
    NSArray<NSString *> *required = schemaDictionary[kSchemaKeywordRequired];
    
    NSUInteger maxPropertiesValue = (maxProperties != nil ? [maxProperties unsignedIntegerValue] : NSUIntegerMax);
    NSUInteger minPropertiesValue = (minProperties != nil ? [minProperties unsignedIntegerValue] : 0);
    NSSet<NSString *> *requiredSet = (required != nil ? [NSSet setWithArray:required] : nil);

    return [[self alloc] initWithMaximumProperties:maxPropertiesValue minimumProperties:minPropertiesValue requiredProperties:requiredSet];
}

+ (BOOL)validateSchemaFormat:(NSDictionary<NSString *, id> *)schemaDictionary specification:(DSJSONSchemaSpecification *)specification
{
    id maxProperties = schemaDictionary[kSchemaKeywordMaxProperties];
    id minProperties = schemaDictionary[kSchemaKeywordMinProperties];
    id required = schemaDictionary[kSchemaKeywordRequired];
    
    // maxProperties must be a number and not a boolean, and must be greater than or equal to zero
    if (maxProperties != nil) {
        if ([maxProperties isKindOfClass:[NSNumber class]] == NO || [maxProperties ds_isBoolean] || [(NSNumber *)maxProperties compare:@0] == NSOrderedAscending) {
            return NO;
        }
    }
    // minProperties must be a number and not a boolean, and must be greater than or equal to zero
    if (minProperties != nil) {
        if ([minProperties isKindOfClass:[NSNumber class]] == NO || [minProperties ds_isBoolean] || [(NSNumber *)minProperties compare:@0] == NSOrderedAscending) {
            return NO;
        }
    }
    // required must be a non-empty array of unique strings
    if (required != nil) {
        if ([required isKindOfClass:[NSArray class]] == NO) {
            return NO;
        }
        
        if (specification.version == DSJSONSchemaSpecificationVersionDraft6 ||
            specification.version == DSJSONSchemaSpecificationVersionDraft7) {
            if ([required count] == 0) {
                return YES;
            }
        }
        
        if ([required count] == 0) {
            return NO;
        }
        
        for (id property in required) {
            if ([property isKindOfClass:[NSString class]] == NO) {
                return NO;
            }
        }
        
        if ([NSSet setWithArray:required].count != [required count]) {
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
    if ([instance isKindOfClass:[NSDictionary class]] == NO) {
        return YES;
    }

    // check maximum and minimum counts
    NSUInteger propertiesCount = [instance count];
    if (propertiesCount > self.maximumProperties || propertiesCount < self.minimumProperties) {
        if (error != NULL) {
            NSString *failureReason = [NSString stringWithFormat:@"Object contains %lu properties.", (unsigned long)propertiesCount];
            *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
        }
        return NO;
    }
    
    // check required properties
    NSSet<NSString *> *requiredProperties = self.requiredProperties;
    if (requiredProperties != nil) {
        NSSet<NSString *> *keyset = [NSSet setWithArray:[instance allKeys]];
        if ([requiredProperties isSubsetOfSet:keyset] == NO) {
            if (error != NULL) {
                NSMutableSet<NSString *> *missingProperties = [requiredProperties mutableCopy];
                [missingProperties minusSet:keyset];
                NSString *missingPropertiesList = [[missingProperties allObjects] componentsJoinedByString:@", "];
                NSString *failureReason = [NSString stringWithFormat:@"Object is missing required properties: '%@'.", missingPropertiesList];
                *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
            }
            return NO;
        }
    }

    return YES;
}

@end
