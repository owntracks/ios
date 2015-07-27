//
//  Connection.m
//  OwnTracks
//
//  Created by Christoph Krey on 25.08.13.
//  Copyright (c) 2013-2015 Christoph Krey. All rights reserved.
//

#import "Connection.h"
#import "CoreData.h"

#import <CocoaLumberjack/CocoaLumberjack.h>
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

#define BACKGROUND_DISCONNECT_AFTER 8.0

@interface Connection()

@property (nonatomic) NSInteger state;

@property (strong, nonatomic) NSTimer *disconnectTimer;
@property (strong, nonatomic) NSTimer *reconnectTimer;
@property (strong, nonatomic) NSTimer *idleTimer;
@property (nonatomic) double reconnectTime;
@property (nonatomic) BOOL reconnectFlag;

@property (strong, nonatomic) MQTTSession *session;

@property (strong, nonatomic) NSString *host;
@property (nonatomic) UInt32 port;
@property (nonatomic) BOOL tls;
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

@end

#define RECONNECT_TIMER 1.0
#define RECONNECT_TIMER_MAX 64.0

@implementation Connection
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;

- (id)init {
    self = [super init];
    DDLogVerbose(@"ddLogLevel %lu", (unsigned long)ddLogLevel);
    DDLogVerbose(@"Connection init");
    self.state = state_starting;
    self.subscriptions = [[NSArray alloc] init];
    self.variableSubscriptions = [[NSDictionary alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification
                                                      object:nil queue:nil usingBlock:^(NSNotification *note){
                                                          DDLogVerbose(@"UIApplicationWillEnterForegroundNotification");
                                                      }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil queue:nil usingBlock:^(NSNotification *note){
                                                          DDLogVerbose(@"UIApplicationDidBecomeActiveNotification");
                                                          if (self.disconnectTimer && self.disconnectTimer.isValid) {
                                                              DDLogVerbose(@"%@ disconnectTimer invalidate %@",
                                                                           self.clientId,
                                                                           self.disconnectTimer.fireDate);
                                                              [self.disconnectTimer invalidate];
                                                          }
                                                          [self connectToLast];
                                                      }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil queue:nil usingBlock:^(NSNotification *note){
                                                          DDLogVerbose(@"UIApplicationDidEnterBackgroundNotification");
                                                      }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                      object:nil queue:nil usingBlock:^(NSNotification *note){
                                                          DDLogVerbose(@"UIApplicationWillResignActiveNotification");
                                                          [self disconnect];
                                                      }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                      object:nil queue:nil usingBlock:^(NSNotification *note){
                                                          DDLogVerbose(@"UIApplicationWillTerminateNotification");
                                                          self.terminate = true;
                                                      }];
    return self;
}

- (void)main {
    DDLogVerbose(@"Connection main");
    // if there is no timer running, runUntilDate: does return immediately!?
    self.idleTimer = [NSTimer timerWithTimeInterval:60
                                             target:self
                                           selector:@selector(idle)
                                           userInfo:nil
                                            repeats:TRUE];
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [runLoop addTimer:self.idleTimer forMode:NSDefaultRunLoopMode];
    while (!self.terminate) {
        DDLogVerbose(@"Connection main %@", [NSDate date]);
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    [self disconnect];
    [self.idleTimer invalidate];
}

- (void)idle {
    DDLogVerbose(@"%@ idle", self.clientId);
}

- (void)connectTo:(NSString *)host
             port:(NSInteger)port
              tls:(BOOL)tls
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
    DDLogVerbose(@"%@ connectTo: %@:%@@%@:%ld %@ (%ld) c%d / %@ %@ q%ld r%d as %@ %@ %@",
                 self.clientId,
                 auth ? user : @"",
                 auth ? pass : @"",
                 host,
                 (long)port,
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
    
    if (!self.session ||
        ![host isEqualToString:self.host] ||
        port != self.port ||
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
        
        DDLogVerbose(@"%@ new session", self.clientId);
        self.session = [[MQTTSession alloc] initWithClientId:clientId
                                                    userName:auth ? user : nil
                                                    password:auth ? pass : nil
                                                   keepAlive:keepalive
                                                cleanSession:clean
                                                        will:willTopic != nil
                                                   willTopic:willTopic
                                                     willMsg:will
                                                     willQoS:willQos
                                              willRetainFlag:willRetainFlag
                                               protocolLevel:3
                                                     runLoop:[NSRunLoop currentRunLoop]
                                                     forMode:NSDefaultRunLoopMode
                                              securityPolicy:securityPolicy
                                                certificates:certificates];
        [self.session setDelegate:self];
        self.session.persistence.persistent = TRUE;
        self.reconnectTime = RECONNECT_TIMER;
        self.reconnectFlag = FALSE;
    }
    [self connectToInternal];
}

- (void)startBackgroundTimer {
    DDLogVerbose(@"%@ startBackgroundTimer", self.clientId);
    
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        if (self.disconnectTimer && self.disconnectTimer.isValid) {
            DDLogVerbose(@"%@ disconnectTimer.isValid %@",
                         self.clientId,
                         self.disconnectTimer.fireDate);
        } else {
            self.disconnectTimer = [NSTimer timerWithTimeInterval:BACKGROUND_DISCONNECT_AFTER
                                                           target:self
                                                         selector:@selector(disconnectInBackground)
                                                         userInfo:Nil repeats:FALSE];
            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            [runLoop addTimer:self.disconnectTimer forMode:NSDefaultRunLoopMode];
            DDLogVerbose(@"%@ disconnectTimer %@",
                         self.clientId,
                         self.disconnectTimer.fireDate);
        }
    }
}

- (void)disconnectInBackground {
    DDLogVerbose(@"%@ disconnectInBackground", self.clientId);
    self.disconnectTimer = nil;
    [self disconnect];
}


- (UInt16)sendData:(NSData *)data topic:(NSString *)topic qos:(NSInteger)qos retain:(BOOL)retainFlag
{
    DDLogVerbose(@"%@ sendData:%@ %@ q%ld r%d",
                 self.clientId,
                 topic,
                 [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding],
                 (long)qos,
                 retainFlag);
    
    if (self.state != state_connected) {
        [self connectToLast];
    }
    UInt16 msgId = [self.session publishData:data
                                     onTopic:topic
                                      retain:retainFlag
                                         qos:qos];
    DDLogVerbose(@"%@ sendData m%u", self.clientId, msgId);
    return msgId;
}

- (void)disconnect
{
    DDLogVerbose(@"%@ disconnect:", self.clientId);
    self.state = state_closing;
    [self.session close];
    
    if (self.reconnectTimer) {
        [self.reconnectTimer invalidate];
        self.reconnectTimer = nil;
    }
}

- (void)setVariableSubscriptions:(NSDictionary *)variableSubscriptions {
    for (NSString *topicFilter in self.variableSubscriptions) {
        if (![variableSubscriptions objectForKey:topicFilter]) {
            [self.session unsubscribeTopic:topicFilter];
        }
    }
    
    for (NSString *topicFilter in variableSubscriptions) {
        if (![self.variableSubscriptions objectForKey:topicFilter]) {
            NSNumber *number = variableSubscriptions[topicFilter];
            MQTTQosLevel qos = [number unsignedIntValue];
            [self.session subscribeToTopic:topicFilter atLevel:qos];
        }
    }
    
    _variableSubscriptions = variableSubscriptions;
}

- (void)unsubscribeFromTopic:(NSString *)topic {
    [self.session unsubscribeTopic:topic];
}

#pragma mark - MQTT Callback methods

- (void)connected:(MQTTSession *)session sessionPresent:(BOOL)sessionPresent
{
    self.lastErrorCode = nil;
    self.state = state_connected;
    
    /*
     * if clean-session is set or if it's the first time we connect in non-clean-session-mode, subscribe to topic
     */
    if (self.clean || !self.reconnectFlag) {
        for (NSString *topicFilter in self.subscriptions) {
            if (topicFilter.length) {
                [self.session subscribeToTopic:topicFilter atLevel:self.subscriptionQos];
            }
        }
        for (NSString *topicFilter in self.variableSubscriptions.allKeys) {
            MQTTQosLevel qos = [self.variableSubscriptions[topicFilter] intValue];
            [self.session subscribeToTopic:topicFilter atLevel:qos];
        }
        self.reconnectFlag = TRUE;
    }
}

- (void)handleEvent:(MQTTSession *)session event:(MQTTSessionEvent)eventCode error:(NSError *)error
{
    DDLogVerbose(@"%@ MQTT eventCode: %@ (%ld) %@",
                 self.clientId,
                 @{@(MQTTSessionEventConnected): @"connected",
                   @(MQTTSessionEventConnectionRefused): @"connection refused",
                   @(MQTTSessionEventConnectionClosed): @"connection closed",
                   @(MQTTSessionEventConnectionError): @"connection error",
                   @(MQTTSessionEventProtocolError): @"protocoll error"
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
        case MQTTSessionEventConnectionError:
        {
            DDLogVerbose(@"%@ setTimer %f", self.clientId, self.reconnectTime);
            self.reconnectTimer = [NSTimer timerWithTimeInterval:self.reconnectTime
                                                          target:self
                                                        selector:@selector(reconnect)
                                                        userInfo:Nil repeats:FALSE];
            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            [runLoop addTimer:self.reconnectTimer
                      forMode:NSDefaultRunLoopMode];
            
            self.state = state_error;
            self.lastErrorCode = error;
            break;
        }
        default:
            break;
    }
}

- (void)subAckReceived:(MQTTSession *)session msgID:(UInt16)msgID grantedQoss:(NSArray *)qoss {
    DDLogVerbose(@"%@ subAckReceived m%u %@",
                 self.clientId,
                 msgID,
                 qoss);

}

- (void)unsubAckReceived:(MQTTSession *)session msgID:(UInt16)msgID {
    DDLogVerbose(@"%@ unsubAckReceived m%u",
                 self.clientId,
                 msgID);
}


- (void)messageDelivered:(MQTTSession *)session msgID:(UInt16)msgID
{
    DDLogVerbose(@"%@ messageDelivered m%u",
                 self.clientId,
                 msgID);
    [self.delegate messageDelivered:self msgID:msgID];
}

- (void)newMessage:(MQTTSession *)session data:(NSData *)data onTopic:(NSString *)topic qos:(MQTTQosLevel)qos retained:(BOOL)retained mid:(unsigned int)mid {
    DDLogVerbose(@"%@ received %@ %@",
                 self.clientId,
                 topic,
                 [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    [self.delegate handleMessage:self data:data onTopic:topic retained:retained];
}

- (void)buffered:(MQTTSession *)session flowingIn:(NSUInteger)flowingIn flowingOut:(NSUInteger)flowingOut {
    DDLogVerbose(@"%@ buffered i%lu o%lu",
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
    if (self.state == state_starting) {
        self.state = state_connecting;
        [self.session connectToHost:self.host
                               port:self.port
                           usingSSL:self.tls];
    } else {
        DDLogVerbose(@"%@ not starting, can't connect", self.clientId);
    }
    [self startBackgroundTimer];
}

- (NSString *)parameters {
    return [NSString stringWithFormat:@"%@://%@%@:%ld c%d k%ld as %@",
            self.tls ? @"mqtts" : @"mqtt",
            self.auth ? [NSString stringWithFormat:@"%@@", self.user] : @"",
            self.host,
            (long)self.port,
            self.clean,
            (long)self.keepalive,
            self.clientId
            ];
}

- (void)setState:(NSInteger)state {
    _state = state;
    DDLogVerbose(@"%@ state %@ (%ld)",
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
    DDLogVerbose(@"%@ reconnect", self.clientId);
    
    self.reconnectTimer = nil;
    self.state = state_starting;
    
    if (self.reconnectTime < RECONNECT_TIMER_MAX) {
        self.reconnectTime *= 2;
    }
    [self connectToInternal];
}

- (void)connectToLast {
    DDLogVerbose
    (@"%@ connectToLast", self.clientId);
    
    self.reconnectTime = RECONNECT_TIMER;
    
    [self connectToInternal];
}

@end
