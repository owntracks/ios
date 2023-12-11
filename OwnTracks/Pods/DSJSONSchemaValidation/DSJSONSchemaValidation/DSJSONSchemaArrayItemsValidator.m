//
//  DSJSONSchemaArrayItemsValidator.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 1/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchemaArrayItemsValidator.h"
#import "DSJSONSchema.h"
#import "DSJSONSchemaFactory.h"
#import "DSJSONSchemaErrors.h"
#import "DSJSONSchemaValidationContext.h"
#import "NSNumber+DSJSONNumberTypes.h"

@implementation DSJSONSchemaArrayItemsValidator

static NSString * const kSchemaKeywordItems = @"items";
static NSString * const kSchemaKeywordAdditionalItems = @"additionalItems";

- (instancetype)initWithItemsSchema:(DSJSONSchema *)itemsSchema orItemSchemas:(NSArray<DSJSONSchema *> *)itemSchemas additionalItemsSchema:(DSJSONSchema *)additionalItemsSchema additionalItemsAllowed:(BOOL)additionalItemsAllowed
{
    NSAssert(itemsSchema == nil || itemSchemas == nil, @"Can either have single item schema or item schemas array.");
    NSAssert(additionalItemsSchema == nil || additionalItemsAllowed, @"Cannot have additional items schema if additional items are not allowed.");
    
    self = [super init];
    if (self) {
        _itemsSchema = itemsSchema;
        _itemSchemas = [itemSchemas copy];
        _additionalItemsSchema = additionalItemsSchema;
        _additionalItemsAllowed = additionalItemsAllowed;
    }
    
    return self;
}

- (NSString *)description
{
    NSString *itemSchemasDescription;
    if (self.itemsSchema != nil) {
        itemSchemasDescription = self.itemsSchema.description;
    } else {
        itemSchemasDescription = [NSString stringWithFormat:@"%lu schemas", (unsigned long)self.itemSchemas.count];
    }
    
    NSString *additionalItemsDescription;
    if (self.additionalItemsSchema != nil) {
        additionalItemsDescription = self.additionalItemsSchema.description;
    } else {
        additionalItemsDescription = (self.additionalItemsAllowed ? @"allowed" : @"not allowed");
    }
    
    return [[super description] stringByAppendingFormat:@"{ items: %@; additional items: %@ }", itemSchemasDescription, additionalItemsDescription];
}

+ (NSSet<NSString *> *)assignedKeywords
{
    return [NSSet setWithArray:@[ kSchemaKeywordItems, kSchemaKeywordAdditionalItems ]];
}

+ (instancetype)validatorWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary schemaFactory:(DSJSONSchemaFactory *)schemaFactory error:(NSError * __autoreleasing *)error
{
    id itemsObject = schemaDictionary[kSchemaKeywordItems];
    id additionalItemsObject = schemaDictionary[kSchemaKeywordAdditionalItems];
    
    // parse items keyword
    DSJSONSchema *itemsSchema = nil;
    NSArray<DSJSONSchema *> *itemSchemas = nil;
    if ([itemsObject isKindOfClass:[NSDictionary class]] ||
        [itemsObject isKindOfClass:[NSNumber class]]) {
        // parse as a schema object; schema will have scope extended by "/items"
        DSJSONSchemaFactory *itemsSchemaFactory = [schemaFactory factoryByAppendingScopeComponent:kSchemaKeywordItems];
        itemsSchema = [itemsSchemaFactory schemaWithObject:itemsObject error:error];
        if (itemsSchema == nil) {
            return nil;
        }
    } else if ([itemsObject isKindOfClass:[NSArray class]]) {
        // parse as a schemas array
        NSMutableArray<DSJSONSchema *> *schemas = [NSMutableArray arrayWithCapacity:[itemsObject count]];
        
        __block BOOL success = YES;
        __block NSError *internalError = nil;
        [(NSArray<id> *)itemsObject enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            // schema object must be a dictionary
            if ([obj isKindOfClass:[NSDictionary class]] ||
                [obj isKindOfClass:[NSNumber class]]) {
                // each schema will have scope extended by "/items/#" where # is its index
                NSString *indexString = [NSString stringWithFormat:@"%lu", (unsigned long)idx];
                DSJSONSchemaFactory *itemSchemaFactory = [schemaFactory factoryByAppendingScopeComponentsFromArray:@[ kSchemaKeywordItems, indexString ]];
                
                DSJSONSchema *itemSchema = [itemSchemaFactory schemaWithObject:obj error:&internalError];
                if (itemSchema != nil) {
                    [schemas addObject:itemSchema];
                } else {
                    success = NO;
                }
            } else {
                success = NO;
                internalError = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:itemsObject];
            }
            
            if (success == NO) {
                *stop = YES;
            }
        }];
        
        if (success) {
            itemSchemas = [schemas copy];
        } else {
            if (error != NULL) {
                *error = internalError;
            }
            return nil;
        }
    } else if (itemsObject != nil) {
        // invalid instance
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaDictionary];
        }
        return nil;
    }
    
    // parse additionalItems keyword
    DSJSONSchema *additionalItemsSchema = nil;
    BOOL additionalItemsAllowed = YES;
    if ([additionalItemsObject isKindOfClass:[NSDictionary class]]) {
        // parse as a schema object; schema will have scope extended by "/additionalItems"
        DSJSONSchemaFactory *additionalSchemaFactory = [schemaFactory factoryByAppendingScopeComponent:kSchemaKeywordAdditionalItems];
        additionalItemsSchema = [additionalSchemaFactory schemaWithObject:additionalItemsObject error:error];
        if (additionalItemsSchema == nil) {
            return nil;
        }
    } else if ([additionalItemsObject isKindOfClass:[NSNumber class]] && [additionalItemsObject ds_isBoolean]) {
        // parse as a boolean
        additionalItemsAllowed = [additionalItemsObject boolValue];
    } else if (additionalItemsObject != nil) {
        // invalid instance
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaDictionary];
        }
        return nil;
    }
    
    return [[self alloc] initWithItemsSchema:itemsSchema orItemSchemas:itemSchemas additionalItemsSchema:additionalItemsSchema additionalItemsAllowed:additionalItemsAllowed];
}

