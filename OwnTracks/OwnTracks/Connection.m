//
//  Connection.m
//  OwnTracks
//
//  Created by Christoph Krey on 25.08.13.
//  Copyright © 2013-2018 Christoph Krey. All rights reserved.
//

#import "Connection.h"

#import "CoreData.h"
#import "Queue+CoreDataClass.h"

#import <UIKit/UIKit.h>
#import "MQTTLog.h"
#import "sodium.h"
#import "MQTTWebsocketTransport.h"
#import "LocationManager.h"
#import "Settings.h"
#import "MQTTSSLSecurityPolicy.h"
#import "MQTTSSLSecurityPolicyTransport.h"

@interface Connection() <NSURLSessionDelegate>

@property (nonatomic) NSInteger state;

@property (strong, nonatomic) NSTimer *reconnectTimer;
@property (strong, nonatomic) NSTimer *idleTimer;
@property (nonatomic) double reconnectTime;
@property (nonatomic) BOOL reconnectFlag;

@property (strong, nonatomic) MQTTSession *session;
@property (strong, nonatomic) NSMutableDictionary <NSString *, NSNumber *> *extraSubscriptions;

@property (strong, nonatomic) NSString *url;

@property (strong, nonatomic) NSString *host;
@property (nonatomic) UInt32 port;
@property (nonatomic) BOOL ws;
@property (nonatomic) BOOL tls;
@property (nonatomic) MQTTProtocolVersion protocolVersion;
@property (nonatomic) NSInteger keepalive;
@property (nonatomic) BOOL clean;
@property (nonatomic) BOOL auth;
@property (strong, nonatomic) NSString *user;
@property (strong, nonatomic) NSString *pass;
@property (strong, nonatomic) NSString *willTopic;
@property (strong, nonatomic) NSData *will;
@property (nonatomic) NSInteger willQos;
@property (nonatomic) BOOL willRetainFlag;
@property (strong, nonatomic) NSString *clientId;
@property (strong, nonatomic) MQTTSSLSecurityPolicy *securityPolicy;
@property (strong, nonatomic) NSArray *certificates;

@property (nonatomic, readwrite) NSError *lastErrorCode;

@property (nonatomic) NSUInteger outCount;
@property (nonatomic) NSUInteger inCount;

@property (strong, nonatomic) NSURLSession *urlSession;

@end

#define RECONNECT_TIMER 1.0
#define RECONNECT_TIMER_MAX 64.0

@implementation Connection
DDLogLevel ddLogLevel = DDLogLevelWarning;

- (instancetype)init {
    self = [super init];
    DDLogVerbose(@"[Connection] Connection init");
    
    if (sodium_init() == -1) {
        DDLogError(@"[Connection] sodium_init failed");
    } else {
        DDLogInfo(@"[Connection] sodium_init succeeded");
    }

    [MQTTLog setLogLevel:DDLogLevelWarning];

    self.state = state_starting;
    self.subscriptions = [[NSArray alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note){
                                                      DDLogVerbose(@"[Connection] UIApplicationWillEnterForegroundNotification");
                                                  }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note){
                                                      DDLogVerbose(@"[Connection] UIApplicationDidBecomeActiveNotification");
                                                      [self connectToLast];
                                                  }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note){
                                                      DDLogVerbose(@"[Connection] UIApplicationDidEnterBackgroundNotification");
                                                  }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note){
                                                      DDLogVerbose(@"[Connection] UIApplicationWillResignActiveNotification");
                                                      if ([LocationManager sharedInstance].monitoring != LocationMonitoringMove) {
                                                          [self disconnect];
                                                      }
                                                  }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note){
                                                      DDLogVerbose(@"[Connection] UIApplicationWillTerminateNotification");
                                                      self.terminate = true;
                                                  }];
    return self;
}

