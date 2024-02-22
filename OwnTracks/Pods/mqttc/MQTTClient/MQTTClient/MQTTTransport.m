//
//  MQTTTransport.m
//  MQTTClient
//
//  Created by Christoph Krey on 05.01.16.
//  Copyright © 2016-2022 Christoph Krey. All rights reserved.
//

#import <mqttc/MQTTTransport.h>

#import <mqttc/MQTTLog.h>

@implementation MQTTTransport
@synthesize state;
@synthesize runLoop;
@synthesize runLoopMode;
@synthesize delegate;
@synthesize host;
@synthesize port;
@synthesize allowUntrustedCertificates;
@synthesize certificates;
@synthesize tls;

- (instancetype)init {
    self = [super init];
    self.state = MQTTTransportCreated;
    self.runLoop = [NSRunLoop currentRunLoop];
    self.runLoopMode = NSRunLoopCommonModes;
    self.host = @"localhost";
    self.port = 1883;
    self.tls = false;
    self.allowUntrustedCertificates = false;
    self.certificates = nil;

    return self;
}

- (void)open {
    DDLogError(@"MQTTTransport is abstract class");
}

- (void)close {
    DDLogError(@"MQTTTransport is abstract class");
}

- (BOOL)send:(NSData *)data {
    DDLogError(@"MQTTTransport is abstract class");
    return FALSE;
}

+ (NSArray *)clientCertsFromP12:(NSString *)path passphrase:(NSString *)passphrase {
    if (!path) {
        DDLogWarn(@"[MQTTTransport] no p12 path given");
        return nil;
    }

    NSData *pkcs12data = [[NSData alloc] initWithContentsOfFile:path];
    if (!pkcs12data) {
        DDLogWarn(@"[MQTTTransport] reading p12 failed");
        return nil;
    }

    if (!passphrase) {
        DDLogWarn(@"[MQTTTransport] no passphrase given");
        return nil;
    }
    CFArrayRef keyref = NULL;
    OSStatus importStatus = SecPKCS12Import((__bridge CFDataRef)pkcs12data,
                                            (__bridge CFDictionaryRef)@{(__bridge id)kSecImportExportPassphrase: passphrase},
                                            &keyref);
    if (importStatus != noErr) {
        DDLogWarn(@"[MQTTTransport] Error while importing pkcs12 [%d]", (int)importStatus);
        return nil;
    }

    CFDictionaryRef identityDict = CFArrayGetValueAtIndex(keyref, 0);
    if (!identityDict) {
        DDLogWarn(@"[MQTTTransport] could not CFArrayGetValueAtIndex");
        return nil;
    }

    SecIdentityRef identityRef = (SecIdentityRef)CFDictionaryGetValue(identityDict,
                                                                      kSecImportItemIdentity);
    if (!identityRef) {
        DDLogWarn(@"[MQTTTransport] could not CFDictionaryGetValue");
        return nil;
    };

    SecCertificateRef cert = NULL;
    OSStatus status = SecIdentityCopyCertificate(identityRef, &cert);
    if (status != noErr) {
        DDLogWarn(@"[MQTTTransport] SecIdentityCopyCertificate failed [%d]", (int)status);
        return nil;
    }

    NSArray *clientCerts = @[(__bridge id)identityRef, (__bridge id)cert];
    return clientCerts;
}

@end
