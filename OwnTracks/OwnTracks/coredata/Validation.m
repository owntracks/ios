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

static DSJSONSchema *messageSchema = nil;
static DSJSONSchema *messagesSchema = nil;
static DSJSONSchema *encryptionSchema = nil;

+ (Validation *)sharedInstance {
    if (theInstance == nil) {
        theInstance = [[Validation alloc] init];
    }
    return theInstance;
}

- (instancetype)init {
    self = [super init];
    NSURL *messageSchemaURL = [[NSBundle mainBundle] URLForResource:@"message"
                                                      withExtension:@"json"];
    NSURL *messageSchemaBaseURL = [NSURL URLWithString:@"https://owntracks.org/schemas/message.json"];
    NSData *messageSchemaData = [NSData dataWithContentsOfURL:messageSchemaURL];
    NSError *messageSchemaError = nil;
    messageSchema = [DSJSONSchema schemaWithData:messageSchemaData
                                         baseURI:messageSchemaBaseURL
                                referenceStorage:nil
                                   specification:[DSJSONSchemaSpecification draft7]
                                         options:nil
                                           error:&messageSchemaError];
    if (!messageSchema) {
        DDLogError(@"Validation message schema creation error: %@",
                   messageSchemaError);
    }
    
    NSURL *messagesSchemaURL = [[NSBundle mainBundle] URLForResource:@"messages"
                                                       withExtension:@"json"];
    NSURL *messagesSchemaBaseURL = [NSURL URLWithString:@"https://owntracks.org/schemas/messages.json"];
    NSData *messagesSchemaData = [NSData dataWithContentsOfURL:messagesSchemaURL];
    NSError *messagesSchemaError = nil;
    messagesSchema = [DSJSONSchema schemaWithData:messagesSchemaData
                                          baseURI:messagesSchemaBaseURL
                                 referenceStorage:[DSJSONSchemaStorage storageWithSchema:messageSchema]
                                    specification:[DSJSONSchemaSpecification draft7]
                                          options:nil
                                            error:&messagesSchemaError];
    if (!messagesSchema) {
        DDLogError(@"Validation messages schema creation error: %@",
                   messagesSchemaError);
    }
    
    NSURL *encryptionSchemaURL = [[NSBundle mainBundle] URLForResource:@"encryption"
                                                         withExtension:@"json"];
    NSURL *encryptionSchemaBaseURL = [NSURL URLWithString:@"https://owntracks.org/schemas/encryption.json"];
    NSData *encryptionSchemaData = [NSData dataWithContentsOfURL:encryptionSchemaURL];
    NSError *encryptionSchemaError = nil;
    encryptionSchema = [DSJSONSchema schemaWithData:encryptionSchemaData
                                            baseURI:encryptionSchemaBaseURL
                                   referenceStorage:nil
                                      specification:[DSJSONSchemaSpecification draft7]
                                            options:nil
                                              error:&encryptionSchemaError];
    if (!encryptionSchema) {
        DDLogError(@"Validation encryption schema creation error: %@",
                   encryptionSchemaError);
    }
    
    return self;
}

- (id)validateMessageData:(NSData *)data {
    return [self validateData:data againstSchema:messageSchema];
}

- (id)validateMessagesData:(NSData *)data {
    return [self validateData:data againstSchema:messagesSchema];
}

- (id)validateEncryptionData:(NSData *)data {
    return [self validateData:data againstSchema:encryptionSchema];
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
            json = [NSJSONSerialization JSONObjectWithData:data
                                                   options:0
                                                     error:nil];
            NSData *jsonData =
            [NSJSONSerialization dataWithJSONObject:json
                                            options:NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted
                                              error:nil];
            DDLogError(@"Validation error: %@ with %@",
                       validationError,
                       [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
        }
    } else {
        json = [NSJSONSerialization JSONObjectWithData:data
                                               options:0
                                                 error:nil];
        NSData *jsonData =
        [NSJSONSerialization dataWithJSONObject:json
                                        options:NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted
                                          error:nil];
        DDLogVerbose(@"Not validated: %@",
                     [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
        
    }
    
    return json;
}

@end