- (void)main {
    DDLogVerbose(@"[Connection] main");
    // if there is no timer running, runUntilDate: does return immediately!?
    self.idleTimer = [NSTimer timerWithTimeInterval:60
                                             target:self
                                           selector:@selector(idle)
                                           userInfo:nil
                                            repeats:TRUE];
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [runLoop addTimer:self.idleTimer forMode:NSDefaultRunLoopMode];
    
    while (!self.terminate) {
        DDLogVerbose(@"[Connection] main %@", [NSDate date]);
        if (self.url) {
            __block NSTimeInterval runUntilDate = 1.0;
            [CoreData.sharedInstance.queuedMOC performBlockAndWait:^{
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Queue"];
                request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
                
                NSError *error = nil;
                NSArray *matches = [CoreData.sharedInstance.queuedMOC executeFetchRequest:request error:&error];
                if (matches) {
                    [self.delegate totalBuffered: self count:matches.count];
                    if (matches.count) {
                        Queue *queue = matches.firstObject;
                        
                        if (self.state == state_starting) {
                            [self sendHTTP:queue.topic data:queue.data];
                            runUntilDate = 0.1;
                        }

                        if (matches.count > 100 * 1024) {
                            queue = matches.lastObject;
                            [CoreData.sharedInstance.queuedMOC deleteObject:queue];
                            [CoreData.sharedInstance sync:CoreData.sharedInstance.queuedMOC];
                        }
                    }
                }
            }];
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:runUntilDate]];
        } else {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        }
    }
    
    [self disconnect];
    [self.idleTimer invalidate];
}

- (void)idle {
    DDLogVerbose(@"[Connection] %@ idle", self.clientId);
}

