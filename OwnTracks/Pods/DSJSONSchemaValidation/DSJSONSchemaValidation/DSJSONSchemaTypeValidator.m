//
//  DSJSONSchemaTypeValidator.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 30/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchemaTypeValidator.h"
#import "DSJSONSchemaErrors.h"
#import "DSJSONSchemaFactory.h"
#import "NSNumber+DSJSONNumberTypes.h"

DSJSONSchemaInstanceTypes DSJSONSchemaInstanceTypeFromString(NSString *string);
NSString *NSStringFromDSJSONSchemaInstanceTypes(DSJSONSchemaInstanceTypes types);

@interface DSJSONSchemaTypeValidator ()

@property (nonatomic, strong) DSJSONSchemaSpecification *specification;

@end

@implementation DSJSONSchemaTypeValidator

static NSString * const kSchemaKeywordType = @"type";

- (instancetype)initWithTypes:(DSJSONSchemaInstanceTypes)types specification:(DSJSONSchemaSpecification *)specification
{
    self = [super init];
    if (self) {
        _types = types;
        _specification = specification;
    }
    
    return self;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"{ allowed types: %@ }", NSStringFromDSJSONSchemaInstanceTypes(self.types)];
}

+ (NSSet<NSString *> *)assignedKeywords
{
    return [NSSet setWithObject:kSchemaKeywordType];
}

+ (instancetype)validatorWithDictionary:(NSDictionary<NSString *, id> *)schemaDictionary schemaFactory:(DSJSONSchemaFactory *)schemaFactory error:(NSError * __autoreleasing *)error
{
    id typesObject = schemaDictionary[kSchemaKeywordType];
    
    DSJSONSchemaInstanceTypes types = DSJSONSchemaInstanceTypesNone;
    if ([typesObject isKindOfClass:[NSString class]]) {
        // parse type instance either as a string...
        types = DSJSONSchemaInstanceTypeFromString(typesObject);
    } else if ([typesObject isKindOfClass:[NSArray class]]) {
        // ... or as an array
        for (id typeObject in typesObject) {
            DSJSONSchemaInstanceTypes type = DSJSONSchemaInstanceTypesNone;
            if ([typeObject isKindOfClass:[NSString class]]) {
                type = DSJSONSchemaInstanceTypeFromString(typeObject);
            }
            
            if (type != DSJSONSchemaInstanceTypesNone && (types & type) == 0) {
                types |= type;
            } else {
                // fail if invalid instance is encountered or there is a duplicate type
                types = DSJSONSchemaInstanceTypesNone;
                break;
            }
        }
    }
    
    if (types != DSJSONSchemaInstanceTypesNone) {
        return [[self alloc] initWithTypes:types specification:schemaFactory.specification];
    } else {
        if (error != NULL) {
            *error = [NSError vv_JSONSchemaErrorWithCode:DSJSONSchemaErrorCodeInvalidSchemaFormat failingObject:schemaDictionary];
        }
        return nil;
    }
}

- (NSArray<DSJSONSchema *> *)subschemas
{
    return nil;
}

- (BOOL)validateInstance:(id)instance inContext:(DSJSONSchemaValidationContext *)context error:(NSError *__autoreleasing *)error
{
    DSJSONSchemaInstanceTypes types = self.types;
    if ((types & DSJSONSchemaInstanceTypesObject) != 0 && [instance isKindOfClass:[NSDictionary class]]) {
        return YES;
    }
    if ((types & DSJSONSchemaInstanceTypesArray) != 0 && [instance isKindOfClass:[NSArray class]]) {
        return YES;
    }
    if ((types & DSJSONSchemaInstanceTypesString) != 0 && [instance isKindOfClass:[NSString class]]) {
        return YES;
    }
    if ((types & DSJSONSchemaInstanceTypesInteger) != 0 && [instance isKindOfClass:[NSNumber class]]) {
        if ([instance ds_isInteger]) {
            return YES;
        }
        if ((self.specification.version == DSJSONSchemaSpecificationVersionDraft6 ||
             self.specification.version == DSJSONSchemaSpecificationVersionDraft7) &&
            [instance ds_isFloat]) {
            // "a float without fractional part is an integer"
            double doubleValue = [instance doubleValue];
            double fractionalPart = fmod(doubleValue, 1.0);
            if (fractionalPart == 0.0) {
                return YES;
            }
        }
    }
    if ((types & DSJSONSchemaInstanceTypesNumber) != 0 && [instance isKindOfClass:[NSNumber class]] && [instance ds_isBoolean] == NO) {
        return YES;
    }
    if ((types & DSJSONSchemaInstanceTypesBoolean) != 0 && [instance isKindOfClass:[NSNumber class]] && [instance ds_isBoolean]) {
        return YES;
    }
    if ((types & DSJSONSchemaInstanceTypesNull) != 0 && instance == [NSNull null]) {
        return YES;
    }
    
    if (error != NULL) {
        NSString *failureReason = @"Object type is not allowed.";
        *error = [NSError vv_JSONSchemaValidationErrorWithFailingValidator:self reason:failureReason context:context];
    }
    return NO;
}

@end

DSJSONSchemaInstanceTypes DSJSONSchemaInstanceTypeFromString(NSString *string)
{
    static NSDictionary<NSString *, NSNumber *> *mapping;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mapping = @{ @"object" : @(DSJSONSchemaInstanceTypesObject), @"array" : @(DSJSONSchemaInstanceTypesArray), @"string" : @(DSJSONSchemaInstanceTypesString), @"integer" : @(DSJSONSchemaInstanceTypesInteger), @"number" : @(DSJSONSchemaInstanceTypesNumber), @"boolean" : @(DSJSONSchemaInstanceTypesBoolean), @"null" : @(DSJSONSchemaInstanceTypesNull) };
    });
    
    NSNumber *typeNumber = mapping[string];
    if (typeNumber != nil) {
        return [typeNumber unsignedIntegerValue];
    } else {
        return DSJSONSchemaInstanceTypesNone;
    }
}

NSString *NSStringFromDSJSONSchemaInstanceTypes(DSJSONSchemaInstanceTypes types)
{
    if (types == DSJSONSchemaInstanceTypesNone) {
        return @"none";
    }
    
    NSMutableArray<NSString *> *typeStrings = [NSMutableArray array];
    if (types & DSJSONSchemaInstanceTypesObject) {
        [typeStrings addObject:@"object"];
    }
    if (types & DSJSONSchemaInstanceTypesArray) {
        [typeStrings addObject:@"array"];
    }
    if (types & DSJSONSchemaInstanceTypesString) {
        [typeStrings addObject:@"string"];
    }
    if (types & DSJSONSchemaInstanceTypesInteger) {
        [typeStrings addObject:@"integer"];
    }
    if (types & DSJSONSchemaInstanceTypesNumber) {
        [typeStrings addObject:@"number"];
    }
    if (types & DSJSONSchemaInstanceTypesBoolean) {
        [typeStrings addObject:@"boolean"];
    }
    if (types & DSJSONSchemaInstanceTypesNull) {
        [typeStrings addObject:@"null"];
    }
    
    return [typeStrings componentsJoinedByString:@", "];
}
