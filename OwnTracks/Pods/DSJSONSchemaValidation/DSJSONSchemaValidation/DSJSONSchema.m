//
//  DSJSONSchema.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 28/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchema.h"
#import "DSJSONDictionarySchema.h"
#import "DSJSONBooleanSchema.h"
#import "DSJSONSchemaReference.h"
#import "NSNumber+DSJSONNumberTypes.h"

@implementation DSJSONSchema

- (instancetype)initWithScopeURI:(NSURL *)uri title:(nullable NSString *)title description:(nullable NSString *)description validators:(nullable NSArray<id<DSJSONSchemaValidator>> *)validators subschemas:(nullable NSArray<DSJSONSchema *> *)subschemas specification:(DSJSONSchemaSpecification *)specification options:(nullable DSJSONSchemaValidationOptions *)options
{
    NSParameterAssert(uri);
    
    self = [super init];
    if (self) {
        _uri = uri;
        _title = [title copy];
        _schemaDescription = [description copy];
        _validators = [validators copy];
        _subschemas = [subschemas copy];
        _specification = specification;
        _options = options ?: [[DSJSONSchemaValidationOptions alloc] init];
        
        // check if options is appliable
        NSAssert(options.removeAdditional == DSJSONSchemaValidationOptionsRemoveAdditionalNone ||
                 specification.version == DSJSONSchemaSpecificationVersionDraft6 ||
                 specification.version == DSJSONSchemaSpecificationVersionDraft7,
                 @"`removeAdditional` option is not available for the draft 4 specification");
    }
    
    return self;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"{ %@; '%@': '%@'; %lu validators; %lu subschemas }", self.uri, self.title, self.schemaDescription, (unsigned long)self.validators.count, (unsigned long)self.subschemas.count];
}

#pragma mark - Schema parsing

+ (nullable instancetype)schemaWithObject:(id)foundationObject baseURI:(nullable NSURL *)baseURI referenceStorage:(nullable DSJSONSchemaStorage *)referenceStorage specification:(DSJSONSchemaSpecification *)specification options:(nullable DSJSONSchemaValidationOptions *)options error:(NSError * __autoreleasing *)error
{
    DSJSONSchemaValidationOptions *nonnullOptions = options ?: [[DSJSONSchemaValidationOptions alloc] init];
    if ([foundationObject isKindOfClass:[NSDictionary class]]) {
        return [DSJSONDictionarySchema schemaWithDictionary:foundationObject baseURI:baseURI referenceStorage:referenceStorage specification:specification options:nonnullOptions error:error];
    } else if (foundationObject != nil) {
        if (specification.version == DSJSONSchemaSpecificationVersionDraft4) {
            // schema object must be a dictionary for draft-04
            if (error != NULL) {
                *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:foundationObject];
            }
            return nil;
        }
        
        // is boolean schema
        if ([foundationObject isKindOfClass:NSNumber.class] && [foundationObject ds_isBoolean]) {
            return [DSJSONBooleanSchema schemaWithNumber:foundationObject baseURI:baseURI specification:specification options:nonnullOptions error:error];
        }
        else {
            if (error != NULL) {
                *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:foundationObject];
            }
            return nil;
        }
    } else {
        return nil;
    }
}

+ (nullable instancetype)schemaWithData:(NSData *)schemaData baseURI:(nullable NSURL *)baseURI referenceStorage:(nullable DSJSONSchemaStorage *)referenceStorage specification:(DSJSONSchemaSpecification *)specification options:(nullable DSJSONSchemaValidationOptions *)options error:(NSError * __autoreleasing *)error
{
    id object = [NSJSONSerialization JSONObjectWithData:schemaData options:(NSJSONReadingOptions)kNilOptions error:error];
    return [self schemaWithObject:object baseURI:baseURI referenceStorage:referenceStorage specification:specification options:options error:error];
}

