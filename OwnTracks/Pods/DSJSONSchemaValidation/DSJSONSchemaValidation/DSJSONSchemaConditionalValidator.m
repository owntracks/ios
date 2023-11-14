//
//  DSJSONSchemaConditionalValidator.m
//  DSJSONSchemaValidationTests
//
//  Created by Andrew Podkovyrin on 20/08/2018.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSJSONSchemaConditionalValidator.h"
#import "DSJSONSchema.h"
#import "DSJSONSchemaFactory.h"
#import "DSJSONSchemaErrors.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DSJSONSchemaConditionalValidator

static NSString * const kSchemaKeywordIf = @"if";
static NSString * const kSchemaKeywordThen = @"then";
static NSString * const kSchemaKeywordElse = @"else";

- (instancetype)initWithIfSchema:(DSJSONSchema *)ifSchema thenSchema:(DSJSONSchema *)thenSchema elseSchema:(DSJSONSchema *)elseSchema
{
    NSAssert(ifSchema || thenSchema || elseSchema, @"One of the conditional subschemas must be presented");
    self = [super init];
    if (self) {
        _ifSchema = ifSchema;
        _thenSchema = thenSchema;
        _elseSchema = elseSchema;
    }
    return self;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"{ if schema: %@, then schema: %@, else schema: %@ }", self.ifSchema, self.thenSchema, self.elseSchema];
}

+ (NSSet<NSString *> *)assignedKeywords
{
    return [NSSet setWithObjects:kSchemaKeywordIf, kSchemaKeywordThen, kSchemaKeywordElse, nil];
}

+ (nullable instancetype)validatorWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary schemaFactory:(DSJSONSchemaFactory *)schemaFactory error:(NSError * __autoreleasing *)error
{
    DSJSONSchema *ifSchema = nil;
    id object = schemaDictionary[kSchemaKeywordIf];
    NSError *internalError = nil;
    if ([object isKindOfClass:[NSDictionary class]] ||
        [object isKindOfClass:[NSNumber class]]) {
        // contains object is a dictionary or boolean - parse it as a schema;
        // schema will have scope extended by "/if"
        DSJSONSchemaFactory *extendedSchemaFactory = [schemaFactory factoryByAppendingScopeComponentsFromArray:@[ kSchemaKeywordIf ]];
        
        ifSchema = [extendedSchemaFactory schemaWithObject:object error:&internalError];
    }
    if (internalError) {
        if (error != NULL) {
            *error = internalError;
        }
        return nil;
    }
    
    DSJSONSchema *thenSchema = nil;
    object = schemaDictionary[kSchemaKeywordThen];
    if ([object isKindOfClass:[NSDictionary class]] ||
        [object isKindOfClass:[NSNumber class]]) {
        // contains object is a dictionary or boolean - parse it as a schema;
        // schema will have scope extended by "/then"
        DSJSONSchemaFactory *extendedSchemaFactory = [schemaFactory factoryByAppendingScopeComponentsFromArray:@[ kSchemaKeywordThen ]];
        
        thenSchema = [extendedSchemaFactory schemaWithObject:object error:&internalError];
    }
    if (internalError) {
        if (error != NULL) {
            *error = internalError;
        }
        return nil;
    }
    
    DSJSONSchema *elseSchema = nil;
    object = schemaDictionary[kSchemaKeywordElse];
    if ([object isKindOfClass:[NSDictionary class]] ||
        [object isKindOfClass:[NSNumber class]]) {
        // contains object is a dictionary or boolean - parse it as a schema;
        // schema will have scope extended by "/else"
        DSJSONSchemaFactory *extendedSchemaFactory = [schemaFactory factoryByAppendingScopeComponentsFromArray:@[ kSchemaKeywordElse ]];
        
        elseSchema = [extendedSchemaFactory schemaWithObject:object error:&internalError];
    }
    if (internalError) {
        if (error != NULL) {
            *error = internalError;
        }
        return nil;
    }
    
    
    if (ifSchema || thenSchema || elseSchema) {
        return [[self alloc] initWithIfSchema:ifSchema thenSchema:thenSchema elseSchema:elseSchema];
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
    NSMutableArray *subschemas = [NSMutableArray array];
    if (self.ifSchema) {
        DSJSONSchema *schema = self.ifSchema;
        [subschemas addObject:schema];
    }
    if (self.thenSchema) {
        DSJSONSchema *schema = self.thenSchema;
        [subschemas addObject:schema];
    }
    if (self.elseSchema) {
        DSJSONSchema *schema = self.elseSchema;
        [subschemas addObject:schema];
    }
    return [subschemas copy];
}

- (BOOL)validateInstance:(id)instance inContext:(DSJSONSchemaValidationContext *)context error:(NSError *__autoreleasing *)error
{
    // silently succeed if there is no `ifSchema` or (`thenSchema` and `elseSchema`)
    if (self.ifSchema == nil || (self.thenSchema == nil && self.elseSchema == nil)) {
        return YES;
    }
    
    BOOL ifValidationResult = [self.ifSchema validateObject:instance inContext:context error:nil];
    
    if (ifValidationResult) {
        if (self.thenSchema == nil) {
            return YES;
        }
        
        NSError *thenError = nil;
        BOOL thenValidationResult = [self.thenSchema validateObject:instance inContext:context error:&thenError];
        if (error != NULL) {
            *error = thenError;
        }
        
        return thenValidationResult;
    }
    else {
        if (self.elseSchema == nil) {
            return YES;
        }
        
        NSError *elseError = nil;
        BOOL elseValidationResult = [self.elseSchema validateObject:instance inContext:context error:&elseError];
        if (error != NULL) {
            *error = elseError;
        }
        
        return elseValidationResult;
    }

    return YES;
}

@end

NS_ASSUME_NONNULL_END
