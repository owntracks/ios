//
//  NSString+DSJSONPointer.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 2/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (DSJSONPointer)

/** Returns a string constructed from receiver by escaping JSON Pointer special characters. */
- (NSString *)vv_stringByEncodingAsJSONPointer;
/** Returns a string constructed from receiver by unescaping JSON Pointer special characters. */
- (NSString *)vv_stringByDecodingAsJSONPointer;

/** Returns a string representing a JSON Pointer composed of the specified path components. */
+ (NSString *)vv_JSONPointerStringFromPathComponents:(NSArray<NSString *> *)pathComponents;

@end

NS_ASSUME_NONNULL_END
