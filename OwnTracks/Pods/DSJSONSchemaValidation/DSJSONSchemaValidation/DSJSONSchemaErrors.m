//
//  DSJSONSchemaErrors.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 29/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchemaErrors.h"

NSString * const DSJSONSchemaErrorDomain = @"com.argentumko.JSONSchemaValidationError";
NSString * const DSJSONSchemaErrorFailingObjectKey = @"object";
NSString * const DSJSONSchemaErrorFailingValidatorKey = @"validator";
NSString * const DSJSONSchemaErrorFailingObjectPathKey = @"path";

@implementation NSError (DSJSONSchemaError)

+ (instancetype)vv_JSONSchemaErrorWithCode:(DSJSONSchemaErrorCode)code failingObject:(id)failingObject
{
    return [self vv_JSONSchemaErrorWithCode:code failingObject:failingObject underlyingError:nil];
}

+ (instancetype)vv_JSONSchemaErrorWithCode:(DSJSONSchemaErrorCode)code failingObject:(id)failingObject underlyingError:(NSError *)underlyingError
{
    NSMutableDictionary<NSString *, id> *userInfo = [NSMutableDictionary dictionary];
    if (failingObject != nil) {
        userInfo[DSJSONSchemaErrorFailingObjectKey] = [self vv_jsonDescriptionForObject:failingObject];
    }
    if (underlyingError != nil) {
        userInfo[NSUnderlyingErrorKey] = underlyingError;
    }
    
    NSString *localizedDescription = [self vv_localizedDescriptionForErrorCode:code];
    if (localizedDescription != nil) {
        userInfo[NSLocalizedDescriptionKey] = localizedDescription;
    }
    
    return [NSError errorWithDomain:DSJSONSchemaErrorDomain code:(NSInteger)code userInfo:[userInfo copy]];
}

+ (instancetype)vv_JSONSchemaValidationErrorWithFailingValidator:(id<DSJSONSchemaValidator>)failingValidator reason:(NSString *)failureReason context:(DSJSONSchemaValidationContext *)validationContext
{
    NSParameterAssert(failingValidator);
    NSParameterAssert(failureReason);
    NSParameterAssert(validationContext);
    
    NSMutableDictionary<NSString *, id> *userInfo = [NSMutableDictionary dictionary];
    userInfo[DSJSONSchemaErrorFailingObjectKey] = [self vv_jsonDescriptionForObject:validationContext.validatedObject];
    userInfo[DSJSONSchemaErrorFailingValidatorKey] = failingValidator;
    userInfo[DSJSONSchemaErrorFailingObjectPathKey] = validationContext.validationPath;
    userInfo[NSLocalizedFailureReasonErrorKey] = failureReason;
    
    NSString *localizedDescription = [self vv_localizedDescriptionForErrorCode:DSJSONSchemaErrorCodeValidationFailed];
    if (localizedDescription != nil) {
        userInfo[NSLocalizedDescriptionKey] = localizedDescription;
    }
    
    return [NSError errorWithDomain:DSJSONSchemaErrorDomain code:DSJSONSchemaErrorCodeValidationFailed userInfo:[userInfo copy]];
}

+ (NSString *)vv_localizedDescriptionForErrorCode:(DSJSONSchemaErrorCode)errorCode
{
    switch (errorCode) {
        case DSJSONSchemaErrorCodeIncompatibleMetaschema:
            return NSLocalizedString(@"Specified JSON Schema was created using incompatible metaschema, as denoted by its '$schema' keyword.", nil);

        case DSJSONSchemaErrorCodeInvalidSchemaFormat:
            return NSLocalizedString(@"Specified JSON Schema is not a valid schema.", nil);
            
        case DSJSONSchemaErrorCodeInvalidResolutionScope:
            return NSLocalizedString(@"Specified JSON Schema contains invalid resolution scope URI.", nil);
            
        case DSJSONSchemaErrorCodeDuplicateResolutionScope:
            return NSLocalizedString(@"Specified JSON Schema or Schema Storage contains duplicate resolution scope URIs.", nil);
            
        case DSJSONSchemaErrorCodeInvalidSchemaReference:
            return NSLocalizedString(@"Specified JSON Schema contains an invalid schema reference.", nil);
            
        case DSJSONSchemaErrorCodeUnresolvableSchemaReference:
            return NSLocalizedString(@"Failed to resolve a schema reference in the specified JSON Schema.", nil);
            
        case DSJSONSchemaErrorCodeReferenceCycle:
            return NSLocalizedString(@"Specified JSON Schema contains a schema reference cycle.", nil);
            
        case DSJSONSchemaErrorCodeInvalidRegularExpression:
            return NSLocalizedString(@"Specified JSON Schema contains an invalid regular expression in one of its validators.", nil);
            
        case DSJSONSchemaErrorCodeNoValidatorKeywordsDefined:
            return NSLocalizedString(@"Attempted to register a validator class with no assigned keywords.", nil);
            
        case DSJSONSchemaErrorCodeValidatorKeywordAlreadyDefined:
            return NSLocalizedString(@"Attempted to register a validator class that defines already registered keywords.", nil);
            
        case DSJSONSchemaErrorCodeFormatNameAlreadyDefined:
            return NSLocalizedString(@"Attempted to register a format validator with already defined format name.", nil);
        
        case DSJSONSchemaErrorCodeContentDecoderAlreadyDefined:
            return NSLocalizedString(@"Attempted to register a 'contentEncoding' decoder with already defined encoding name.", nil);
        
        case DSJSONSchemaErrorCodeContentMediaTypeValidatorAlreadyDefined:
            return NSLocalizedString(@"Attempted to register a 'contentMediaType' validator with already defined content media type.", nil);
            
        case DSJSONSchemaErrorCodeValidationFailed:
            return NSLocalizedString(@"JSON instance validation against the schema failed.", nil);
            
        case DSJSONSchemaErrorCodeValidationInfiniteLoop:
            return NSLocalizedString(@"JSON instance validation got into an infinite loop.", nil);
            
        default:
            return nil;
    }
}

+ (id)vv_jsonDescriptionForObject:(id)object
{
    if ([NSJSONSerialization isValidJSONObject:object]) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingPrettyPrinted error:NULL];
        if (data != nil) {
            return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
    }
    
    // If object cannot be serialized back into JSON or an error occurred, just return it as-is
    return object;
}

@end