- (BOOL)visitUsingBlock:(void (^)(DSJSONSchema *subschema, BOOL *stop))block
{
    NSParameterAssert(block);
    
    BOOL stop = NO;
    // visit self first
    block(self, &stop);
    if (stop) {
        return YES;
    }
    
    // visit subschemas in validators
    for (id<DSJSONSchemaValidator> validator in self.validators) {
        for (DSJSONSchema *subschema in [validator subschemas]) {
            stop = [subschema visitUsingBlock:block];
            if (stop) {
                return YES;
            }
        }
    }
    
    // visit unbound subschemas
    for (DSJSONSchema *subschema in self.subschemas) {
        stop = [subschema visitUsingBlock:block];
        if (stop) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)resolveReferencesWithSchemaStorage:(DSJSONSchemaStorage *)schemaStorage error:(NSError * __autoreleasing *)error
{
    __block NSError *internalError = nil;
    [self visitUsingBlock:^(DSJSONSchema *subschema, BOOL *stop) {
        // do not process normal schemas
        if ([subschema isKindOfClass:[DSJSONSchemaReference class]] == NO) {
            return;
        }
        
        DSJSONSchemaReference *referenceSubschema = (DSJSONSchemaReference *)subschema;
        // do not process already resolved references
        if (referenceSubschema.referencedSchema != nil) {
            return;
        }
        
        // try resolving the reference
        NSURL *referenceURI = referenceSubschema.referenceURI;
        DSJSONSchema *referencedSchema = [schemaStorage schemaForURI:referenceURI];
        if (referencedSchema != nil) {
            [referenceSubschema resolveReferenceWithSchema:referencedSchema];
        } else {
            internalError = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeUnresolvableSchemaReference failingObject:referenceURI];
            *stop = YES;
        }
    }];
    
    if (internalError == nil) {
        return YES;
    } else {
        if (error != NULL) {
            *error = internalError;
        }
        return NO;
    }
}

- (BOOL)detectReferenceCyclesWithError:(NSError * __autoreleasing *)error
{
    __block NSError *internalError = nil;
    [self visitUsingBlock:^(DSJSONSchema *subschema, BOOL *stop) {
        // do not process normal schemas
        if ([subschema isKindOfClass:[DSJSONSchemaReference class]] == NO) {
            return;
        }
        
        DSJSONSchemaReference *referencePointer = (DSJSONSchemaReference *)subschema;
        NSMutableSet<DSJSONSchemaReference *> *referenceChain = [NSMutableSet set];
        do {
            if ([referenceChain containsObject:referencePointer] == NO) {
                [referenceChain addObject:referencePointer];
                
                DSJSONSchema *referencedSchema = [referencePointer referencedSchema];
                NSAssert(referencedSchema != nil, @"Assuming all schema references are already resolved.");
                
                if ([referencedSchema isKindOfClass:[DSJSONSchemaReference class]]) {
                    referencePointer = (DSJSONSchemaReference *)referencedSchema;
                } else {
                    referencePointer = nil;
                }
            } else {
                internalError = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeReferenceCycle failingObject:referencePointer];
                *stop = YES;
                return;
            }
        } while (referencePointer != nil);
    }];
    
    if (internalError == nil) {
        return YES;
    } else {
        if (error != NULL) {
            *error = internalError;
        }
        return NO;
    }
}

#pragma mark - Schema validation

- (BOOL)validateObject:(id)object inContext:(nullable DSJSONSchemaValidationContext *)context error:(NSError * __autoreleasing *)error
{
    // create a validation context if necessary
    DSJSONSchemaValidationContext *validationContext = context ?: [[DSJSONSchemaValidationContext alloc] init];
    
    // try to register a new entry in the validation context
    BOOL success = [validationContext pushValidatedSchema:self object:object withError:error];
    if (success == NO) {
        return NO;
    }
    
    for (id<DSJSONSchemaValidator> validator in self.validators) {
        if ([validator validateInstance:object inContext:validationContext error:error] == NO) {
            success = NO;
            break;
        }
    }
    
    // unregister the current entry from the validation context
    [validationContext popValidatedSchemaAndObject];
    
    return success;
}

- (BOOL)validateObject:(id)object withError:(NSError *__autoreleasing *)error
{
    if (self.options.removeAdditional != DSJSONSchemaValidationOptionsRemoveAdditionalNone) {
        BOOL isMutable = [object isKindOfClass:NSMutableDictionary.class];
        NSAssert(isMutable, @"Using `removeAdditional` option is only allowed with mutable objects because this option could change object in place. Use `NSDictionary:ds_deepMutableCopy` helper");
        if (!isMutable) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:DSJSONSchemaErrorDomain
                                             code:-1
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Internal error: Invalid usage of `removeAdditional` option" }];
            }
            return NO;
        }
    }
    
    return [self validateObject:object inContext:nil error:error];
}

