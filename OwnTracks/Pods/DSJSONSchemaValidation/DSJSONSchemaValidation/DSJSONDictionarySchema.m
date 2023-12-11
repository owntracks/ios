//
//  DSJSONDictionarySchema.m
//  DSJSONSchemaValidation
//
//  Created by Andrew Podkovyrin on 11/08/2018.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSJSONDictionarySchema.h"
#import "DSJSONSchema+Protected.h"
#import "DSJSONSchemaFactory.h"
#import "DSJSONSchemaValidationContext.h"
#import "NSURL+DSJSONReferencing.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DSJSONDictionarySchema

static NSString * const kSchemaKeywordSchema = @"$schema";

#pragma mark - Schema parsing

+ (nullable instancetype)schemaWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary baseURI:(nullable NSURL *)baseURI referenceStorage:(nullable DSJSONSchemaStorage *)referenceStorage specification:(DSJSONSchemaSpecification *)specification options:(DSJSONSchemaValidationOptions *)options error:(NSError * __autoreleasing *)error
{
    if ([schemaDictionary isKindOfClass:NSDictionary.class] == NO) {
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaDictionary];
        }
        return nil;
    }
    
    // retrieve metaschema URI
    id metaschemaURIString = schemaDictionary[kSchemaKeywordSchema];
    if (metaschemaURIString != nil && [metaschemaURIString isKindOfClass:[NSString class]] == NO) {
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaDictionary];
        }
        return nil;
    }
    NSURL *metaschemaURI = [NSURL URLWithString:metaschemaURIString];
    
    // check that metaschema is supported
    if ([specification.unsupportedMetaschemaURIs containsObject:metaschemaURI]) {
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeIncompatibleMetaschema failingObject:metaschemaURIString];
        }
        return nil;
    }
    
    // retrieve validator mapping for this metaschema
    NSDictionary<NSString *, Class> *keywordsMapping = [self validatorsMappingForMetaschemaURI:metaschemaURI specification:specification];
    NSAssert(keywordsMapping.count > 0, @"No keywords defined!");
    
    // if base URI is not present, replace it with an empty one
    NSURL *scopeURI = baseURI ?: [NSURL URLWithString:@""];
    scopeURI = scopeURI.vv_normalizedURI;
    
    DSJSONSchema *schema = nil;
    // have to be careful around autorelease pool and reference-returned autoreleasing objects...
    NSError *internalError = nil;
    @autoreleasepool {
        // instantiate a root schema factory and use it to create the schema
        DSJSONSchemaFactory *factory = [DSJSONSchemaFactory factoryWithScopeURI:scopeURI keywordsMapping:keywordsMapping specification:specification options:options];
        schema = [factory schemaWithObject:schemaDictionary error:&internalError];
        
        if (schema != nil) {
            // create a schema storage to resolve references
            DSJSONSchemaStorage *resolvingStorage;
            if (referenceStorage != nil) {
                resolvingStorage = [referenceStorage storageByAddingSchema:schema];
            } else {
                resolvingStorage = [DSJSONSchemaStorage storageWithSchema:schema];
            }
            
            if (resolvingStorage != nil) {
                // resolve all schema references
                BOOL success = [schema resolveReferencesWithSchemaStorage:resolvingStorage error:&internalError];
                
                if (success) {
                    // detect reference cycles
                    [schema detectReferenceCyclesWithError:&internalError];
                }
            } else {
                // if creating a schema storage failed, it means there are duplicate scope URIs
                internalError = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeDuplicateResolutionScope failingObject:schemaDictionary];
            }
        }
    }
    
    if (internalError == nil) {
        return (DSJSONDictionarySchema *)schema;
    } else {
        if (error != NULL) {
            *error = internalError;
        }
        return nil;
    }
}

@end

NS_ASSUME_NONNULL_END