- (void)connectTo:(NSString *)host
             port:(UInt32)port
               ws:(BOOL)ws
              tls:(BOOL)tls
  protocolVersion:(MQTTProtocolVersion)protocolVersion
        keepalive:(NSInteger)keepalive
            clean:(BOOL)clean
             auth:(BOOL)auth
             user:(NSString *)user
             pass:(NSString *)pass
        willTopic:(NSString *)willTopic
             will:(NSData *)will
          willQos:(NSInteger)willQos
   willRetainFlag:(BOOL)willRetainFlag
     withClientId:(NSString *)clientId
   securityPolicy:(MQTTSSLSecurityPolicy *)securityPolicy
     certificates:(NSArray *)certificates {
    DDLogVerbose(@"[Connection] %@ connectTo: %@:%@@%@:%ld v%d %@ %@ (%ld) c%d / %@ %@ q%ld r%d as %@ %@ %@",
                 self.clientId,
                 auth ? user : @"",
                 auth ? pass : @"",
                 host,
                 (long)port,
                 protocolVersion,
                 ws ? @"WS" : @"MQTT",
                 tls ? @"TLS" : @"PLAIN",
                 (long)keepalive,
                 clean,
                 willTopic,
                 [[NSString alloc] initWithData:will encoding:NSUTF8StringEncoding],
                 (long)willQos,
                 willRetainFlag,
                 clientId,
                 securityPolicy,
                 certificates
                 );
    
    self.url = nil;
    
    if (!self.session ||
        ![host isEqualToString:self.host] ||
        port != self.port ||
        ws != self.ws ||
        tls != self.tls ||
        keepalive != self.keepalive ||
        clean != self.clean ||
        auth != self.auth ||
        ![user isEqualToString:self.user] ||
        ![pass isEqualToString:self.pass] ||
        ![willTopic isEqualToString:self.willTopic] ||
        //![will isEqualToData:self.will] ||
        willQos != self.willQos ||
        willRetainFlag != self.willRetainFlag ||
        ![clientId isEqualToString:self.clientId] ||
        securityPolicy != self.securityPolicy ||
        certificates != self.certificates) {
        self.host = host;
        self.port = (int)port;
        self.protocolVersion = protocolVersion;
        self.ws = ws;
        self.tls = tls;
        self.keepalive = keepalive;
        self.clean = clean;
        self.auth = auth;
        self.user = user;
        self.pass = pass;
        self.willTopic = willTopic;
        self.will = will;
        self.willQos = willQos;
        self.willRetainFlag = willRetainFlag;
        self.clientId = clientId;
        self.securityPolicy = securityPolicy;
        self.certificates = certificates;
        
        DDLogVerbose(@"[Connection] %@ new session", self.clientId);
        MQTTTransport *mqttTransport;
        if (ws) {
            MQTTWebsocketTransport *websocketTransport = [[MQTTWebsocketTransport alloc] init];
            websocketTransport.host = host;
            websocketTransport.port = port;
            websocketTransport.tls = tls;
            if (securityPolicy) {
                websocketTransport.allowUntrustedCertificates = securityPolicy.allowInvalidCertificates;
                websocketTransport.pinnedCertificates = securityPolicy.pinnedCertificates;
            }

            mqttTransport = websocketTransport;
        } else {
            if (securityPolicy) {
                MQTTSSLSecurityPolicyTransport *sslSecPolTransport = [[MQTTSSLSecurityPolicyTransport alloc] init];
                sslSecPolTransport.host = host;
                sslSecPolTransport.port = port;
                sslSecPolTransport.tls = tls;
                sslSecPolTransport.certificates = certificates;
                sslSecPolTransport.securityPolicy = securityPolicy;

                mqttTransport = sslSecPolTransport;
            } else {
                MQTTCFSocketTransport *cfSocketTransport = [[MQTTCFSocketTransport alloc] init];
                cfSocketTransport.host = host;
                cfSocketTransport.port = port;
                cfSocketTransport.tls = tls;
                cfSocketTransport.certificates = certificates;
                mqttTransport = cfSocketTransport;
            }
        }

        self.session = [[MQTTSession alloc] init];
        self.session.transport = mqttTransport;
        self.session.clientId = clientId;
        self.session.userName = auth ? user : nil;
        self.session.password = auth ? pass : nil;
        self.session.keepAliveInterval = keepalive;
        self.session.cleanSessionFlag = clean;

        if (willTopic) {
            MQTTWill *mqttWill = [[MQTTWill alloc] initWithTopic:willTopic
                                                            data:will
                                                      retainFlag:willRetainFlag
                                                             qos:willQos
                                               willDelayInterval:nil
                                          payloadFormatIndicator:nil
                                           messageExpiryInterval:nil
                                                     contentType:nil
                                                   responseTopic:nil
                                                 correlationData:nil
                                                  userProperties:nil];
            self.session.will = mqttWill;
        }

        self.session.protocolLevel = protocolVersion;
        self.session.persistence.persistent = TRUE;
        self.session.persistence.maxMessages = 100 * 1024;
        self.session.persistence.maxSize = 100 * 1024 * 1024;

        (self.session).delegate = self;

        self.reconnectTime = RECONNECT_TIMER;
        self.reconnectFlag = FALSE;
    }
    [self connectToInternal];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)redirectResponse
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler {
    NSMutableURLRequest *newRequest = request.mutableCopy;
    if (redirectResponse) {
        newRequest = nil;
    }

    completionHandler(newRequest);
}


- (void)connectHTTP:(NSString *)url auth:(BOOL)auth user:(NSString *)user pass:(NSString *)pass {
    self.url = url;
    self.auth = auth;
    self.user = auth ? user : nil;
    self.pass = auth ? pass : nil;
    self.reconnectTime = RECONNECT_TIMER;
    self.reconnectFlag = FALSE;
    self.state = state_starting;
    [self connectToInternal];

#if 1
    NSURLSessionConfiguration *usc = NSURLSessionConfiguration.defaultSessionConfiguration;
    self.urlSession = [NSURLSession sessionWithConfiguration:usc
                                                    delegate:self
                                               delegateQueue:nil];
#else
    self.urlSession = NSURLSession.sharedSession;
#endif
}

