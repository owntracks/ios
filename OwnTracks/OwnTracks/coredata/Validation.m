//
//  Validation.m
//  OwnTracks
//
//  Created by Christoph Krey on 13.11.23.
//  Copyright © 2023 OwnTracks. All rights reserved.
//

#import "Validation.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <DSJSONSchemaValidation/DSJSONSchema.h>

@implementation Validation
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
static Validation *theInstance = nil;

static DSJSONSchema *normalSchema = nil;
static DSJSONSchema *arraySchema = nil;
static DSJSONSchema *encryptedSchema = nil;

+ (Validation *)sharedInstance {
    if (theInstance == nil) {
        theInstance = [[Validation alloc] init];
    }
    return theInstance;
}

- (instancetype)init {
    self = [super init];
    NSURL *normalSchemaURL = [[NSBundle mainBundle] URLForResource:@"JsonSchema"
                                                     withExtension:@"json"];
    NSData *normalSchemaData = [NSData dataWithContentsOfURL:normalSchemaURL];
    NSError *normalSchemaError = nil;
    normalSchema = [DSJSONSchema schemaWithData:normalSchemaData
                                        baseURI:nil
                               referenceStorage:nil
                                  specification:[DSJSONSchemaSpecification draft7]
                                        options:nil
                                          error:&normalSchemaError];
    if (!normalSchema) {
        DDLogError(@"Validation schema creation error: %@",
                   normalSchemaError);
    }
    
    NSURL *arraySchemaURL = [[NSBundle mainBundle] URLForResource:@"ArraySchema"
                                                    withExtension:@"json"];
    NSData *arraySchemaData = [NSData dataWithContentsOfURL:arraySchemaURL];
    NSError *arraySchemaError = nil;
    arraySchema = [DSJSONSchema schemaWithData:arraySchemaData
                                       baseURI:nil
                              referenceStorage:[DSJSONSchemaStorage storageWithSchema:normalSchema]
                                 specification:[DSJSONSchemaSpecification draft7]
                                       options:nil
                                         error:&arraySchemaError];
    if (!arraySchema) {
        DDLogError(@"Validation schema creation error: %@",
                   arraySchemaError);
    }
    
    NSURL *encryptedSchemaURL = [[NSBundle mainBundle] URLForResource:@"EncryptedSchema"
                                                        withExtension:@"json"];
    NSData *encryptedSchemaData = [NSData dataWithContentsOfURL:encryptedSchemaURL];
    NSError *encryptedSchemaError = nil;
    encryptedSchema = [DSJSONSchema schemaWithData:encryptedSchemaData
                                           baseURI:nil
                                  referenceStorage:nil
                                     specification:[DSJSONSchemaSpecification draft7]
                                           options:nil
                                             error:&encryptedSchemaError];
    if (!encryptedSchema) {
        DDLogError(@"Validation encrypted schema creation error: %@",
                   encryptedSchemaError);
    }
    
    return self;
}

- (id)validateData:(NSData *)data {
    return [self validateData:data againstSchema:normalSchema];
}

- (id)validateArrayData:(NSData *)data {
    return [self validateData:data againstSchema:arraySchema];
}

- (id)validateEncryptedData:(NSData *)data {
    return [self validateData:data againstSchema:encryptedSchema];
}

- (id)validateData:(NSData *)data againstSchema:(DSJSONSchema *)schema {
    id json = nil;
    if (schema) {
        NSError *validationError = nil;
        if ([schema validateObjectWithData:data
                                     error:&validationError]) {
            json = [NSJSONSerialization JSONObjectWithData:data
                                                   options:0
                                                     error:nil];
            if (json) {
                NSData *jsonData = 
                [NSJSONSerialization dataWithJSONObject:json
                                                options:NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted
                                                  error:nil];
                DDLogDebug(@"Validation JSON: %@",
                           [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
            }
        } else {
            DDLogError(@"Validation error: %@",
                       validationError);
        }
    }
    return json;
}

- (BOOL)validateJson:(id)json {
    BOOL success = TRUE;
    if (normalSchema) {
        NSError *validationError = nil;
        success = [normalSchema validateObject:json
                                     withError:&validationError];
        if (!success) {
            DDLogError(@"Validation error: %@",
                       validationError);
        }
    }
    return success;
}

@end
