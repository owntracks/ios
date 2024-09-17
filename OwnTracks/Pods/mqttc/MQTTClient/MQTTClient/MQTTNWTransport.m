//
//  MQTTNWTransport.m
//  MQTTClient
//
//  Created by Christoph Krey on 01.10.19.
//  Copyright © 2019-2022 Christoph Krey. All rights reserved.
//

#import <mqttc/MQTTNWTransport.h>
#import <mqttc/MQTTLog.h>
#import <os/availability.h>

API_AVAILABLE(ios(13.0), macos(10.15))
@interface MQTTNWTransport ()
@property (strong, nonatomic) NSURLSession *session;
@property (strong, nonatomic) NSURLSessionStreamTask *streamTask;
@property (strong, nonatomic) NSURLSessionWebSocketTask *webSocketTask;
@end

@implementation MQTTNWTransport

- (instancetype)init {
    self = [super init];
    self.ws = false;

    return self;
}


- (void)open {
    DDLogVerbose(@"[MQTTNWTransport] session");

#define EPHEMERAL 1
#ifdef EPHEMERAL
    self.session =
    [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]
                                  delegate:self
                             delegateQueue:nil];
#else
    self.session =
    [NSURLSession sharedSession];
#endif

    DDLogVerbose(@"[MQTTNWTransport] task");
    if (self.ws) {
        NSString *urlString = [NSString stringWithFormat:@"ws%@://%@:%u/mqtt",
                               self.tls ? @"s": @"",
                               self.host,
                               (unsigned int)self.port];
        NSURL *url = [NSURL URLWithString:urlString];
        if (@available(iOS 13.0, macOS 10.15, *)) {
            self.webSocketTask = [self.session webSocketTaskWithURL:url protocols:@[@"mqtt"]];
        } else {
            // Fallback on earlier versions
        }
    } else {
        if (@available(iOS 9.0, macos 10.11, *)) {
            self.streamTask = [self.session streamTaskWithHostName:self.host
                                                              port:self.port];
        } else {
            // Fallback on earlier versions
        }
    }

    DDLogVerbose(@"[MQTTNWTransport] resume");
    if (self.ws) {
        [self.webSocketTask resume];
    } else {
        [self.streamTask resume];
    }

    if (!self.ws) {
        if (self.tls) {
            [self.streamTask startSecureConnection];
        } else {
        }
    }

    [self.delegate mqttTransportDidOpen:self];
    [self read];
}

- (void)read {
    DDLogVerbose(@"[MQTTNWTransport] read");
    if (self.ws) {
        if (@available(iOS 13.0, macOS 10.15, *)) {
            [self.webSocketTask receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage * _Nullable message, NSError * _Nullable error) {
                DDLogVerbose(@"[MQTTNWTransport] receiveMessage %@ %@ %ld",
                             message, error, (long)self.webSocketTask.closeCode);
                if (error) {
                    if ([error.domain isEqualToString:NSPOSIXErrorDomain] && error.code == 57) {
                        [self.delegate mqttTransportDidClose:self];
                    } else {
                        [self.delegate mqttTransport:self didFailWithError:error];
                    }
                } else {
                    [self.delegate mqttTransport:self didReceiveMessage:message.data];
                    [self read];
                }
            }];
        } else {
            // Fallback on earlier versions
        }
    } else {
        [self.streamTask readDataOfMinLength:0
                                   maxLength:1024
                                     timeout:0
                           completionHandler:
         ^(NSData * _Nullable data, BOOL atEOF, NSError * _Nullable error) {
            DDLogVerbose(@"[MQTTNWTransport] read %@ %d %@", data, atEOF, error);
            if (atEOF) {
                [self.delegate mqttTransportDidClose:self];
            } else if (error || !data) {
                [self.delegate mqttTransport:self didFailWithError:error];
            } else {
                [self.delegate mqttTransport:self didReceiveMessage:data];
                [self read];
            }
        }];
    }
}

- (void)close {
    if (self.ws) {
        [self.webSocketTask cancel];
    } else {
        [self.streamTask cancel];
    }
}

- (BOOL)send:(NSData *)data {
    if (self.ws) {
        if (@available(iOS 13.0, macOS 10.15, *)) {
            DDLogVerbose(@"[MQTTNWTransport] send ws %ld %@",
                         (long)self.webSocketTask.state,
                         self.webSocketTask.error);

            NSURLSessionWebSocketMessage *message = [[NSURLSessionWebSocketMessage alloc] initWithData:data];
            [self.webSocketTask sendMessage:message
                          completionHandler:^(NSError * _Nullable error) {
                DDLogVerbose(@"[MQTTNWTransport] sendMessage error %@", error);
            }];
        } else {
            // Fallback on earlier versions
        }
    } else {
        DDLogVerbose(@"[MQTTNWTransport] send stream %ld %@",
                     (long)self.streamTask.state,
                     self.streamTask.error);
        [self.streamTask writeData:data
                           timeout:0
                 completionHandler:^(NSError * _Nullable error) {
            DDLogVerbose(@"[MQTTNWTransport] send error %@", error);
        }];
    }
    return TRUE;
}

- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
            DDLogVerbose(@"[MQTTNWTransport] didReceiveChallenge %@ %@ %@",
                 challenge, challenge.protectionSpace, challenge.proposedCredential);
    if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust) {
        DDLogVerbose(@"[MQTTNWTransport] serverTrust %@",
             challenge.protectionSpace.serverTrust);
        CFIndex certificateCount = SecTrustGetCertificateCount(challenge.protectionSpace.serverTrust);
        DDLogVerbose(@"[MQTTNWTransport] SecTrustGetCertificateCount %ld",
                     (long)certificateCount);

        CFArrayRef certs = SecTrustCopyCertificateChain(challenge.protectionSpace.serverTrust);
        for (CFIndex index = 0; index < certificateCount; index++) {
            SecCertificateRef certificateRef  = (SecCertificateRef)CFArrayGetValueAtIndex(certs, index);
            NSString *summary = (NSString*)CFBridgingRelease(
                                   SecCertificateCopySubjectSummary(certificateRef)
                                );
            DDLogVerbose(@"[MQTTNWTransport] SecCertificateCopySubjectSummary %@", summary);
        }
        CFRelease(certs);

        if (self.allowUntrustedCertificates) {
            if ([challenge.protectionSpace.host isEqualToString:self.host]) {
                NSURLCredential *sc = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
                completionHandler(NSURLSessionAuthChallengeUseCredential, sc);
                return;
            }
        }

    } else if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate) {
        if (self.certificates) {
            NSURLCredential *cc = [NSURLCredential
                                   credentialWithIdentity:(__bridge SecIdentityRef _Nonnull)(self.certificates[0])
                                   certificates:self.certificates persistence:NSURLCredentialPersistenceForSession];

            completionHandler(NSURLSessionAuthChallengeUseCredential, cc);
            return;
        }
    }

    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, challenge.proposedCredential);
}

@end
