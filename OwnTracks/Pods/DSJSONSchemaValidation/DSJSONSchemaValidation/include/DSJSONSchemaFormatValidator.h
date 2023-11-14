//
//  DSJSONSchemaFormatValidator.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 3/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSJSONSchemaValidator.h"

NS_ASSUME_NONNULL_BEGIN

typedef BOOL(^DSJSONSchemaFormatValidatorBlock)(id instance);

/**
 Implements "format" keyword. Applicable to all instance types, though standard formats only validate string instances.
 @discussion Clients can register custom formats to validate them without modifying this validator class. Refer to methods `+registerFormat:withRegularExpression:error:` and `+registerFormat:withBlock:error:` for details.
 */
@interface DSJSONSchemaFormatValidator : NSObject <DSJSONSchemaValidator>

/** Name of the format a valid instance must comply to. */
@property (nonatomic, readonly, copy) NSString *formatName;

/**
 Registers the specified regular expression to be used to validate the specified format.
 @discussion This method allows extending basic functionality of the format validator by registering custom formats to be validated by a regular expression. Registering a custom format will fail if a format with the specified name is already registered. Validation by a regular expression will silently succeed if a validated instance is not a string.
 @warning Avoid calling this method while a schema is already being validated to avoid undefined behavior.
 @param format Custom format name. Must not be nil.
 @param regularExpression Regular expression used to validate the format. Must not be nil.
 @param error Error object to contain any error encountered during registration of the format.
 @return YES, if the format has been registered successfully, otherwise NO.
 */
+ (BOOL)registerFormat:(NSString *)format withRegularExpression:(NSRegularExpression *)regularExpression error:(NSError * __autoreleasing *)error;
/**
 Registers the specified block to be used to validate the specified format.
 @discussion This method allows extending basic functionality of the format validator by registering custom formats to be validated by a block. Registering a custom format will fail if a format with the specified name is already registered. Note that the validation block is expected to return YES if it does not support the type of the validated instance.
 @warning Avoid calling this method while a schema is already being validated to avoid undefined behavior. To ensure thread-safety, the validation block must be reentrant, independent of external state (like captured mutable objects or block variables) and independent of calling thread.
 @param format Custom format name. Must not be nil.
 @param block Block used to validate the format. The block takes validated instance as a parameter and returns YES if the instance is valid against it, or NO otherwise. Must not be nil.
 @param error Error object to contain any error encountered during registration of the format.
 @return YES, if the format has been registered successfully, otherwise NO.
 */
+ (BOOL)registerFormat:(NSString *)format withBlock:(DSJSONSchemaFormatValidatorBlock)block error:(NSError * __autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
