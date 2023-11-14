//
//  DSJSONSchemaPropertyNamesValidator.m
//  DSJSONSchemaValidation
//
//  Created by Andrew Podkovyrin on 14/08/2018.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSJSONSchemaPropertyNamesValidator.h"
#import "DSJSONSchema.h"
#import "DSJSONSchemaFactory.h"
#import "DSJSONSchemaErrors.h"

NS_ASSUME_NONNULL_BEGIN

static NSString * const kSchemaKeywordPropertyNames = @"propertyNames";

@implementation DSJSONSchemaPropertyNamesValidator

- (instancetype)initWithSchema:(DSJSONSchema *)schema
{
    NSParameterAssert(schema);
    self = [super init];
    if (self) {
        _schema = schema;
    }
    return self;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"{ schema: %@ }", self.schema];
}

+ (NSSet<NSString *> *)assignedKeywords
{
    return [NSSet setWithObject:kSchemaKeywordPropertyNames];
}

+ (nullable instancetype)validatorWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary schemaFactory:(DSJSONSchemaFactory *)schemaFactory error:(NSError * __autoreleasing *)error
{
    id propertyNamesObject = schemaDictionary[kSchemaKeywordPropertyNames];
    NSError *internalError = nil;
    DSJSONSchema *propertyNamesSchema = nil;
    if ([propertyNamesObject isKindOfClass:[NSDictionary class]] ||
        [propertyNamesObject isKindOfClass:[NSNumber class]]) {
        // contains object is a dictionary or boolean - parse it as a schema;
        // schema will have scope extended by "/propertyNames"
        DSJSONSchemaFactory *propertyNamesSchemaFactory = [schemaFactory factoryByAppendingScopeComponentsFromArray:@[ kSchemaKeywordPropertyNames ]];
        
        propertyNamesSchema = [propertyNamesSchemaFactory schemaWithObject:propertyNamesObject error:&internalError];
    }
    
    if (propertyNamesSchema) {
        return [[self alloc] initWithSchema:propertyNamesSchema];
    }
    else {
        if (error != NULL) {
            *error = internalError ?: [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaDictionary];
        }
        return nil;
    }
}

- (nullable NSArray<DSJSONSchema *> *)subschemas
{
    return @[ self.schema ];
}

- (BOOL)validateInstance:(id)instance inContext:(DSJSONSchemaValidationContext *)context error:(NSError *__autoreleasing *)error
{
    // silently succeed if value of the instance is inapplicable
    if ([instance isKindOfClass:[NSDictionary class]] == NO) {
        return YES;
    }
    
    // object without properties is valid
    if ([instance count] == 0) {
        return YES;
    }
    
    // validate each property name with the schema
    NSError *internalError = nil;
    BOOL success = YES;
    for (NSString *propertyName in instance) {
        success = [self.schema validateObject:propertyName inContext:context error:&internalError];
        if (!success) {
            break;
        }
    }

    if (success == NO) {
        if (error != NULL) {
            *error = internalError;
        }
    }
    
    return success;
}

@end

NS_ASSUME_NONNULL_END
