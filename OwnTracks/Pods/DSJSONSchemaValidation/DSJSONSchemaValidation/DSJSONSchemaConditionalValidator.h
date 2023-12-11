//
//  DSJSONSchemaConditionalValidator.h
//  DSJSONSchemaValidationTests
//
//  Created by Andrew Podkovyrin on 20/08/2018.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSJSONSchemaValidator.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Implements "if", "then" and "else" keywords. Applicable to any instances.
 */
@interface DSJSONSchemaConditionalValidator : NSObject <DSJSONSchemaValidator>

@property (nonatomic, nullable, readonly, strong) DSJSONSchema *ifSchema;
@property (nonatomic, nullable, readonly, strong) DSJSONSchema *thenSchema;
@property (nonatomic, nullable, readonly, strong) DSJSONSchema *elseSchema;

@end

NS_ASSUME_NONNULL_END
