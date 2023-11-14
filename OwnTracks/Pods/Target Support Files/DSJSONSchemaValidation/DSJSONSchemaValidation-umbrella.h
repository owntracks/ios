#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "DSJSONSchema+Protected.h"
#import "DSJSONSchema+StandardValidators.h"
#import "DSJSONSchemaArrayItemsValidator.h"
#import "DSJSONSchemaArrayValidator.h"
#import "DSJSONSchemaCombiningValidator.h"
#import "DSJSONSchemaConditionalValidator.h"
#import "DSJSONSchemaConstValidator.h"
#import "DSJSONSchemaContainsValidator.h"
#import "DSJSONSchemaContentValidator.h"
#import "DSJSONSchemaDefinitions.h"
#import "DSJSONSchemaDependenciesValidator.h"
#import "DSJSONSchemaEnumValidator.h"
#import "DSJSONSchemaNumericValidator.h"
#import "DSJSONSchemaObjectPropertiesValidator.h"
#import "DSJSONSchemaObjectValidator.h"
#import "DSJSONSchemaPropertyNamesValidator.h"
#import "DSJSONSchemaStringValidator.h"
#import "DSJSONSchemaTypeValidator.h"
#import "DSJSONBooleanSchema.h"
#import "DSJSONDictionarySchema.h"
#import "DSJSONSchema.h"
#import "DSJSONSchemaErrors.h"
#import "DSJSONSchemaFactory.h"
#import "DSJSONSchemaFormatValidator.h"
#import "DSJSONSchemaReference.h"
#import "DSJSONSchemaSpecification.h"
#import "DSJSONSchemaStorage.h"
#import "DSJSONSchemaValidationContext.h"
#import "DSJSONSchemaValidationOptions.h"
#import "DSJSONSchemaValidator.h"
#import "NSArray+DSJSONComparison.h"
#import "NSDictionary+DSJSONComparison.h"
#import "NSDictionary+DSJSONDeepMutableCopy.h"
#import "NSNumber+DSJSONNumberTypes.h"
#import "NSObject+DSJSONComparison.h"
#import "NSString+DSJSONPointer.h"
#import "NSURL+DSJSONReferencing.h"

FOUNDATION_EXPORT double DSJSONSchemaValidationVersionNumber;
FOUNDATION_EXPORT const unsigned char DSJSONSchemaValidationVersionString[];

