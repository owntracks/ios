//
//  DSJSONBooleanSchema.m
//  DSJSONSchemaValidation
//
//  Created by Andrew Podkovyrin on 11/08/2018.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSJSONBooleanSchema.h"
#import "NSURL+DSJSONReferencing.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Boolean Validator

@interface DSJSONSchemaBooleanSchemaValidator : NSObject <DSJSONSchemaValidator>

@property (nonatomic, readonly, assign) BOOL schemaValue;

@end

@implementation DSJSONSchemaBooleanSchemaValidator

- (instancetype)initWithSchemaValue:(BOOL)schemaValue
{
    self = [super init];
    if (self) {
        _schemaValue = schemaValue;
    }
    return self;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"{ boolean value %@ }", self.schemaValue ? @"YES" : @"NO"];
}

+ (NSSet<NSString *> *)assignedKeywords
{
    NSAssert(NO, @"Assigned keywords are not available for boolean schema validator");
    return [NSSet setWithObject:@""];
}

+ (nullable instancetype)validatorWithDictionary:(__unused NSDictionary<NSString *, id> *)schemaDictionary schemaFactory:(__unused DSJSONSchemaFactory *)schemaFactory error:(__unused  NSError * __autoreleasing *)error
{
    NSAssert(NO, @"`validatorWithDictionary:schemaFactory:error` is not available for boolean schema validator");
    return nil;
}

- (nullable NSArray<DSJSONSchema *> *)subschemas
{
    return nil;
}

- (BOOL)validateInstance:(__unused id)instance inContext:(DSJSONSchemaValidationContext *)context error:(__unused NSError *__autoreleasing *)error
{
    if (self.schemaValue == NO) {
        if (error != NULL) {
            NSString *failureReason = [NSString stringWithFormat:@"Object does not satisfy '%@' schema.", self.schemaValue ? @"YES" : @"NO"];
            *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
        }
        return NO;
    }
    else {
        return YES;
    }
}

@end

#pragma mark - Boolean Schema

@implementation DSJSONBooleanSchema

#pragma mark - Schema parsing

+ (nullable instancetype)schemaWithNumber:(NSNumber *)schemaNumber baseURI:(nullable NSURL *)baseURI specification:(DSJSONSchemaSpecification *)specification options:(DSJSONSchemaValidationOptions *)options error:(NSError * __autoreleasing *)error
{
    if ([schemaNumber isKindOfClass:NSNumber.class] == NO) {
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaNumber];
        }
        return nil;
    }

    // if base URI is not present, replace it with an empty one
    NSURL *scopeURI = baseURI ?: [NSURL URLWithString:@""];
    scopeURI = scopeURI.vv_normalizedURI;
    
    DSJSONBooleanSchema *schema = [[self alloc] initWithScopeURI:scopeURI schemaValue:schemaNumber.boolValue specification:specification options:options];
    
    return schema;
}

- (instancetype)initWithScopeURI:(NSURL *)uri schemaValue:(BOOL)schemaValue specification:(DSJSONSchemaSpecification *)specification options:(DSJSONSchemaValidationOptions *)options
{
    DSJSONSchemaBooleanSchemaValidator *validator = [[DSJSONSchemaBooleanSchemaValidator alloc] initWithSchemaValue:schemaValue];
    self = [super initWithScopeURI:uri title:nil description:nil validators:@[ validator ] subschemas:nil specification:specification options:options];
    if (self) {
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
