//
//  DSJSONSchemaValidationContext.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 11/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSJSONSchema;

/**
 This class is used during the validation process to detect infinite loops and compute the validated object's key path.
 */
@interface DSJSONSchemaValidationContext : NSObject

/** Returns the last registered validated schema or nil if none is currently registered. */
@property (nonatomic, nullable, readonly, strong) DSJSONSchema *validatedSchema;
/** Returns the last registered validated object or nil if none is currently registered. */
@property (nonatomic, nullable, readonly, strong) id validatedObject;
/** Returns the current full validation path encoded as a JSON pointer. */
@property (nonatomic, readonly, copy) NSString *validationPath;

/**
 Attempts to push a schema-object pair into the receiver's validation stack.
 @discussion If receiver already contains an association between `validatedSchema` and `validatedObject`, this method will fail.
 @param validatedSchema Schema to push.
 @param validatedObject Validated object to associate with `validatedSchema`.
 @param error Error object to contain any error encountered during registration.
 @return YES if the pair was pushed successfully, otherwise NO.
 */
- (BOOL)pushValidatedSchema:(DSJSONSchema *)validatedSchema object:(id)validatedObject withError:(NSError * __autoreleasing *)error;
/**
 Pops the last schema-object off the the receiver's validation stack.
 @discussion If current validation stack is empty, this method throws an exception.
 */
- (void)popValidatedSchemaAndObject;

/**
 Pushes the specified path component into the receiver's stack of current validation path.
 @param pathComponent The path component to push down the stack. Can be a property name or an array index.
 */
- (void)pushValidationPathComponent:(NSString *)pathComponent;
/**
 Pops the last path component off the receiver's stack of current validation path.
 @discussion If current validation path stack is empty, this method throws an exception.
 */
- (void)popValidationPathComponent;

@end

NS_ASSUME_NONNULL_END
