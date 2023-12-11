//
//  DSJSONSchemaFactory.h
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 29/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSJSONSchemaSpecification.h"
#import "DSJSONSchemaValidationOptions.h"

NS_ASSUME_NONNULL_BEGIN

@class DSJSONSchema;

/**
 Defines an object capable of creating schema and validator instances.
 @discussion This class is used by the implementation of the schema and validator classes. Schema instantiation process starts by creating a root factory object, configured with the keywords mapping and base scope URI. This factory is then used to create the root schema and instantiate its validators. Validators receive a factory and use it to generate sub-factories for instantiating nested schemas.
 */
@interface DSJSONSchemaFactory : NSObject

/** Resolution scope URI of the receiver. */
@property (nonatomic, readonly, strong) NSURL *scopeURI;
/** Keywords mapping used to create validators for the schema. */
@property (nonatomic, readonly, copy) NSDictionary<NSString *, Class> *keywordsMapping;
/** Schema specification version. */
@property (nonatomic, readonly, strong) DSJSONSchemaSpecification *specification;
/** Schema validation options. */
@property (nonatomic, readonly, strong) DSJSONSchemaValidationOptions *options;

/**
 Creates a root factory object with specified base resolution scope URI and keywords mapping.
 @param scopeURI Base resolution scope URI of the factory.
 @param keywordsMapping Keyword to validator class mapping to be used for the schemas created using the factory and its derived factories.
 @param specification Schema specification version. Serves as a configuration for validation process.
 @param options Schema validation options. Different options that allows to change default behaviour of the validator classes.
 @discussion This method is invoked by the root schema instantiation process, you don't need to invoke it yourself.
 */
+ (instancetype)factoryWithScopeURI:(NSURL *)scopeURI keywordsMapping:(NSDictionary<NSString *, Class> *)keywordsMapping specification:(DSJSONSchemaSpecification *)specification options:(DSJSONSchemaValidationOptions *)options;

/**
 Creates and returns a new factory object with the specified resolution scope and the same keywords mapping as the receiver.
 @param scopeURI Resolution scope URI for the created factory.
 @return Created factory object.
 */
- (instancetype)factoryByReplacingScopeURI:(NSURL *)scopeURI;
/**
 Creates and returns a new factory object with an appended resolution scope and the same keywords mapping as the receiver.
 @discussion Resolution scope path will be extended by the specified fragment component.
 @param scopeComponent Scope path fragment appended to the scope path of the receiver.
 */
- (instancetype)factoryByAppendingScopeComponent:(NSString *)scopeComponent;
/**
 Creates and returns a new factory object with an appended resolution scope and the same keywords mapping as the receiver.
 @discussion Resolution scope path will be extended by the specified fragment components.
 @param scopeComponentsArray Array of scope path fragments appended to the scope path of the receiver.
 */
- (instancetype)factoryByAppendingScopeComponentsFromArray:(NSArray<NSString *> *)scopeComponentsArray;

/**
 Returns a schema configured using the contents of specified JSON dictionary.
 @discussion Note that returned schema may have a different resolution scope URI than the value of `scopeURI` property, if that schema alters its scope with an "id" property.
 @param foundationObject Foundation object containing the JSON Schema representation.
 @param error Error object to contain any error encountered during schema instantiation.
 @return Configured schema instance, or nil if an error occurred.
 */
- (nullable DSJSONSchema *)schemaWithObject:(id)foundationObject error:(NSError * __autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
