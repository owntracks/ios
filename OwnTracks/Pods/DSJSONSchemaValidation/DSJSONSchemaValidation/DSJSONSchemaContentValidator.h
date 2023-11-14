//
//  DSJSONSchemaContentValidator.h
//  DSJSONSchemaValidation
//
//  Created by Andrew Podkovyrin on 21/08/2018.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSJSONSchemaValidator.h"

NS_ASSUME_NONNULL_BEGIN

@class DSJSONSchemaContentValidator;

typedef _Nullable id (^DSJSONContentDecoderBlock)(_Nullable id value, DSJSONSchemaContentValidator *validator, DSJSONSchemaValidationContext *context, NSError * _Nullable __autoreleasing *error);

typedef BOOL (^DSJSONContentTypeValidatorBlock)(id value, DSJSONSchemaContentValidator *validator, DSJSONSchemaValidationContext *context, NSError * _Nullable __autoreleasing *error);

/**
 Implements "contentMediaType" and "contentEncoding" keywords. Validation of string-encoded content based on media type. Applicable to string instances.
  @discussion Clients can register custom content decoders and media type validators to validate them without modifying this validator class. Refer to methods `+registerEncoding:withBlock:error:` and `+registerMediaType:withBlock:error:` for details.
 */
@interface DSJSONSchemaContentValidator : NSObject <DSJSONSchemaValidator>

/** Content media type. */
@property (nullable, readonly, copy, nonatomic) NSString *mediaType;
/** Content encoding. */
@property (nullable, readonly, copy, nonatomic) NSString *encoding;

/**
 Registers the specified block to be used to decode content with the specified encoding.
 @discussion This method allows extending basic functionality of the content validator by registering custom encodings to be decoded by a block. Registering a custom encoding will fail if a decoder with the specified name is already registered.
 @warning Avoid calling this method while a schema is already being validated to avoid undefined behavior. To ensure thread-safety, the decoder block must be reentrant, independent of external state (like captured mutable objects or block variables) and independent of calling thread.
 @param encoding Custom encoding name. Must not be nil.
 @param block Block used to decode the instance. The block takes decoding instance as a parameter and returns decoded value if the instance is decoded without errors, or `nil` otherwise. Must not be nil.
 @param error Error object to contain any error encountered during registration of the decoder.
 @return YES, if the decoder has been registered successfully, otherwise NO.
 */
+ (BOOL)registerEncoding:(NSString *)encoding withBlock:(DSJSONContentDecoderBlock)block error:(NSError * __autoreleasing *)error;
/**
 Registers the specified block to be used to validate the specified media type.
 @discussion This method allows extending basic functionality of the media type validator by registering custom media types to be validated by a block. Registering a custom media type will fail if a media type with the specified name is already registered. Note that the validation block is expected to return YES if it does not support the type of the validated instance.
 @warning Avoid calling this method while a schema is already being validated to avoid undefined behavior. To ensure thread-safety, the validation block must be reentrant, independent of external state (like captured mutable objects or block variables) and independent of calling thread.
 @param mediaType Custom media type name. Must not be nil.
 @param block Block used to validate the media type. The block takes validated instance as a parameter and returns YES if the instance is valid against it, or NO otherwise. Must not be nil.
 @param error Error object to contain any error encountered during registration of the media type.
 @return YES, if the media type has been registered successfully, otherwise NO.
 */
+ (BOOL)registerMediaType:(NSString *)mediaType withBlock:(DSJSONContentTypeValidatorBlock)block error:(NSError * __autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
