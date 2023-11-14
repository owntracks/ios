//
//  DSJSONSchemaStringValidator.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 31/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchemaStringValidator.h"
#import "DSJSONSchemaErrors.h"
#import "NSNumber+DSJSONNumberTypes.h"

@implementation DSJSONSchemaStringValidator

static NSString * const kSchemaKeywordMaxLength = @"maxLength";
static NSString * const kSchemaKeywordMinLength = @"minLength";
static NSString * const kSchemaKeywordPattern = @"pattern";

- (instancetype)initWithMaximumLength:(NSUInteger)maximumLength minimumLength:(NSUInteger)minimumLength regularExpression:(NSRegularExpression *)regularExpression
{
    self = [super init];
    if (self) {
        _maximumLength = maximumLength;
        _minimumLength = minimumLength;
        _regularExpression = regularExpression;
    }
    
    return self;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"{ maximum length: %@, minimum length: %lu, pattern: %@ }", (self.maximumLength != NSUIntegerMax ? @(self.maximumLength) : @"none"), (unsigned long)self.minimumLength, self.regularExpression.pattern];
}

+ (NSSet<NSString *> *)assignedKeywords
{
    return [NSSet setWithArray:@[ kSchemaKeywordMaxLength, kSchemaKeywordMinLength, kSchemaKeywordPattern ]];
}

+ (instancetype)validatorWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary schemaFactory:(__unused DSJSONSchemaFactory *)schemaFactory error:(NSError * __autoreleasing *)error
{
    if ([self validateSchemaFormat:schemaDictionary] == NO) {
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaDictionary];
        }
        return nil;
    }
    
    NSNumber *maxLength = schemaDictionary[kSchemaKeywordMaxLength];
    NSNumber *minLength = schemaDictionary[kSchemaKeywordMinLength];
    NSString *pattern = schemaDictionary[kSchemaKeywordPattern];
    
    NSUInteger maxLengthValue = (maxLength != nil ? [maxLength unsignedIntegerValue] : NSUIntegerMax);
    NSUInteger minLengthValue = (minLength != nil ? [minLength unsignedIntegerValue] : 0);
    
    NSRegularExpression *regexp = nil;
    if (pattern.length > 0) {
        NSError *underlyingError;
        regexp = [NSRegularExpression regularExpressionWithPattern:pattern options:(NSRegularExpressionOptions)0 error:&underlyingError];
        if (regexp == nil) {
            if (error != NULL) {
                *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidRegularExpression failingObject:pattern underlyingError:underlyingError];
            }
            return nil;
        }
    }
    
    return [[self alloc] initWithMaximumLength:maxLengthValue minimumLength:minLengthValue regularExpression:regexp];
}

+ (BOOL)validateSchemaFormat:(NSDictionary<NSString *, id> *)schemaDictionary
{
    id maxLength = schemaDictionary[kSchemaKeywordMaxLength];
    id minLength = schemaDictionary[kSchemaKeywordMinLength];
    id pattern = schemaDictionary[kSchemaKeywordPattern];
    
    // maxLength must be a number and not a boolean, and must be greater than or equal to zero
    if (maxLength != nil) {
        if ([maxLength isKindOfClass:[NSNumber class]] == NO || [maxLength ds_isBoolean] || [(NSNumber *)maxLength compare:@0] == NSOrderedAscending) {
            return NO;
        }
    }
    // minLength must be a number and not a boolean, and must be greater than or equal to zero
    if (minLength != nil) {
        if ([minLength isKindOfClass:[NSNumber class]] == NO || [minLength ds_isBoolean] || [(NSNumber *)minLength compare:@0] == NSOrderedAscending) {
            return NO;
        }
    }
    // pattern must be a string
    if (pattern != nil) {
        if ([pattern isKindOfClass:[NSString class]] == NO) {
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
    if ([instance isKindOfClass:[NSString class]] == NO) {
        return YES;
    }
    
    // retrieve actual string length by converting it to UTF32 representation and calculating number of 4-byte charaters
    // (see http://www.objc.io/issue-9/unicode.html for details)
    NSUInteger realLength = [instance lengthOfBytesUsingEncoding:NSUTF32StringEncoding] / 4;
    // check maximum and minimum length
    if (realLength > self.maximumLength || realLength < self.minimumLength) {
        if (error != NULL) {
            NSString *failureReason = [NSString stringWithFormat:@"String is %lu characters long.", (unsigned long)realLength];
            *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
        }
        return NO;
    }
    
    // check regexp pattern
    NSRegularExpression *regularExpression = self.regularExpression;
    if (regularExpression != nil) {
        NSRange fullRange = NSMakeRange(0, [(NSString *)instance length]);
        if ([regularExpression numberOfMatchesInString:instance options:(NSMatchingOptions)0 range:fullRange] == 0) {
            if (error != NULL) {
                NSString *failureReason = @"String does not satisfy the pattern.";
                *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
            }
            return NO;
        }
    }
    
    return YES;
}

@end
