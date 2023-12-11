//
//  DSJSONSchemaDefinitions.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 30/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSJSONSchemaValidator.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Implements "definitions" keyword.
 @discussion While conforming to the `DSJSONSchemaValidator` protocol, this class is not really a validator. Its purpose is to store subschemas defined in "definitions" property of the schema.
 */
@interface DSJSONSchemaDefinitions : NSObject <DSJSONSchemaValidator>

@end

NS_ASSUME_NONNULL_END
