//
//  DSJSONSchema+Protected.h
//  DSJSONSchemaValidation
//
//  Created by Andrew Podkovyrin on 11/08/2018.
//  Copyright © 2018 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchema.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSJSONSchema ()

- (BOOL)resolveReferencesWithSchemaStorage:(DSJSONSchemaStorage *)schemaStorage error:(NSError * __autoreleasing *)error;
- (BOOL)detectReferenceCyclesWithError:(NSError * __autoreleasing *)error;

+ (NSDictionary<NSString *, Class> *)validatorsMappingForMetaschemaURI:(NSURL *)metaschemaURI specification:(DSJSONSchemaSpecification *)specification;

@end

NS_ASSUME_NONNULL_END
