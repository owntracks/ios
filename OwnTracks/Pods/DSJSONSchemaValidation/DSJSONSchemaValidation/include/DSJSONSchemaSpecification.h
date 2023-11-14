//
//  DSJSONSchemaSpecification.h
//  DSJSONSchemaValidation
//
//  Created by Andrew Podkovyrin on 10/08/2018.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DSJSONSchemaSpecificationVersion) {
    DSJSONSchemaSpecificationVersionDraft4,
    DSJSONSchemaSpecificationVersionDraft6,
    DSJSONSchemaSpecificationVersionDraft7,
};

/**
 Defines an object with schema specification version. 
 */
@interface DSJSONSchemaSpecification : NSObject

/** Specification version value. */
@property (nonatomic, readonly, assign) DSJSONSchemaSpecificationVersion version;
/** ID Schema Keyword ('id' for draft 4 or '$id' for draft 6 / 7). */
@property (nonatomic, readonly, copy) NSString *idKeyword;
@property (nonatomic, readonly, strong) NSURL *defaultMetaschemaURI;
@property (nonatomic, readonly, copy) NSSet<NSURL *> *supportedMetaschemaURIs;
@property (nonatomic, readonly, copy) NSSet<NSURL *> *unsupportedMetaschemaURIs;
/** Set of object and array schema keywords. */
@property (nonatomic, readonly, copy) NSSet<NSString *> *keywords;

/** Creates JSON Schema draft 4 configuration object. */
+ (instancetype)draft4;
/** Creates JSON Schema draft 6 configuration object. */
+ (instancetype)draft6;
/** Creates JSON Schema draft 7 configuration object. */
+ (instancetype)draft7;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
