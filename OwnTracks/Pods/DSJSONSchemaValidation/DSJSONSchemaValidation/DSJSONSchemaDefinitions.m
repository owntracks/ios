//
//  DSJSONSchemaDefinitions.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 30/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchemaDefinitions.h"
#import "DSJSONSchemaFactory.h"
#import "DSJSONSchemaErrors.h"

@implementation DSJSONSchemaDefinitions
{
    NSArray<DSJSONSchema *> *_schemas;
}

static NSString * const kSchemaKeywordDefinitions = @"definitions";

- (instancetype)initWithSchemas:(NSArray<DSJSONSchema *> *)schemas
{
    self = [super init];
    if (self) {
        _schemas = [schemas copy];
    }
    
    return self;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"{ %lu subschemas }", (unsigned long)_schemas.count];
}

+ (NSSet<NSString *> *)assignedKeywords
{
    return [NSSet setWithObject:kSchemaKeywordDefinitions];
}

+ (instancetype)validatorWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary schemaFactory:(DSJSONSchemaFactory *)schemaFactory error:(NSError * __autoreleasing *)error
{
    // check that "definitions" is a dictionary
    id definitions = schemaDictionary[kSchemaKeywordDefinitions];
    if ([definitions isKindOfClass:[NSDictionary class]] == NO) {
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaDictionary];
        }
        return nil;
    }
    
    // parse the subschemas
    NSMutableArray<DSJSONSchema *> *schemas = [NSMutableArray arrayWithCapacity:[definitions count]];
    __block BOOL success = YES;
    __block NSError *internalError = nil;
    [(NSDictionary<NSString *, id> *)definitions enumerateKeysAndObjectsUsingBlock:^(NSString *key, id schemaObject, BOOL *stop) {
        if ([schemaObject isKindOfClass:[NSDictionary class]] == NO &&
            [schemaObject isKindOfClass:[NSNumber class]] == NO) {
            internalError = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaObject];
            success = NO;
            *stop = YES;
            return;
        }
        
        // each subschema has its resolution scope extended by "definitions/[schema_name]"
        DSJSONSchemaFactory *definitionFactory = [schemaFactory factoryByAppendingScopeComponentsFromArray:@[ kSchemaKeywordDefinitions, key ]];
        
        DSJSONSchema *schema = [definitionFactory schemaWithObject:schemaObject error:&internalError];
        if (schema != nil) {
            [schemas addObject:schema];
        } else {
            success = NO;
            *stop = YES;
            return;
        }
    }];
    
    if (success) {
        return [[self alloc] initWithSchemas:schemas];
    } else {
        if (error != NULL) {
            *error = internalError;
        }
        return nil;
    }
}

- (NSArray<DSJSONSchema *> *)subschemas
{
    return _schemas;
}

- (BOOL)validateInstance:(__unused id)instance inContext:(__unused DSJSONSchemaValidationContext *)context error:(__unused NSError *__autoreleasing *)error
{
    // definitions "validator" always succeeds
    return YES;
}

@end
