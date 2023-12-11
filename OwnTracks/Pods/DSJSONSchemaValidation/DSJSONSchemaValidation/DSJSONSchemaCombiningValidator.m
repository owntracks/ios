//
//  DSJSONSchemaCombiningValidator.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 2/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchemaCombiningValidator.h"
#import "DSJSONSchema.h"
#import "DSJSONSchemaFactory.h"
#import "DSJSONSchemaErrors.h"

@implementation DSJSONSchemaCombiningValidator

static NSString * const kSchemaKeywordAllOf = @"allOf";
static NSString * const kSchemaKeywordAnyOf = @"anyOf";
static NSString * const kSchemaKeywordOneOf = @"oneOf";
static NSString * const kSchemaKeywordNot = @"not";

- (instancetype)initWithAllOfSchemas:(NSArray<DSJSONSchema *> *)allOfSchemas anyOfSchemas:(NSArray<DSJSONSchema *> *)anyOfSchemas oneOfSchemas:(NSArray<DSJSONSchema *> *)oneOfSchemas notSchema:(DSJSONSchema *)notSchema
{
    self = [super init];
    if (self) {
        _allOfSchemas = [allOfSchemas copy];
        _anyOfSchemas = [anyOfSchemas copy];
        _oneOfSchemas = [oneOfSchemas copy];
        _notSchema = notSchema;
    }
    
    return self;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"{ all of %lu schemas; any of %lu schemas; one of %lu schemas; not %@ }", (unsigned long)self.allOfSchemas.count, (unsigned long)self.anyOfSchemas.count, (unsigned long)self.oneOfSchemas.count, self.notSchema];
}

+ (NSSet<NSString *> *)assignedKeywords
{
    return [NSSet setWithArray:@[ kSchemaKeywordAllOf, kSchemaKeywordAnyOf, kSchemaKeywordOneOf, kSchemaKeywordNot ]];
}

+ (instancetype)validatorWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary schemaFactory:(DSJSONSchemaFactory *)schemaFactory error:(NSError *__autoreleasing *)error
{
    id allOfObject = schemaDictionary[kSchemaKeywordAllOf];
    id anyOfObject = schemaDictionary[kSchemaKeywordAnyOf];
    id oneOfObect = schemaDictionary[kSchemaKeywordOneOf];
    id notObject = schemaDictionary[kSchemaKeywordNot];
    
    // parse allOf keyword
    NSArray<DSJSONSchema *> *allOfSchemas = nil;
    if (allOfObject != nil) {
        DSJSONSchemaFactory *internalFactory = [schemaFactory factoryByAppendingScopeComponent:kSchemaKeywordAllOf];
        allOfSchemas = [self schemasArrayFromObject:allOfObject factory:internalFactory error:error];
        if (allOfSchemas == nil) {
            return nil;
        }
    }
    
    // parse anyOf keyword
    NSArray<DSJSONSchema *> *anyOfSchemas = nil;
    if (anyOfObject != nil) {
        DSJSONSchemaFactory *internalFactory = [schemaFactory factoryByAppendingScopeComponent:kSchemaKeywordAnyOf];
        anyOfSchemas = [self schemasArrayFromObject:anyOfObject factory:internalFactory error:error];
        if (anyOfSchemas == nil) {
            return nil;
        }
    }
    
    // parse oneOf keyword
    NSArray<DSJSONSchema *> *oneOfSchemas = nil;
    if (oneOfObect != nil) {
        DSJSONSchemaFactory *internalFactory = [schemaFactory factoryByAppendingScopeComponent:kSchemaKeywordOneOf];
        oneOfSchemas = [self schemasArrayFromObject:oneOfObect factory:internalFactory error:error];
        if (oneOfSchemas == nil) {
            return nil;
        }
    }
    
    // parse not keyword
    DSJSONSchema *notSchema = nil;
    if (notObject != nil) {
        // not must be a dictionary
        if ([notObject isKindOfClass:[NSDictionary class]] ||
            [notObject isKindOfClass:[NSNumber class]]) {
            DSJSONSchemaFactory *internalFactory = [schemaFactory factoryByAppendingScopeComponent:kSchemaKeywordNot];
            notSchema = [internalFactory schemaWithObject:notObject error:error];
            if (notSchema == nil) {
                return nil;
            }
        } else {
            if (error != NULL) {
                *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaDictionary];
            }
            return nil;
        }
    }
    
    return [[self alloc] initWithAllOfSchemas:allOfSchemas anyOfSchemas:anyOfSchemas oneOfSchemas:oneOfSchemas notSchema:notSchema];
}

