//
//  DSJSONSchema+StandardValidators.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 30/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchema+StandardValidators.h"

@implementation DSJSONSchema (StandardValidators)

+ (void)load
{
    // register all standard validators for default metaschema
    NSArray<Class<DSJSONSchemaValidator>> *draft4ValidatorClasses = @[ [DSJSONSchemaDefinitions class], [DSJSONSchemaTypeValidator class], [DSJSONSchemaEnumValidator class], [DSJSONSchemaNumericValidator class], [DSJSONSchemaStringValidator class], [DSJSONSchemaArrayValidator class], [DSJSONSchemaArrayItemsValidator class], [DSJSONSchemaObjectValidator class], [DSJSONSchemaObjectPropertiesValidator class], [DSJSONSchemaDependenciesValidator class], [DSJSONSchemaCombiningValidator class], [DSJSONSchemaFormatValidator class] ];
    
    NSMutableArray<Class<DSJSONSchemaValidator>> *draft6ValidatorClasses = [draft4ValidatorClasses mutableCopy];
    [draft6ValidatorClasses addObjectsFromArray:@[ [DSJSONSchemaConstValidator class], [DSJSONSchemaContainsValidator class], [DSJSONSchemaPropertyNamesValidator class] ]];
    
    NSMutableArray<Class<DSJSONSchemaValidator>> *draft7ValidatorClasses = [draft6ValidatorClasses mutableCopy];
    [draft7ValidatorClasses addObjectsFromArray:@[ [DSJSONSchemaConditionalValidator class], [DSJSONSchemaContentValidator class] ] ];
    
    for (Class<DSJSONSchemaValidator> validatorClass in draft4ValidatorClasses) {
        if ([self registerValidatorClass:validatorClass forMetaschemaURI:nil specification:[DSJSONSchemaSpecification draft4]  withError:NULL] == NO) {
            [NSException raise:NSInternalInconsistencyException format:@"Failed to register standard JSON draft-04 Schema validators."];
        }
    }
    for (Class<DSJSONSchemaValidator> validatorClass in draft6ValidatorClasses) {
        if ([self registerValidatorClass:validatorClass forMetaschemaURI:nil specification:[DSJSONSchemaSpecification draft6]  withError:NULL] == NO) {
            [NSException raise:NSInternalInconsistencyException format:@"Failed to register standard JSON draft-06 Schema validators."];
        }
    }
    for (Class<DSJSONSchemaValidator> validatorClass in draft7ValidatorClasses) {
        if ([self registerValidatorClass:validatorClass forMetaschemaURI:nil specification:[DSJSONSchemaSpecification draft7]  withError:NULL] == NO) {
            [NSException raise:NSInternalInconsistencyException format:@"Failed to register standard JSON draft-07 Schema validators."];
        }
    }
}

@end
