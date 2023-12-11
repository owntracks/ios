//
//  DSJSONSchemaContainsValidator.h
//  DSJSONSchemaValidation
//
//  Created by Andrew Podkovyrin on 14/08/2018.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSJSONSchemaValidator.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Implements "contains" keyword. Applicable to array instances.
 */
@interface DSJSONSchemaContainsValidator : NSObject <DSJSONSchemaValidator>

/**
 Any item of non-empty an array instance must validate against the schema. Empty array is invalid. Any other type is valid.
 */
@property (readonly, strong, nonatomic) DSJSONSchema *schema;

@end

NS_ASSUME_NONNULL_END
