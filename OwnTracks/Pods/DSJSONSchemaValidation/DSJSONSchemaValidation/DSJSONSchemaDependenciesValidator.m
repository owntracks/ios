//
//  DSJSONSchemaDependenciesValidator.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 1/01/2015.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchemaDependenciesValidator.h"
#import "DSJSONSchema.h"
#import "DSJSONSchemaFactory.h"
#import "DSJSONSchemaErrors.h"
#import "NSNumber+DSJSONNumberTypes.h"
#import "DSJSONBooleanSchema.h"

@implementation DSJSONSchemaDependenciesValidator

static NSString * const kSchemaKeywordDependencies = @"dependencies";

- (instancetype)initWithSchemaDependencies:(NSDictionary<NSString *, DSJSONSchema *> *)schemaDependencies propertyDependencies:(NSDictionary<NSString *, NSSet<NSString *> *> *)propertyDependencies
{
    self = [super init];
    if (self) {
        _schemaDependencies = [schemaDependencies copy];
        _propertyDependencies = [propertyDependencies copy];
    }
    
    return self;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"{ %lu schema dependencies; %lu property dependencies }", (unsigned long)self.schemaDependencies.count, (unsigned long)self.propertyDependencies.count];
}

+ (NSSet<NSString *> *)assignedKeywords
{
    return [NSSet setWithObject:kSchemaKeywordDependencies];
}

+ (instancetype)validatorWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary schemaFactory:(DSJSONSchemaFactory *)schemaFactory error:(NSError * __autoreleasing *)error
{
    id dependencies = schemaDictionary[kSchemaKeywordDependencies];
    
    // dependencies must be a dictionary
    if ([dependencies isKindOfClass:[NSDictionary class]] == NO) {
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaDictionary];
        }
        return nil;
    }
    
    NSMutableDictionary<NSString *, DSJSONSchema *> *schemaDependencies = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSSet<NSString *> *> *propertyDependencies = [NSMutableDictionary dictionary];
    
    // parse the dependencies
    __block BOOL success = YES;
    __block NSError *internalError = nil;
    [dependencies enumerateKeysAndObjectsUsingBlock:^(NSString *propertyName, id dependencyObject, BOOL *stop) {
        if ([dependencyObject isKindOfClass:[NSDictionary class]] ||
            [dependencyObject isKindOfClass:[NSNumber class]]) {
            // dependency object is a dictionary or boolean - parse it as a schema dependency;
            // schema will have scope extended by "/dependencies/#" where # is dependent property name
            DSJSONSchemaFactory *dependencySchemaFactory = [schemaFactory factoryByAppendingScopeComponentsFromArray:@[ kSchemaKeywordDependencies, propertyName ]];
            
            DSJSONSchema *dependencySchema = [dependencySchemaFactory schemaWithObject:dependencyObject error:&internalError];
            if (dependencySchema != nil) {
                schemaDependencies[propertyName] = dependencySchema;
            } else {
                *stop = YES;
                success = NO;
            }
        } else if ([dependencyObject isKindOfClass:[NSArray class]]) {
            if (schemaFactory.specification.version == DSJSONSchemaSpecificationVersionDraft6 ||
                schemaFactory.specification.version == DSJSONSchemaSpecificationVersionDraft7) {
                if (((NSArray *)dependencyObject).count == 0) {
                    *stop = YES;
                    success = YES;
                    return;
                }
            }
            
            // dependency object is an array - parse it as a property dependency;
            // each property names array must be non-empty and contain unique strings
            for (id dependentProperty in dependencyObject) {
                if ([dependentProperty isKindOfClass:[NSString class]] == NO) {
                    *stop = YES;
                    success = NO;
                    return;
                }
            }
            
            NSSet<NSString *> *dependentPropertiesSet = [NSSet setWithArray:dependencyObject];
            if (dependentPropertiesSet.count == 0 || dependentPropertiesSet.count != [dependencyObject count]) {
                *stop = YES;
                success = NO;
                return;
            }
            
            propertyDependencies[propertyName] = dependentPropertiesSet;
        } else {
            // invalid dependency object
            *stop = YES;
            success = NO;
        }
    }];
    
    if (success) {
        return [[self alloc] initWithSchemaDependencies:schemaDependencies propertyDependencies:propertyDependencies];
    } else {
        if (error != NULL) {
            *error = internalError ?: [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaDictionary];
        }
        return nil;
    }
}

- (NSArray<DSJSONSchema *> *)subschemas
{
    return self.schemaDependencies.allValues;
}

- (BOOL)validateInstance:(id)instance inContext:(DSJSONSchemaValidationContext *)context error:(NSError *__autoreleasing *)error
{
    // silently succeed if value of the instance is inapplicable
    if ([instance isKindOfClass:[NSDictionary class]] == NO) {
        return YES;
    }
    
    NSSet<NSString *> *propertyNames = [NSSet setWithArray:[instance allKeys]];
    __block BOOL success = YES;
    __block NSString *failingProperty;

    // validate property dependencies
    [self.propertyDependencies enumerateKeysAndObjectsUsingBlock:^(NSString *property, NSSet<NSString *> *dependingProperties, BOOL *stop) {
        if ([propertyNames containsObject:property]) {
            if ([dependingProperties isSubsetOfSet:propertyNames] == NO) {
                failingProperty = property;
                success = NO;
                *stop = YES;
            }
        }
    }];
    if (success == NO) {
        if (error != NULL) {
            NSMutableSet<NSString *> *missingProperties = [self.propertyDependencies[failingProperty] mutableCopy];
            [missingProperties minusSet:propertyNames];
            NSString *missingPropertiesList = [[missingProperties allObjects] componentsJoinedByString:@", "];
            NSString *failureReason = [NSString stringWithFormat:@"Object is missing properties '%@' as required by property '%@'.", missingPropertiesList, failingProperty];
            *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
        }
        return NO;
    }
    
    // validate schema dependencies
    __block NSError *internalError;
    [self.schemaDependencies enumerateKeysAndObjectsUsingBlock:^(NSString *property, DSJSONSchema *schema, BOOL *stop) {
        if ([propertyNames containsObject:property]) {
            if ([schema validateObject:instance inContext:context error:&internalError] == NO) {
                success = NO;
                *stop = YES;
            }
        }
    }];
    if (success == NO) {
        if (error != NULL) {
            *error = internalError;
        }
    }
    
    return success;
}

@end