+ (NSArray<DSJSONSchema *> *)schemasArrayFromObject:(id)schemasObject factory:(DSJSONSchemaFactory *)factory error:(NSError * __autoreleasing *)error
{
    NSParameterAssert(schemasObject);
    NSParameterAssert(factory);
    
    if ([self validateSchemasArrayObject:schemasObject] == NO) {
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemasObject];
        }
        return nil;
    }
    
    NSMutableArray<DSJSONSchema *> *schemas = [NSMutableArray arrayWithCapacity:[schemasObject count]];
    
    __block BOOL success = YES;
    __block NSError *internalError = nil;
    [(NSArray<NSDictionary *> *)schemasObject enumerateObjectsUsingBlock:^(NSDictionary *schemaObject, NSUInteger idx, BOOL *stop) {
        NSString *scopeComponent = [NSString stringWithFormat:@"%lu", (unsigned long)idx];
        DSJSONSchemaFactory *internalSchemaFactory = [factory factoryByAppendingScopeComponent:scopeComponent];
        
        DSJSONSchema *schema = [internalSchemaFactory schemaWithObject:schemaObject error:&internalError];
        if (schema != nil) {
            [schemas addObject:schema];
        } else {
            success = NO;
            *stop = YES;
        }
    }];
    
    if (success) {
        return [schemas copy];
    } else {
        if (error != NULL) {
            *error = internalError;
        }
        return nil;
    }
}

+ (BOOL)validateSchemasArrayObject:(id)schemasArrayObject
{
    if ([schemasArrayObject isKindOfClass:[NSArray class]] == NO || [schemasArrayObject count] == 0) {
        return NO;
    }
    for (id item in schemasArrayObject) {
        if ([item isKindOfClass:[NSDictionary class]] == NO &&
            [item isKindOfClass:[NSNumber class]] == NO) {
            return NO;
        }
    }
    
    return YES;
}

- (NSArray<DSJSONSchema *> *)subschemas
{
    NSMutableArray<DSJSONSchema *> *subschemas = [NSMutableArray array];

    NSArray<DSJSONSchema *> *allOfSchemas = self.allOfSchemas;
    if (allOfSchemas != nil) {
        [subschemas addObjectsFromArray:allOfSchemas];
    }

    NSArray<DSJSONSchema *> *anyOfSchemas = self.anyOfSchemas;
    if (anyOfSchemas != nil) {
        [subschemas addObjectsFromArray:anyOfSchemas];
    }

    NSArray<DSJSONSchema *> *oneOfSchemas = self.oneOfSchemas;
    if (oneOfSchemas != nil) {
        [subschemas addObjectsFromArray:oneOfSchemas];
    }

    DSJSONSchema *notSchema = self.notSchema;
    if (notSchema != nil) {
        [subschemas addObject:notSchema];
    }
    
    return [subschemas copy];
}

- (BOOL)validateInstance:(id)instance inContext:(DSJSONSchemaValidationContext *)context error:(NSError *__autoreleasing *)error
{
    // validate "all" schemas
    NSArray<DSJSONSchema *> *allOfSchemas = self.allOfSchemas;
    if (allOfSchemas != nil) {
        for (DSJSONSchema *schema in allOfSchemas) {
            if ([schema validateObject:instance inContext:context error:error] == NO) {
                return NO;
            }
        }
    }
    
    // validate "any of" schemas
    NSArray<DSJSONSchema *> *anyOfSchemas = self.anyOfSchemas;
    if (anyOfSchemas != nil) {
        BOOL success = NO;
        for (DSJSONSchema *schema in anyOfSchemas) {
            // since multiple schemas from "any of" may fail, actual internal errors are not interesting
            success = [schema validateObject:instance inContext:context error:NULL];
            if (success) {
                // no need to check for more than one successful subschema
                break;
            }
        }
        
        if (success == NO) {
            if (error != NULL) {
                NSString *failureReason = @"No 'any of' subschemas satisfied the object.";
                *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
            }
            return NO;
        }
    }
    
    // validate "one of" schemas
    NSArray<DSJSONSchema *> *oneOfSchemas = self.oneOfSchemas;
    if (oneOfSchemas != nil) {
        NSUInteger counter = 0;
        for (DSJSONSchema *schema in oneOfSchemas) {
            // since multiple schemas from "one of" may fail, actual internal errors are not interesting
            if ([schema validateObject:instance inContext:context error:NULL]) {
                counter++;
            }
            if (counter > 1) {
                // no need to check for more than two successul subschemas
                break;
            }
        }
        
        if (counter == 0) {
            if (error != NULL) {
                NSString *failureReason = @"No 'one of' subschemas satisfied the object.";
                *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
            }
            return NO;
        }
        if (counter > 1) {
            if (error != NULL) {
                NSString *failureReason = @"More than one 'one of' subschema satisfied the object.";
                *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
            }
            return NO;
        }
    }
    
    // validate "not" schema
    DSJSONSchema *notSchema = self.notSchema;
    if (notSchema != nil) {
        BOOL success = [notSchema validateObject:instance inContext:context error:NULL];
        if (success) {
            if (error != NULL) {
                NSString *failureReason = @"The 'not' subschema must fail.";
                *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
            }
            return NO;
        }
    }
    
    return YES;
}

@end
