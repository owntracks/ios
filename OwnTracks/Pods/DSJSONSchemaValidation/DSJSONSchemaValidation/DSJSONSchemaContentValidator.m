//
//  DSJSONSchemaContentValidator.m
//  DSJSONSchemaValidation
//
//  Created by Andrew Podkovyrin on 21/08/2018.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSJSONSchemaContentValidator.h"
#import "DSJSONSchema.h"
#import "DSJSONSchemaFactory.h"
#import "DSJSONSchemaErrors.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DSJSONSchemaContentValidator

static NSString * const kSchemaKeywordContentMediaType = @"contentMediaType";
static NSString * const kSchemaKeywordContentEncoding = @"contentEncoding";

+ (void)initialize
{
    if (self == DSJSONSchemaContentValidator.class) {
        // register standard
        BOOL success = YES;
        
        // decoders
        success &= [self registerEncoding:@"base64" withBlock:[self base64ContentDecoderBlock] error:NULL];
        
        // media type validators
        success &= [self registerMediaType:@"application/json" withBlock:[self applicationJSONContentTypeValidatorBlock] error:NULL];
        
        NSAssert(success, @"Registering standard content decoders/validators must succeed!");
    }
}

- (instancetype)initWithMediaType:(nullable NSString *)mediaType encoding:(nullable NSString *)encoding
{
    self = [super init];
    if (self) {
        _mediaType = [mediaType copy];
        _encoding = [encoding copy];
    }
    return self;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"{ media type: %@, encoding: %@ }", self.mediaType, self.encoding];
}

+ (NSSet<NSString *> *)assignedKeywords
{
    return [NSSet setWithObjects:kSchemaKeywordContentMediaType, kSchemaKeywordContentEncoding, nil];
}

+ (nullable instancetype)validatorWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary schemaFactory:(__unused DSJSONSchemaFactory *)schemaFactory error:(__unused NSError * __autoreleasing *)error
{
    NSString *mediaType = nil;
    if ([schemaDictionary[kSchemaKeywordContentMediaType] isKindOfClass:NSString.class]) {
        mediaType = schemaDictionary[kSchemaKeywordContentMediaType];
    }
    
    NSString *encoding = nil;
    if ([schemaDictionary[kSchemaKeywordContentEncoding] isKindOfClass:NSString.class]) {
        encoding = schemaDictionary[kSchemaKeywordContentEncoding];
    }
    
    return [[self alloc] initWithMediaType:mediaType encoding:encoding];
}

- (nullable NSArray<DSJSONSchema *> *)subschemas
{
    return nil;
}

- (BOOL)validateInstance:(id)instance inContext:(__unused DSJSONSchemaValidationContext *)context error:(NSError *__autoreleasing *)error
{
    // silently succeed if value of the instance is inapplicable
    if ([instance isKindOfClass:NSString.class] == NO) {
        return YES;
    }
    
    NSData *data = nil;
    
    DSJSONContentDecoderBlock decoderBlock = [self.class decoderBlockForEncoding:self.encoding];
    if (decoderBlock) {
        NSError *internalError = nil;
        data = decoderBlock(instance, self, context, &internalError);
        if (internalError) {
            if (error != NULL) {
                *error = internalError;
            }
            return NO;
        }
    }
    else {
        data = [(NSString *)instance dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    DSJSONContentTypeValidatorBlock mediaTypeValidatorBlock = [self.class contentValidatorBlockForMediaType:self.mediaType];
    if (mediaTypeValidatorBlock) {
        NSError *internalError = nil;
        BOOL success = mediaTypeValidatorBlock(data, self, context, &internalError);
        if (internalError) {
            if (error != NULL) {
                *error = internalError;
            }
        }
        return success;
    }
    
    return YES;
}

#pragma mark - Registration

static NSMutableDictionary<NSString *, DSJSONContentDecoderBlock> *decoderBlocks;

+ (nullable DSJSONContentDecoderBlock)decoderBlockForEncoding:(nullable NSString *)encoding
{
    if (!encoding) {
        return nil;
    }
    
    if (decoderBlocks == nil) {
        return nil;
    }
    
    @synchronized(decoderBlocks) {
        NSString *nonnullEncoding = encoding;
        return decoderBlocks[nonnullEncoding];
    }
}

+ (BOOL)registerEncoding:(NSString *)encoding withBlock:(DSJSONContentDecoderBlock)block error:(NSError * __autoreleasing *)error
{
    NSParameterAssert(encoding);
    NSParameterAssert(block);
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        decoderBlocks = [NSMutableDictionary dictionary];
    });
    
    @synchronized(decoderBlocks) {
        if (decoderBlocks[encoding] == nil) {
            decoderBlocks[encoding] = block;
            return YES;
        } else {
            if (error != NULL) {
                *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeContentDecoderAlreadyDefined failingObject:encoding];
            }
            return NO;
        }
    }
}

static NSMutableDictionary<NSString *, DSJSONContentTypeValidatorBlock> *contentValidatorBlocks;

+ (nullable DSJSONContentTypeValidatorBlock)contentValidatorBlockForMediaType:(nullable NSString *)mediaType
{
    if (!mediaType) {
        return nil;
    }
    
    if (contentValidatorBlocks == nil) {
        return nil;
    }
    
    @synchronized(contentValidatorBlocks) {
        NSString *nonnullMediaType = mediaType;
        return contentValidatorBlocks[nonnullMediaType];
    }
}

+ (BOOL)registerMediaType:(NSString *)mediaType withBlock:(DSJSONContentTypeValidatorBlock)block error:(NSError * __autoreleasing *)error
{
    NSParameterAssert(mediaType);
    NSParameterAssert(block);
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        contentValidatorBlocks = [NSMutableDictionary dictionary];
    });
    
    @synchronized(contentValidatorBlocks) {
        if (contentValidatorBlocks[mediaType] == nil) {
            contentValidatorBlocks[mediaType] = block;
            return YES;
        } else {
            if (error != NULL) {
                *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeContentMediaTypeValidatorAlreadyDefined failingObject:mediaType];
            }
            return NO;
        }
    }
}

#pragma mark - Standard

+ (DSJSONContentDecoderBlock)base64ContentDecoderBlock
{
    return ^id _Nullable(id _Nullable value, DSJSONSchemaContentValidator *validator, DSJSONSchemaValidationContext *context, NSError *__autoreleasing  _Nullable * _Nullable error) {
        if (!value) {
            return nil;
        }
        
        id nonnullValue = value;
        NSData *data = [[NSData alloc] initWithBase64EncodedString:nonnullValue options:kNilOptions];
        if (!data) {
            if (error != NULL) {
                NSString *failureReason = @"Object is invalid base64 string.";
                *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:validator reason:failureReason context:context];
            }
            return nil;
        }
        
        return data;
    };
}

+ (DSJSONContentTypeValidatorBlock)applicationJSONContentTypeValidatorBlock
{
    return ^BOOL(id value, DSJSONSchemaContentValidator * _Nonnull validator, DSJSONSchemaValidationContext * _Nonnull context, NSError *__autoreleasing  _Nullable * _Nullable error) {
        NSError *internalError = nil;
        __unused id json = [NSJSONSerialization JSONObjectWithData:value options:NSJSONReadingAllowFragments error:&internalError];
        if (internalError) {
            if (error != NULL) {
                *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:validator reason:internalError.localizedDescription context:context];
            }
            return NO;
        }
        return YES;
    };
}

@end

NS_ASSUME_NONNULL_END
