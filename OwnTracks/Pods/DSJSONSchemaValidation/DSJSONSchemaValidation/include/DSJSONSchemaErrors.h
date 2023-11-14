//
//  DSJSONSchemaErrors.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 29/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSJSONSchemaValidator.h"
#import "DSJSONSchemaValidationContext.h"

NS_ASSUME_NONNULL_BEGIN

/** Domain of errors generated during instantiation and validation of JSON schemas. */
extern NSString * const DSJSONSchemaErrorDomain;
/** JSON schema errors user info key for an optional reference to the object that caused the error or its JSON representation. */
extern NSString * const DSJSONSchemaErrorFailingObjectKey;
/** JSON schema errors user info key for an optional reference to the validator that generated the error. */
extern NSString * const DSJSONSchemaErrorFailingValidatorKey;
/** JSON schema errors user info key for an optional path to the object that caused the error in the form of JSON Pointer. */
extern NSString * const DSJSONSchemaErrorFailingObjectPathKey;

/** Defines error codes in `DSJSONSchemaErrorDomain`. */
typedef NS_ENUM(NSUInteger, DSJSONSchemaErrorCode) {
    /** Specified JSON Schema was created using incompatible metaschema, as denoted by its "$schema" keyword. */
    DSJSONSchemaErrorCodeIncompatibleMetaschema = 100,
    /** Specified JSON Schema is invalid. */
    DSJSONSchemaErrorCodeInvalidSchemaFormat = 101,
    /** Specified JSON Schema contains invalid resolution scope URI. */
    DSJSONSchemaErrorCodeInvalidResolutionScope = 102,
    /** Specified JSON Schema or Schema Storage contains duplicate resolution scope URIs. */
    DSJSONSchemaErrorCodeDuplicateResolutionScope = 103,
    /** Specified JSON Schema contains an invalid schema reference. */
    DSJSONSchemaErrorCodeInvalidSchemaReference = 104,
    /** Specified JSON Schema contains an unresolvable schema reference. */
    DSJSONSchemaErrorCodeUnresolvableSchemaReference = 105,
    /** Specified JSON Schema contains a schema reference cycle. */
    DSJSONSchemaErrorCodeReferenceCycle = 106,
    /** Specified JSON Schema contains an invalid regular expression in one of its validators. */
    DSJSONSchemaErrorCodeInvalidRegularExpression = 107,
    
    /** Attempted to register a validator class with no assigned keywords. */
    DSJSONSchemaErrorCodeNoValidatorKeywordsDefined = 200,
    /** Attempted to register a validator class that defines already registered keywords. */
    DSJSONSchemaErrorCodeValidatorKeywordAlreadyDefined = 201,
    /** Attempted to register a format validator with already defined format name. */
    DSJSONSchemaErrorCodeFormatNameAlreadyDefined = 202,
    /** Attempted to register a contentEncoding decoder with already defined encoding name. */
    DSJSONSchemaErrorCodeContentDecoderAlreadyDefined = 203,
    /** Attempted to register a contentMediaType validator with already defined content media type. */
    DSJSONSchemaErrorCodeContentMediaTypeValidatorAlreadyDefined = 204,
    
    /** JSON instance validation against the schema failed. */
    DSJSONSchemaErrorCodeValidationFailed = 300,
    /** JSON instance validation got into an infinite loop. */
    DSJSONSchemaErrorCodeValidationInfiniteLoop = 301
};

@interface NSError (DSJSONSchemaError)

/**
 Calls `+vv_JSONSchemaErrorWithCode:failingObject:underlyingError:` with nil for `underlyingError`.
 */
+ (instancetype)vv_JSONSchemaErrorWithCode:(DSJSONSchemaErrorCode)code failingObject:(nullable id)failingObject;
/**
 Creates and returns an error object with `DSJSONSchemaErrorDomain` domain, specified error code, optional failing object and underlying error.
 @discussion This convenience method is intended to be used with error codes other than `DSJSONSchemaErrorCodeValidationFailed` - if the error is not related to actual JSON failing validation.
 @param code Error code.
 @param failingObject Object that caused the error. Depending on the error code, it might be a failing JSON Schema or invalid JSON instance, or anything else. Returned error will contain this object under `DSJSONSchemaErrorFailingObjectKey` key in `userInfo`, encoded back into a JSON string if possible. Can be nil.
 @param underlyingError Error that was encountered in an underlying implementation and caused the returned error. Returned error will contain this object under `NSUnderlyingErrorKey` key in `userInfo`. Can be nil.
 @return Configured error object.
 */
+ (instancetype)vv_JSONSchemaErrorWithCode:(DSJSONSchemaErrorCode)code failingObject:(nullable id)failingObject underlyingError:(nullable NSError *)underlyingError;
/**
 Creates and returns a validation error object with `DSJSONSchemaErrorDomain` domain, `DSJSONSchemaErrorCodeValidationFailed` error code.
 @discussion This convenience method is intended to be used for creating error objects caused by failing JSON validation. Validation context is used to infer current validated object and validation path stored in the returned error object. Validated object is encoded as a JSON string for human-readability.
 @param failingValidator Validator object that failed JSON validation. Returned error will contain this object under `DSJSONSchemaErrorFailingValidatorKey` key in `userInfo`. Must not be nil.
 @param failureReason Validation reason as defined by the failing validator object. Returned error will contain this string in `localizedFailureReason`. Must not be nil.
 @return Configured error object.
 */
+ (instancetype)vv_JSONSchemaValidationErrorWithFailingValidator:(id<DSJSONSchemaValidator>)failingValidator reason:(NSString *)failureReason context:(DSJSONSchemaValidationContext *)validationContext;

@end

NS_ASSUME_NONNULL_END