- (NSArray<DSJSONSchema *> *)subschemas
{
    NSMutableArray<DSJSONSchema *> *subschemas = [NSMutableArray array];

    DSJSONSchema *itemsSchema = self.itemsSchema;
    if (itemsSchema != nil) {
        [subschemas addObject:itemsSchema];
    }

    NSArray<DSJSONSchema *> *itemSchemas = self.itemSchemas;
    if (itemSchemas != nil) {
        [subschemas addObjectsFromArray:itemSchemas];
    }

    DSJSONSchema *additionalItemsSchema = self.additionalItemsSchema;
    if (additionalItemsSchema != nil) {
        [subschemas addObject:additionalItemsSchema];
    }
    
    return [subschemas copy];
}

- (BOOL)validateInstance:(id)instance inContext:(DSJSONSchemaValidationContext *)context error:(NSError *__autoreleasing *)error
{
    // silently succeed if value of the instance is inapplicable
    if ([instance isKindOfClass:[NSArray class]] == NO) {
        return YES;
    }
    
    // validate each item with the corresponding schema
    __block BOOL success = YES;
    __block NSError *internalError = nil;
    [(NSArray<id> *)instance enumerateObjectsUsingBlock:^(id item, NSUInteger idx, BOOL *stop) {
        NSString *failureReason;
        DSJSONSchema *schema = [self schemaForInstanceItemAtIndex:idx failureReason:&failureReason];
        if (schema != nil) {
            [context pushValidationPathComponent:[NSString stringWithFormat:@"%lu", (unsigned long)idx]];
            BOOL result = [schema validateObject:item inContext:context error:&internalError];
            [context popValidationPathComponent];
            
            if (result == NO) {
                success = NO;
                *stop = YES;
            }
        } else if (failureReason != nil) {
            internalError = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
            success = NO;
            *stop = YES;
        }
    }];
    
    if (success == NO) {
        if (error != NULL) {
            *error = internalError;
        }
    }
    
    return success;
}

- (DSJSONSchema *)schemaForInstanceItemAtIndex:(NSUInteger)itemIndex failureReason:(NSString * __autoreleasing *)failureReason
{
    DSJSONSchema *itemsSchema = self.itemsSchema;
    NSArray<DSJSONSchema *> *itemSchemas = self.itemSchemas;

    if (itemsSchema != nil) {
        // item schemas are defined as a single schema - return this schema
        return itemsSchema;
    } else if (itemSchemas != nil) {
        // item schemas are defined as an array
        if (itemIndex < itemSchemas.count) {
            // item index is within bounds of the schema array - return schema at that index
            return itemSchemas[itemIndex];
        } else {
            DSJSONSchema *additionalItemsSchema = self.additionalItemsSchema;
            // otherwise, respect the additional items configuration
            if (additionalItemsSchema != nil) {
                // additional items schema is defined - return this schema
                return additionalItemsSchema;
            } else if (self.additionalItemsAllowed) {
                // additional items schema is not defined, but any additional items are allowed
                return nil;
            } else {
                // additional items are not allowed
                *failureReason = [NSString stringWithFormat:@"More than %lu objects in the array is not allowed", (unsigned long)self.itemSchemas.count];
                return nil;
            }
        }
    } else {
        // if item schemas are defined neither as a single schema nor a schema array,
        // it is equivalent to defining a single empty schema, which means any instance is valid,
        // regardless of "additional items" configuration
        return nil;
    }
}

@end
