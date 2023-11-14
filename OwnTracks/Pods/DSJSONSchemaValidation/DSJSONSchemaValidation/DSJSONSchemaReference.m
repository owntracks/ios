//
//  DSJSONSchemaReference.m
//  DSJSONSchemaValidation
//
//  Created by Vlas Voloshin on 28/12/2014.
//  Copyright (c) 2015 Vlas Voloshin. All rights reserved.
//

#import "DSJSONSchemaReference.h"

@implementation DSJSONSchemaReference

- (instancetype)initWithScopeURI:(NSURL *)uri referenceURI:(NSURL *)referenceURI subschemas:(nullable NSArray<DSJSONSchema *> *)subschemas specification:(DSJSONSchemaSpecification *)specification options:(DSJSONSchemaValidationOptions *)options
{
    NSParameterAssert(uri);
    NSParameterAssert(referenceURI);
    
    self = [super initWithScopeURI:uri title:nil description:nil validators:nil subschemas:subschemas specification:specification options:options];
    if (self) {
        _referenceURI = referenceURI;
    }
    
    return self;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"{ referencing %@ }", self.referencedSchema ?: self.referenceURI];
}

- (BOOL)validateObject:(id)object inContext:(DSJSONSchemaValidationContext *)context error:(NSError *__autoreleasing *)error
{
    DSJSONSchema *referencedSchema = self.referencedSchema;
    if (referencedSchema != nil) {
        return [referencedSchema validateObject:object inContext:context error:error];
    } else {
        [NSException raise:NSInternalInconsistencyException format:@"Can't validate an object using an unresolved schema reference."];
        return NO;
    }
}

- (void)resolveReferenceWithSchema:(DSJSONSchema *)schema
{
    if (_referencedSchema != nil) {
        [NSException raise:NSInternalInconsistencyException format:@"Attempted to resolve already resolved schema reference."];
        return;
    }
    
    _referencedSchema = schema;
}

@end
