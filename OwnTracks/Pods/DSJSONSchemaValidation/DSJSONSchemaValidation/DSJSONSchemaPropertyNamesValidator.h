//
//  DSJSONSchemaPropertyNamesValidator.h
//  DSJSONSchemaValidation
//
//  Created by Andrew Podkovyrin on 14/08/2018.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSJSONSchemaValidator.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Implements "propertyNames" keyword. Applicable to object instances.
 */
@interface DSJSONSchemaPropertyNamesValidator : NSObject <DSJSONSchemaValidator>

/**
 A schema which validates the names of all properties of object. Empty object is valid.
 Any other type is valid.
 */
@property (readonly, strong, nonatomic) DSJSONSchema *schema;

@end

NS_ASSUME_NONNULL_END