- (BOOL)validateObjectWithData:(NSData *)data error:(NSError * __autoreleasing *)error
{
    id object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:error];
    if (object != nil) {
        return [self validateObject:object withError:error];
    } else {
        return NO;
    }
}

#pragma mark - Validators registry

// maps metaschema URIs to dictionaries which, in turn, map string keywords to validator classes
static NSMutableDictionary<NSURL *, NSDictionary<NSString *, Class> *> *schemaKeywordsMapping;

+ (NSDictionary<NSString *, Class> *)validatorsMappingForMetaschemaURI:(NSURL *)metaschemaURI specification:(DSJSONSchemaSpecification *)specification
{
    // return nil for unsupported metaschemas
    if ([specification.unsupportedMetaschemaURIs containsObject:metaschemaURI]) {
        return nil;
    }
    
    // if not a standard supported supported metaschema URI, retrieve its custom keywords
    NSDictionary<NSString *, Class> *customKeywordsMapping = nil;
    if (metaschemaURI != nil && [specification.supportedMetaschemaURIs containsObject:metaschemaURI] == NO) {
        customKeywordsMapping = schemaKeywordsMapping[metaschemaURI];
    }
    
    // retrieve keywords mapping for standard metaschema and extend it with custom one if necessary
    NSDictionary<NSString *, Class> *effectiveKeywordsMapping = schemaKeywordsMapping[specification.defaultMetaschemaURI];
    if (customKeywordsMapping.count > 0) {
        NSMutableDictionary<NSString *, Class> *extendedMapping = [effectiveKeywordsMapping mutableCopy];
        [extendedMapping addEntriesFromDictionary:customKeywordsMapping];
        effectiveKeywordsMapping = extendedMapping;
    }
    
    return [effectiveKeywordsMapping copy];
}

+ (BOOL)registerValidatorClass:(Class<DSJSONSchemaValidator>)validatorClass forMetaschemaURI:(nullable NSURL *)metaschemaURI specification:(DSJSONSchemaSpecification *)specification withError:(NSError * __autoreleasing *)error
{
    // initialize the mapping dictionary if necessary
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        schemaKeywordsMapping = [NSMutableDictionary dictionary];
    });
    
    // fail for unsupported metaschemas
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
    if (metaschemaURI && [specification.unsupportedMetaschemaURIs containsObject:metaschemaURI]) {
#pragma clang diagnostic pop
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeIncompatibleMetaschema failingObject:metaschemaURI];
        }
        return NO;
    }
    
    // replace nil and any supported metaschema URI with default one
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
    if (metaschemaURI == nil || [specification.supportedMetaschemaURIs containsObject:metaschemaURI]) {
#pragma clang diagnostic pop
        metaschemaURI = specification.defaultMetaschemaURI;
    }
    NSURL *nonNullableMetaschemaURI = metaschemaURI;
    
    // retrieve keywords set for the validator class
    NSSet<NSString *> *keywords = [validatorClass assignedKeywords];
    // fail if validator does not define any keywords
    if (keywords.count == 0) {
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeNoValidatorKeywordsDefined failingObject:validatorClass];
        }
        return NO;
    }
    
    // check that the new validator does not define any keywords already defined by another validator in the same scope
    NSDictionary<NSString *, Class> *effectiveValidatorsMapping = [self validatorsMappingForMetaschemaURI:nonNullableMetaschemaURI specification:specification];
    if ([[NSSet setWithArray:effectiveValidatorsMapping.allKeys] intersectsSet:keywords]) {
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeValidatorKeywordAlreadyDefined failingObject:validatorClass];
        }
        return NO;
    }
    
    // finally, register the new keywords
    NSMutableDictionary<NSString *, Class> *mapping = [schemaKeywordsMapping[nonNullableMetaschemaURI] mutableCopy] ?: [NSMutableDictionary dictionary];
    for (NSString *keyword in keywords) {
        mapping[keyword] = validatorClass;
    }
    schemaKeywordsMapping[nonNullableMetaschemaURI] = [mapping copy];
    
    return YES;
}

@end
