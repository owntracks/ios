//
//  DSJSONSchema+StandardValidators.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 12/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchema.h"
#import "DSJSONSchemaDefinitions.h"
#import "DSJSONSchemaTypeValidator.h"
#import "DSJSONSchemaEnumValidator.h"
#import "DSJSONSchemaNumericValidator.h"
#import "DSJSONSchemaStringValidator.h"
#import "DSJSONSchemaArrayValidator.h"
#import "DSJSONSchemaArrayItemsValidator.h"
#import "DSJSONSchemaObjectValidator.h"
#import "DSJSONSchemaObjectPropertiesValidator.h"
#import "DSJSONSchemaDependenciesValidator.h"
#import "DSJSONSchemaCombiningValidator.h"
#import "DSJSONSchemaFormatValidator.h"
#import "DSJSONSchemaConstValidator.h"
#import "DSJSONSchemaContainsValidator.h"
#import "DSJSONSchemaPropertyNamesValidator.h"
#import "DSJSONSchemaConditionalValidator.h"
#import "DSJSONSchemaContentValidator.h"

NS_ASSUME_NONNULL_BEGIN

/** This category provides a loading point for standard JSON Schema draft 4 validators. */
@interface DSJSONSchema (StandardValidators)

@end

NS_ASSUME_NONNULL_END
