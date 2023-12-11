//
//  DSJSONSchemaNumericValidator.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 30/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchemaNumericValidator.h"
#import "DSJSONSchemaErrors.h"
#import "DSJSONSchemaFactory.h"
#import "DSJSONSchemaSpecification.h"
#import "NSNumber+DSJSONNumberTypes.h"

@implementation DSJSONSchemaNumericValidator

static NSString * const kSchemaKeywordMultipleOf = @"multipleOf";
static NSString * const kSchemaKeywordMaximum = @"maximum";
static NSString * const kSchemaKeywordExclusiveMaximum = @"exclusiveMaximum";
static NSString * const kSchemaKeywordMinimum = @"minimum";
static NSString * const kSchemaKeywordExclusiveMinimum = @"exclusiveMinimum";

- (instancetype)initWithMultipleOf:(NSDecimalNumber *)multipleOf maximum:(NSNumber *)maximum exclusive:(BOOL)exclusiveMaximum minimum:(NSNumber *)minimum exclusive:(BOOL)exclusiveMinimum
{
    self = [super init];
    if (self) {
        _multipleOf = multipleOf;
        _maximum = maximum;
        _exclusiveMaximum = exclusiveMaximum;
        _minimum = minimum;
        _exclusiveMinimum = exclusiveMinimum;
    }
    
    return self;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"{ multiple of %@; maximum %@ exclusive %@; minimum %@ exclusive %@ }", self.multipleOf, self.maximum, (self.exclusiveMaximum ? @"YES" : @"NO"), self.minimum, (self.exclusiveMinimum ? @"YES" : @"NO")];
}

+ (NSSet<NSString *> *)assignedKeywords
{
    return [NSSet setWithArray:@[ kSchemaKeywordMultipleOf, kSchemaKeywordMaximum, kSchemaKeywordExclusiveMaximum, kSchemaKeywordMinimum, kSchemaKeywordExclusiveMinimum ]];
}

+ (instancetype)validatorWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary schemaFactory:(__unused DSJSONSchemaFactory *)schemaFactory error:(NSError * __autoreleasing *)error
{
    if ([self validateSchemaFormat:schemaDictionary specification:schemaFactory.specification] == NO) {
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaDictionary];
        }
        return nil;
    }
    
    NSNumber *multipleOf = schemaDictionary[kSchemaKeywordMultipleOf];
    NSNumber *maximum = schemaDictionary[kSchemaKeywordMaximum];
    NSNumber *minimum = schemaDictionary[kSchemaKeywordMinimum];
    NSNumber *exclusiveMaximum = nil;
    NSNumber *exclusiveMinimum = nil;
    
    if (schemaFactory.specification.version == DSJSONSchemaSpecificationVersionDraft4) {
        exclusiveMaximum = schemaDictionary[kSchemaKeywordExclusiveMaximum] ?: @NO;
        exclusiveMinimum = schemaDictionary[kSchemaKeywordExclusiveMinimum] ?: @NO;
    }
    else {
        if (!maximum) {
            maximum = schemaDictionary[kSchemaKeywordExclusiveMaximum];
            exclusiveMaximum = maximum ? @YES : @NO;
        }
        if (!minimum) {
            minimum = schemaDictionary[kSchemaKeywordExclusiveMinimum];
            exclusiveMinimum = minimum ? @YES : @NO;
        }
    }
    
    // to avoid floating-point precision errors, multiplier is converted to a decimal number
    NSDecimalNumber *multipleOfDecimal = multipleOf != nil ? [NSDecimalNumber decimalNumberWithString:[multipleOf stringValue]] : nil;
    
    DSJSONSchemaNumericValidator *validator = [[self alloc] initWithMultipleOf:multipleOfDecimal maximum:maximum exclusive:[exclusiveMaximum boolValue] minimum:minimum exclusive:[exclusiveMinimum boolValue]];
    
    return validator;
}