- (UInt16)sendData:(NSData *)data topic:(NSString *)topic qos:(NSInteger)qos retain:(BOOL)retainFlag {
    DDLogVerbose(@"[Connection] %@ sendData:%@ %@ q%ld r%d",
                 self.clientId,
                 topic,
                 [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding],
                 (long)qos,
                 retainFlag);

    if (self.url) {
        [CoreData.sharedInstance.queuedMOC performBlock:^{
            Queue *queue = [NSEntityDescription insertNewObjectForEntityForName:@"Queue"
                                                         inManagedObjectContext:CoreData.sharedInstance.queuedMOC];

            NSData *outgoingData = data;
            if (outgoingData) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:outgoingData options:0 error:nil];
                if (json && [json isKindOfClass:[NSDictionary class]] && self.url) {
                    NSMutableDictionary *mutableJson = [json mutableCopy];
                    mutableJson[@"topic"] = topic;
                    outgoingData = [NSJSONSerialization dataWithJSONObject:mutableJson options:0 error:nil];
                }
            }
            if (self.key && self.key.length) {
                outgoingData = [self encrypt:outgoingData];
            }

            queue.timestamp = [NSDate date];
            queue.topic = topic;
            queue.data = outgoingData;
            
            [CoreData.sharedInstance sync:CoreData.sharedInstance.queuedMOC];
        }];
        
        return 0;
    } else {
        if (self.state != state_connected) {
            [self connectToLast];
        }

        NSData *outgoingData = (self.key && self.key.length) ? [self encrypt:data] : data;

        UInt16 msgId = [self.session publishDataV5:outgoingData
                                           onTopic:topic
                                            retain:retainFlag
                                               qos:qos
                            payloadFormatIndicator:nil
                             messageExpiryInterval:nil
                                        topicAlias:nil
                                     responseTopic:nil
                                   correlationData:nil
                                    userProperties:nil
                                       contentType:nil
                                    publishHandler:nil];
        DDLogVerbose(@"%@ sendData m%u", self.clientId, msgId);
        return msgId;
    }
}

