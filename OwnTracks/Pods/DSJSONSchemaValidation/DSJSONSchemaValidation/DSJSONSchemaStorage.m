//
//  DSJSONSchemaStorage.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 7/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchemaStorage.h"
#import "DSJSONSchema.h"
#import "NSURL+DSJSONReferencing.h"

#pragma mark - DSJSONSchemaStorage

@interface DSJSONSchemaStorage ()
{
@protected
    NSMutableDictionary<NSURL *, DSJSONSchema *> *_mapping;
}

@end

@implementation DSJSONSchemaStorage

+ (instancetype)storage
{
    return [[self alloc] init];
}

+ (instancetype)storageWithSchema:(DSJSONSchema *)schema
{
    NSDictionary<NSURL *, DSJSONSchema *> *mapping = [self scopeURIMappingFromSchema:schema];
    if (mapping != nil) {
        return [[self alloc] initWithMapping:mapping];
    } else {
        return nil;
    }
}

+ (instancetype)storageWithSchemasArray:(NSArray<DSJSONSchema *> *)schemas
{
    DSJSONSchemaStorage *storage = [[self alloc] init];
    
    for (DSJSONSchema *schema in schemas) {
        NSDictionary<NSURL *, DSJSONSchema *> *mapping = [self scopeURIMappingFromSchema:schema];
        if (mapping != nil) {
            BOOL success = [storage addMapping:mapping];
            if (success == NO) {
                return nil;
            }
        } else {
            return nil;
        }
    }
    
    return storage;
}

- (instancetype)init
{
    return [self initWithMapping:nil];
}

- (instancetype)initWithMapping:(NSDictionary<NSURL *, DSJSONSchema *> *)mapping
{
    self = [super init];
    if (self) {
        _mapping = [NSMutableDictionary dictionaryWithDictionary:mapping];
    }
    
    return self;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@" { %lu schemas }", (unsigned long)_mapping.count];
}

- (instancetype)storageByAddingSchema:(DSJSONSchema *)schema
{
    DSJSONSchemaStorage *newStorage = [[self.class alloc] initWithMapping:_mapping];
    NSDictionary<NSURL *, DSJSONSchema *> *newMapping = [self.class scopeURIMappingFromSchema:schema];
    if (newMapping != nil) {
        BOOL success = [newStorage addMapping:newMapping];
        if (success) {
            return newStorage;
        }
    }
    
    return nil;
}

- (DSJSONSchema *)schemaForURI:(NSURL *)schemaURI
{
    return _mapping[schemaURI.vv_normalizedURI];
}

- (BOOL)addMapping:(NSDictionary<NSURL *, DSJSONSchema *> *)mapping
{
    if (mapping == nil) {
        return NO;
    }
    
    // duplicated resolution scope URIs will be replaced
    //
    //    if (_mapping.count != 0) {
    //        // if adding to a non-empty container, check for duplicates first
    //        NSSet<NSURL *> *existingURIs = [NSSet setWithArray:_mapping.allKeys];
    //        NSSet<NSURL *> *newURIs = [NSSet setWithArray:mapping.allKeys];
    //        if ([existingURIs intersectsSet:newURIs]) {
    //            return NO;
    //        }
    //    }
    
    [_mapping addEntriesFromDictionary:mapping];
    
    return YES;
}

+ (NSDictionary<NSURL *, DSJSONSchema *> *)scopeURIMappingFromSchema:(DSJSONSchema *)schema
{
    NSMutableDictionary<NSURL *, DSJSONSchema *> *schemaURIMapping = [NSMutableDictionary dictionary];
    
    __block BOOL success = YES;
    [schema visitUsingBlock:^(DSJSONSchema *subschema, BOOL *stop) {
        NSURL *subschemaURI = subschema.uri;
        if (schemaURIMapping[subschemaURI] == nil) {
            schemaURIMapping[subschemaURI] = subschema;
        } else {
            // fail on duplicate scopes
            success = NO;
            *stop = YES;
        }
    }];
    
    if (success) {
        return [schemaURIMapping copy];
    } else {
        return nil;
    }
}

#pragma mark - NSCopying

- (id)copyWithZone:(__unused NSZone *)zone
{
    // DSJSONSchemaStorage is immutable
    return self;
}

- (id)mutableCopyWithZone:(__unused NSZone *)zone
{
    return [[DSMutableJSONSchemaStorage alloc] initWithMapping:_mapping];
}

@end

#pragma mark - DSMutableJSONSchemaStorage

@implementation DSMutableJSONSchemaStorage

- (BOOL)addSchema:(DSJSONSchema *)schema
{
    NSDictionary<NSURL *, DSJSONSchema *> *mapping = [self.class scopeURIMappingFromSchema:schema];
    if (mapping != nil) {
        return [self addMapping:mapping];
    } else {
        return NO;
    }
}

- (id)copyWithZone:(__unused NSZone *)zone
{
    return [[DSJSONSchemaStorage alloc] initWithMapping:_mapping];
}

@end
