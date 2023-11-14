//
//  DSJSONSchemaSpecification.m
//  DSJSONSchemaValidation
//
//  Created by Andrew Podkovyrin on 10/08/2018.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSJSONSchemaSpecification.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSJSONSchemaSpecification ()

@property (nonatomic, strong) NSURL *defaultMetaschemaURI;
@property (nonatomic, copy) NSSet<NSURL *> *supportedMetaschemaURIs;
@property (nonatomic, copy) NSSet<NSURL *> *unsupportedMetaschemaURIs;
@property (nonatomic, copy) NSSet<NSString *> *keywords;

@end

@implementation DSJSONSchemaSpecification

+ (instancetype)draft4
{
    return [[self alloc] initWithVersion:DSJSONSchemaSpecificationVersionDraft4];
}

+ (instancetype)draft6
{
    return [[self alloc] initWithVersion:DSJSONSchemaSpecificationVersionDraft6];
}

+ (instancetype)draft7
{
    return [[self alloc] initWithVersion:DSJSONSchemaSpecificationVersionDraft7];
}

- (instancetype)initWithVersion:(DSJSONSchemaSpecificationVersion)version
{
    self = [super init];
    if (self) {
        _version = version;
    }
    return self;
}

- (NSString *)idKeyword {
    switch (self.version) {
        case DSJSONSchemaSpecificationVersionDraft4:
            return @"id";
        case DSJSONSchemaSpecificationVersionDraft6:
        case DSJSONSchemaSpecificationVersionDraft7:
            return @"$id";
    }
}

- (NSURL *)defaultMetaschemaURI
{
    if (!_defaultMetaschemaURI) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
        switch (self.version) {
            case DSJSONSchemaSpecificationVersionDraft4: {
                _defaultMetaschemaURI = [NSURL URLWithString:@"http://json-schema.org/draft-04/schema#"];
                break;
            }   
            case DSJSONSchemaSpecificationVersionDraft6: {
                _defaultMetaschemaURI = [NSURL URLWithString:@"http://json-schema.org/draft-06/schema#"];
                break;
            }
            case DSJSONSchemaSpecificationVersionDraft7: {
                _defaultMetaschemaURI = [NSURL URLWithString:@"http://json-schema.org/draft-07/schema#"];
                break;
            }
        }
#pragma clang diagnostic pop
    }
    return _defaultMetaschemaURI;
}

- (NSSet<NSURL *> *)supportedMetaschemaURIs
{
    if (!_supportedMetaschemaURIs) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
        _supportedMetaschemaURIs = [NSSet setWithObjects:
                                    self.defaultMetaschemaURI,
                                    [NSURL URLWithString:@"http://json-schema.org/schema#"],
                                    nil];
#pragma clang diagnostic pop
    }
    return _supportedMetaschemaURIs;
}

- (NSSet<NSURL *> *)unsupportedMetaschemaURIs
{
    if (!_unsupportedMetaschemaURIs) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
        _unsupportedMetaschemaURIs = [NSSet setWithObjects:
                                      [NSURL URLWithString:@"http://json-schema.org/hyper-schema#"],
                                      [NSURL URLWithString:@"http://json-schema.org/draft-04/hyper-schema#"],
                                      [NSURL URLWithString:@"http://json-schema.org/draft-03/schema#"],
                                      [NSURL URLWithString:@"http://json-schema.org/draft-03/hyper-schema#"],
                                      nil];
#pragma clang diagnostic pop
    }
    return _unsupportedMetaschemaURIs;
}

- (NSSet<NSString *> *)keywords {
    if (!_keywords) {
        switch (self.version) {
            case DSJSONSchemaSpecificationVersionDraft4: {
                _keywords = [NSSet setWithArray:[self.class draft4Keywords]];
                break;
            }
            case DSJSONSchemaSpecificationVersionDraft6: {
                _keywords = [NSSet setWithArray:[self.class draft6Keywords]];
                break;
            }
            case DSJSONSchemaSpecificationVersionDraft7: {
                _keywords = [NSSet setWithArray:[self.class draft7Keywords]];
                break;
            }
        }
    }
    return _keywords;
}

+ (NSArray<NSString *> *)draft4Keywords {
    return @[
        // object keywords
        @"properties",
        @"required",
        @"minProperties",
        @"maxProperties",
        @"dependencies",
        @"patternProperties",
        @"additionalProperties",
        // array keywords
        @"items",
        @"additionalItems",
        @"minItems",
        @"maxItems",
        @"uniqueItems",
    ];
}

+ (NSArray<NSString *> *)draft6Keywords {
    NSMutableArray *draft6Keywords = [[self draft4Keywords] mutableCopy];
    [draft6Keywords addObjectsFromArray:@[
        // object keywords
        @"propertyNames",
        // array keywords
        @"contains",
    ]];
    return [draft6Keywords copy];
}

+ (NSArray<NSString *> *)draft7Keywords {
    NSMutableArray *draft7Keywords = [[self draft6Keywords] mutableCopy];
    [draft7Keywords addObjectsFromArray:@[
        // object keywords
        @"if",
        @"then",
        @"else",
    ]];
    return [draft7Keywords copy];
}

@end

NS_ASSUME_NONNULL_END