- (void)sendHTTP:(NSString *)topic data:(NSData *)data {
    NSString *postLength = [NSString stringWithFormat:@"%ld",(unsigned long)data.length];
    DDLogVerbose(@"[Connection] sendtHTTP %@(%@):%@",
                 topic, postLength, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    // auth
    if (self.auth) {
        NSString *authString = [NSString stringWithFormat:@"%@:%@",
                                self.user ? self.user : @"",
                                self.pass ? self.pass : @""];
        NSData *authData = [authString dataUsingEncoding:NSASCIIStringEncoding];
        NSString *authValue = [authData base64EncodedStringWithOptions:0];
        [request setValue:[NSString stringWithFormat:@"Basic %@", authValue] forHTTPHeaderField:@"Authorization"];
    }
    
    request.URL = [NSURL URLWithString:self.url];
    request.HTTPMethod = @"POST";
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    request.HTTPBody = data;
    
    NSString *contentType = [NSString stringWithFormat:@"application/json"];
    [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    DDLogVerbose(@"[Connection] NSMutableURLRequest %@", request);
    
    self.state = state_connecting;
    self.lastErrorCode = nil;

    __block NSRunLoop *myRunLoop = [NSRunLoop currentRunLoop];

    NSURLSessionDataTask *dataTask =
    [self.urlSession dataTaskWithRequest:request completionHandler:
     ^(NSData *data, NSURLResponse *response, NSError *error) {

         DDLogVerbose(@"[Connection] dataTaskWithRequest %@ %@ %@", data, response, error);
         if (!error) {
             
             if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                 NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                 DDLogVerbose(@"[Connection] NSHTTPURLResponse %@", httpResponse);
                 if (httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299) {
                     self.state = state_connected;
                     
                     [CoreData.sharedInstance.queuedMOC performBlock:^{
                         NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Queue"];
                         request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
                         
                         NSArray *matches = [CoreData.sharedInstance.queuedMOC executeFetchRequest:request error:nil];
                         if (matches) {
                             [self.delegate totalBuffered: self count:matches.count];
                             if (matches.count) {
                                 Queue *queue = matches.firstObject;
                                 [CoreData.sharedInstance.queuedMOC deleteObject:queue];
                                 [CoreData.sharedInstance sync:CoreData.sharedInstance.queuedMOC];
                             }
                         }
                         
                         NSData *incomingData = data;
                         DDLogVerbose(@"[Connection] incomingData %@",
                                      [[NSString alloc] initWithData:incomingData encoding:NSUTF8StringEncoding]);
                         if (self.key && self.key.length) {
                             incomingData = [self decrypt:incomingData];
                         }

                         if (incomingData) {
                             id json = [NSJSONSerialization JSONObjectWithData:incomingData options:0 error:nil];
                             if (json && [json isKindOfClass:[NSArray class]]) {
                                 for (id element in json) {
                                     if ([element isKindOfClass:[NSDictionary class]]) {
                                         [self oneMessage:element];
                                     }
                                 }
                             } else if ([json isKindOfClass:[NSDictionary class]]) {
                                 [self oneMessage:json];
                             } else {
                                 //
                             }
                         } else {
                             //
                         }
                         
                         self.state = state_starting;
                         return;
                     }];
                     
                 } else {
                     self.lastErrorCode = [NSError errorWithDomain:@"HTTP Response"
                                                              code:httpResponse.statusCode userInfo:nil];
                     self.state = state_error;
                     [self startReconnectTimer:myRunLoop];
                 }
             } else {
                 self.lastErrorCode = [NSError errorWithDomain:@"HTTP Response"
                                                          code:0 userInfo:nil];
                 self.state = state_error;
                 [self startReconnectTimer:myRunLoop];
             }
         } else {
             self.lastErrorCode = error;
             self.state = state_error;
             [self startReconnectTimer:myRunLoop];
         }
     }];
    [dataTask resume];
}

- (void)oneMessage:(NSDictionary *)message {
    DDLogVerbose(@"[Connection] oneMessage %@", message.description);

    if (message && [message isKindOfClass:[NSDictionary class]]) {
        NSString *topic = @"owntracks/http/??";
        NSString *type = message[@"_type"];
        if (type && [type isEqualToString:@"cmd"]) {
            topic = [Settings theGeneralTopicInMOC:CoreData.sharedInstance.queuedMOC];
        } else {
            if (message[@"tid"]) {
                topic = [NSString stringWithFormat:@"owntracks/http/%@", message[@"tid"]];
            }
        }
        DDLogVerbose(@"[Connection] oneMessage topic %@", topic);
        
        [self.delegate handleMessage:self
                                data:[NSJSONSerialization dataWithJSONObject:message options:0 error:nil]
                             onTopic:topic
                            retained:FALSE];
    }
}

- (void)disconnect {
    DDLogInfo(@"[Connection] %@ disconnect:", self.clientId);
    if (!self.url) {
        self.state = state_closing;
        [self.session closeWithReturnCode:MQTTSuccess
                    sessionExpiryInterval:nil
                             reasonString:nil
                           userProperties:nil
                        disconnectHandler:nil];

        if (self.reconnectTimer) {
            [self.reconnectTimer invalidate];
            self.reconnectTimer = nil;
        }
    }
}

- (void)reset {
    DDLogInfo(@"[Connection] reset");
    
    [CoreData.sharedInstance.queuedMOC performBlockAndWait:^{
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Queue"];
        
        NSError *error = nil;
        NSArray *matches = [CoreData.sharedInstance.queuedMOC executeFetchRequest:request error:&error];
        if (matches) {
            if (matches.count) {
                for (NSManagedObject *object in matches) {
                    [CoreData.sharedInstance.queuedMOC deleteObject:object];
                }
                [CoreData.sharedInstance sync:CoreData.sharedInstance.queuedMOC];
            }
        }
        [self.delegate totalBuffered:self count:0];
    }];
}

- (void)addExtraSubscription:(NSString *)topicFilter qos:(MQTTQosLevel)qos {
    NSNumber *extraSubscription = (self.extraSubscriptions)[topicFilter];
    if (!extraSubscription) {
        (self.extraSubscriptions)[topicFilter] = [NSNumber numberWithInt:qos];
        [self.session subscribeToTopicV5:topicFilter
                                 atLevel:qos
                                 noLocal:FALSE
                       retainAsPublished:FALSE
                          retainHandling:MQTTSendRetained
                  subscriptionIdentifier:0
                          userProperties:nil
                        subscribeHandler:nil];
    }
}

- (void)removeExtraSubscription:(NSString *)topicFilter {
    NSNumber *extraSubscription = (self.extraSubscriptions)[topicFilter];
    if (extraSubscription) {
        [self.session unsubscribeTopicsV5:@[topicFilter]
                           userProperties:nil
                       unsubscribeHandler:nil];
        [self.extraSubscriptions removeObjectForKey:topicFilter];
    }
}

#pragma mark - MQTT Callback methods

- (void)connected:(MQTTSession *)session sessionPresent:(BOOL)sessionPresent {
    self.lastErrorCode = nil;
    self.state = state_connected;
    
    /*
     * if clean-session is set or if it's the first time we connect in non-clean-session-mode, subscribe to topic
     */
    if (self.clean || !self.reconnectFlag) {
        for (NSString *topicFilter in self.subscriptions) {
            if (topicFilter.length) {
                [self.session subscribeToTopicV5:topicFilter
                                         atLevel:self.subscriptionQos
                                         noLocal:FALSE
                               retainAsPublished:FALSE
                                  retainHandling:MQTTSendRetained
                          subscriptionIdentifier:0
                                  userProperties:nil
                                subscribeHandler:nil];
            }
        }
        for (NSString *topicFilter in self.extraSubscriptions.allKeys) {
            NSNumber *qos = (self.extraSubscriptions)[topicFilter];
            [self.session subscribeToTopicV5:topicFilter
                                     atLevel:qos.intValue
                                     noLocal:FALSE
                           retainAsPublished:FALSE
                              retainHandling:MQTTSendRetained
                      subscriptionIdentifier:0
                              userProperties:nil
                            subscribeHandler:nil];
        }
        self.reconnectFlag = TRUE;
    }
}

- (void)handleEvent:(MQTTSession *)session event:(MQTTSessionEvent)eventCode error:(NSError *)error {
    DDLogInfo(@"[Connection] %@ MQTT eventCode: %@ (%ld) %@",
                 self.clientId,
                 @{@(MQTTSessionEventConnected): @"connected",
                   @(MQTTSessionEventConnectionRefused): @"connection refused",
                   @(MQTTSessionEventConnectionClosed): @"connection closed",
                   @(MQTTSessionEventConnectionError): @"connection error",
                   @(MQTTSessionEventProtocolError): @"protocol error",
                   @(MQTTSessionEventConnectionClosedByBroker): @"connection closed by broker"
                   }[@(eventCode)],
                 (long)eventCode, error);
    
    [self.reconnectTimer invalidate];
    switch (eventCode) {
        case MQTTSessionEventConnected:
            // handled in connected callback
            break;
        case MQTTSessionEventConnectionClosed:
        case MQTTSessionEventConnectionClosedByBroker:
            /* this informs the caller that the connection is closed
             * specifically, the caller can end the background task now */
            self.state = state_closed;
            self.state = state_starting;
            break;
        case MQTTSessionEventProtocolError:
        case MQTTSessionEventConnectionRefused:
        case MQTTSessionEventConnectionError: {
            [self startReconnectTimer:[NSRunLoop currentRunLoop]];
            self.state = state_error;
            self.lastErrorCode = error;
            break;
        }
        default:
            break;
    }
}

- (void)subAckReceivedV5:(MQTTSession *)session
                   msgID:(UInt16)msgID
            reasonString:(NSString *)reasonString
          userProperties:(NSArray<NSDictionary<NSString *,NSString *> *> *)userProperties
             reasonCodes:(NSArray<NSNumber *> *)reasonCodes {
    DDLogInfo(@"[Connection] %@ subAckReceived mid=%u rc=%@ up=%@",
              session.clientId,
              msgID,
              reasonCodes,
              userProperties);

}

- (void)unsubAckReceivedV5:(MQTTSession *)session
                     msgID:(UInt16)msgID
              reasonString:(NSString *)reasonString
            userProperties:(NSArray<NSDictionary<NSString *,NSString *> *> *)userProperties
               reasonCodes:(NSArray<NSNumber *> *)reasonCodes {
    DDLogInfo(@"[Connection] %@ unsubAckReceived mid=%u rs=%@ rc=%@ up=%@",
              session.clientId,
              msgID,
              reasonString,
              reasonCodes,
              userProperties);
}

- (void)messageDeliveredV5:(MQTTSession *)session
                     msgID:(UInt16)msgID
                     topic:(NSString *)topic
                      data:(NSData *)data
                       qos:(MQTTQosLevel)qos
                retainFlag:(BOOL)retainFlag
    payloadFormatIndicator:(NSNumber *)payloadFormatIndicator
     messageExpiryInterval:(NSNumber *)messageExpiryInterval
                topicAlias:(NSNumber *)topicAlias
             responseTopic:(NSString *)responseTopic
           correlationData:(NSData *)correlationData
            userProperties:(NSArray<NSDictionary<NSString *,NSString *> *> *)userProperties
               contentType:(NSString *)contentType {
    DDLogInfo(@"[Connection] %@ messageDelivered mid=%u",
              session.clientId,
              msgID);
    [self.delegate messageDelivered:self msgID:msgID];

}

- (BOOL)newMessageWithFeedbackV5:(MQTTSession *)session
                            data:(NSData *)data
                         onTopic:(NSString *)topic
                             qos:(MQTTQosLevel)qos
                        retained:(BOOL)retained
                             mid:(unsigned int)mid
          payloadFormatIndicator:(NSNumber *)payloadFormatIndicator
           messageExpiryInterval:(NSNumber *)messageExpiryInterval
                      topicAlias:(NSNumber *)topicAlias
                   responseTopic:(NSString *)responseTopic
                 correlationData:(NSData *)correlationData
                  userProperties:(NSArray<NSDictionary<NSString *,NSString *> *> *)userProperties
                     contentType:(NSString *)contentType
         subscriptionIdentifiers:(NSArray<NSNumber *> *)subscriptionIdentifiers {

    if (self.key && self.key.length) {
        data = [self decrypt:data];
    }

    DDLogVerbose(@"[Connection] %@ received topic=%@ dataString=%@",
                 session.clientId,
                 topic,
                 [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    return [self.delegate handleMessage:self
                                   data:data
                                onTopic:topic
                               retained:retained];

}

- (void)buffered:(MQTTSession *)session
       flowingIn:(NSUInteger)flowingIn
      flowingOut:(NSUInteger)flowingOut {
    DDLogVerbose(@"[Connection] %@ buffered i%lu o%lu",
                 self.clientId,
                 (unsigned long)flowingIn,
                 (unsigned long)flowingOut);
    self.inCount = flowingIn;
    self.outCount = flowingOut;
    if ((flowingIn + flowingOut) && self.state == state_connected) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = TRUE;
    } else {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = FALSE;
    }
    [self.delegate totalBuffered: self count:flowingOut ? flowingOut : flowingIn];
}

#pragma internal helpers

- (void)connectToInternal {
    if (!self.url) {
        if (self.state == state_starting) {
            self.state = state_connecting;
            [self.session connectWithConnectHandler:nil];
        } else {
            DDLogVerbose(@"[Connection] %@ not starting, can't connect", self.clientId);
        }
    }
}

- (NSString *)parameters {
    if (self.url) {
        return self.url;
    } else {
        return [NSString stringWithFormat:@"%@://%@%@:%ld c%d k%ld as %@",
                self.ws ? (self.tls ? @"wss" : @"ws") : (self.tls ? @"mqtts" : @"mqtt"),
                self.auth ? [NSString stringWithFormat:@"%@@", self.user] : @"",
                self.host,
                (long)self.port,
                self.clean,
                (long)self.keepalive,
                self.clientId
                ];
    }
}

- (void)setState:(NSInteger)state {
    _state = state;
    DDLogVerbose(@"[Connection] %@ state %@ (%ld)",
                 self.clientId,
                 @{@(state_starting): @"starting",
                   @(state_connecting): @"connecting",
                   @(state_error): @"error",
                   @(state_connected): @"connected",
                   @(state_closing): @"closing",
                   @(state_closed): @"closed"
                   }[@(self.state)],
                 (long)self.state);
    [self.delegate showState:self state:self.state];
}

- (void)reconnect {
    DDLogInfo(@"[Connection] %@ reconnect", self.clientId);
    
    self.reconnectTimer = nil;
    self.state = state_starting;
    self.lastErrorCode = nil;
    
    if (self.reconnectTime < RECONNECT_TIMER_MAX) {
        self.reconnectTime *= 2;
    }
    [self connectToInternal];
}

- (void)connectToLast {
    DDLogInfo(@"[Connection] %@ connectToLast", self.clientId);
    
    self.reconnectTime = RECONNECT_TIMER;
    
    [self connectToInternal];
}

- (void)startReconnectTimer:(NSRunLoop *)runLoop {
    DDLogVerbose(@"[Connection] %@ setTimer %f", self.clientId, self.reconnectTime);
    self.reconnectTimer = [NSTimer timerWithTimeInterval:self.reconnectTime
                                                  target:self
                                                selector:@selector(reconnect)
                                                userInfo:Nil repeats:FALSE];
    [runLoop addTimer:self.reconnectTimer forMode:NSDefaultRunLoopMode];
}

- (NSData *)encrypt:(NSData *)message {
    
    unsigned char nonce[crypto_secretbox_NONCEBYTES];
    randombytes_buf(nonce, sizeof nonce);
    
    unsigned char key[crypto_secretbox_KEYBYTES];
    memset(key, 0, sizeof(key));
    [self.key getBytes:key
             maxLength:sizeof(key)
            usedLength:nil
              encoding:NSUTF8StringEncoding
               options:0
                 range:NSMakeRange(0, self.key.length)
        remainingRange:nil];
    
    NSMutableData *ciphertext = [NSMutableData dataWithLength:message.length + crypto_secretbox_MACBYTES];
    crypto_secretbox_easy(ciphertext.mutableBytes, message.bytes, message.length, nonce, key);
    
    NSMutableData *onTheWire = [NSMutableData dataWithBytes:nonce length:crypto_secretbox_NONCEBYTES];
    [onTheWire appendData:ciphertext];
    
    NSDictionary *json = @{
                           @"_type": @"encrypted",
                           @"data": [onTheWire base64EncodedStringWithOptions:0]
                           };
    
    return [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
}

- (NSData *)decrypt:(NSData *)data {
    NSString *b64String;
    
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (json && [json isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = json;
        if ([dictionary[@"_type"] isEqualToString:@"encrypted"]) {
            b64String = dictionary[@"data"];
        } else {
            return data;
        }
    } else {
        return data;
    }

    NSData *onTheWire = [[NSData alloc] initWithBase64EncodedString:b64String
                                                            options:0];
    NSData *nonce = [onTheWire subdataWithRange:NSMakeRange(0, crypto_secretbox_NONCEBYTES)];
    NSData *ciphertext = [onTheWire subdataWithRange:NSMakeRange(crypto_secretbox_NONCEBYTES,
                                                                 onTheWire.length - crypto_secretbox_NONCEBYTES)];
    
    unsigned char key[crypto_secretbox_KEYBYTES];
    memset(key, 0, sizeof(key));
    [self.key getBytes:key
             maxLength:sizeof(key)
            usedLength:nil
              encoding:NSUTF8StringEncoding
               options:0
                 range:NSMakeRange(0, self.key.length)
        remainingRange:nil];
    
    NSMutableData *decrypted = [NSMutableData dataWithLength:ciphertext.length - crypto_secretbox_MACBYTES];
    if (crypto_secretbox_open_easy(decrypted.mutableBytes,
                                   ciphertext.bytes ,
                                   ciphertext.length,
                                   nonce
                                   .bytes,
                                   key) != 0) {
        decrypted = [NSMutableData data];
    }
    
    return decrypted;
}


@end