+ (BOOL)validateSchemaFormat:(NSDictionary<NSString *, id> *)schemaDictionary specification:(DSJSONSchemaSpecification *)specification
{
    id multipleOf = schemaDictionary[kSchemaKeywordMultipleOf];
    id maximum = schemaDictionary[kSchemaKeywordMaximum];
    id exclusiveMaximum = schemaDictionary[kSchemaKeywordExclusiveMaximum];
    id minimum = schemaDictionary[kSchemaKeywordMinimum];
    id exclusiveMinimum = schemaDictionary[kSchemaKeywordExclusiveMinimum];

    // multipleOf must be a number and not a boolean, and must be greater than zero
    if (multipleOf != nil) {
        if ([multipleOf isKindOfClass:[NSNumber class]] == NO || [multipleOf ds_isBoolean] || [(NSNumber *)multipleOf compare:@0] != NSOrderedDescending) {
            return NO;
        }
    }
    // maximum must be a number and not a boolean
    if (maximum != nil) {
        if ([maximum isKindOfClass:[NSNumber class]] == NO || [maximum ds_isBoolean]) {
            return NO;
        }
    }
    // minimum must be a number and not a boolean
    if (minimum != nil) {
        if ([minimum isKindOfClass:[NSNumber class]] == NO || [minimum ds_isBoolean]) {
            return NO;
        }
    }
    if (exclusiveMaximum != nil) {
        if (specification.version == DSJSONSchemaSpecificationVersionDraft4) {
            // exclusiveMaximum must be a number and not a boolean
            if ([exclusiveMaximum isKindOfClass:[NSNumber class]] == NO || [exclusiveMaximum ds_isBoolean] == NO) {
                return NO;
            }
        }
        else {
            // exclusiveMaximum must be a boolean number
            if ([exclusiveMaximum isKindOfClass:[NSNumber class]] == NO || [exclusiveMaximum ds_isBoolean]) {
                return NO;
            }
        }
    }
    if (exclusiveMinimum != nil) {
        if (specification.version == DSJSONSchemaSpecificationVersionDraft4) {
            // exclusiveMinimum must be a number and not a boolean
            if ([exclusiveMinimum isKindOfClass:[NSNumber class]] == NO || [exclusiveMinimum ds_isBoolean] == NO) {
                return NO;
            }
        }
        else {
            // exclusiveMinimum must be a boolean number
            if ([exclusiveMinimum isKindOfClass:[NSNumber class]] == NO || [exclusiveMinimum ds_isBoolean]) {
                return NO;
            }
        }
    }
    
    if (specification.version == DSJSONSchemaSpecificationVersionDraft4) {
        // if exclusiveMaximum is present, maximum must also be present
        if (exclusiveMaximum != nil && maximum == nil) {
            return NO;
        }
        // if exclusiveMinimum is present, minimum must also be present
        if (exclusiveMinimum != nil && minimum == nil) {
            return NO;
        }
    }
    else {
        // if exclusiveMaximum is present, maximum must not be present
        if (exclusiveMaximum != nil && maximum != nil) {
            return NO;
        }
        // if exclusiveMinimum is present, minimum must not be present
        if (exclusiveMinimum != nil && minimum != nil) {
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
    if ([instance isKindOfClass:[NSNumber class]] == NO || [instance ds_isBoolean] == YES) {
        return YES;
    }
    
    // check multipleOf
    NSDecimalNumber *multipleOf = self.multipleOf;
    if (multipleOf != nil) {
        // to avoid floating-point precision errors, convert instance to a decimal number
        NSDecimalNumber *instanceDecimal = [NSDecimalNumber decimalNumberWithString:[instance stringValue]];
        NSDecimalNumber *divident = [instanceDecimal decimalNumberByDividingBy:multipleOf];
        
        // check that divident is integer by rounding it down and comparing the result with the original divident
        BOOL isDividentInteger = NO;
        NSDecimal dividentDecimal = [divident decimalValue];
        if (NSDecimalIsNotANumber(&dividentDecimal) == NO) {
            NSDecimal roundedDivident;
            NSDecimalRound(&roundedDivident, &dividentDecimal, 0, NSRoundPlain);
            isDividentInteger = (NSDecimalCompare(&dividentDecimal, &roundedDivident) == NSOrderedSame);
        }
        
        if (isDividentInteger == NO) {
            if (error != NULL) {
                NSString *failureReason = [NSString stringWithFormat:@"%@ is not multiple of %@.", instance, multipleOf];
                *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
            }
            return NO;
        }
    }
    
    // check maximum
    NSNumber *maximum = self.maximum;
    if (maximum != nil) {
        NSComparisonResult result = [(NSNumber *)instance compare:maximum];
        if ((self.exclusiveMaximum && result != NSOrderedAscending) ||
            (self.exclusiveMaximum == NO && result == NSOrderedDescending)) {
            if (error != NULL) {
                NSString *failureReason = [NSString stringWithFormat:@"%@ is greater %@ %@.", instance, (self.exclusiveMaximum ? @"or equal to" : @"than"), maximum];
                *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
            }
            return NO;
        }
    }
    
    // check minimum
    NSNumber *minimum = self.minimum;
    if (minimum != nil) {
        NSComparisonResult result = [(NSNumber *)instance compare:minimum];
        if ((self.exclusiveMinimum && result != NSOrderedDescending) ||
            (self.exclusiveMinimum == NO && result == NSOrderedAscending)) {
            if (error != NULL) {
                NSString *failureReason = [NSString stringWithFormat:@"%@ is lower %@ %@.", instance, (self.exclusiveMinimum ? @"or equal to" : @"than"), minimum];
                *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
            }
            return NO;
        }
    }
    
    return YES;
}

@end
