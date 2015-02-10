//
//  Connection.m
//  OwnTracks
//
//  Created by Christoph Krey on 25.08.13.
//  Copyright (c) 2013-2015 Christoph Krey. All rights reserved.
//

#import "Connection.h"
#import "CoreData.h"
#import "OwnTracksAppDelegate.h"
#import "Message+Create.h"
#import "CoreData.h"

#ifdef DEBUG
#define DEBUGCONN TRUE
#else
#define DEBUGCONN FALSE
#endif

@interface Connection()

@property (nonatomic) NSInteger state;

@property (strong, nonatomic) NSTimer *reconnectTimer;
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

@property (nonatomic, readwrite) NSError *lastErrorCode;

@end

#define RECONNECT_TIMER 1.0
#define RECONNECT_TIMER_MAX 64.0

@implementation Connection

- (id)init
{
   if (DEBUGCONN) NSLog(@"Connection init");
    self = [super init];
    self.state = state_starting;
    return self;
}

/*
 * externally visible methods
 */

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
{
    if (DEBUGCONN) NSLog(@"Connection connectTo: %@:%@@%@:%ld %@ (%ld) c%d / %@ %@ q%ld r%d as %@",
                         auth ? user : @"",
                         auth ? pass : @"",
                         host,
                         (long)port,
                         tls ? @"TLS" : @"PLAIN",
                         (long)keepalive,
                         clean,
                         willTopic,
                         [Connection dataToString:will],
                         (long)willQos,
                         willRetainFlag,
                         clientId
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
        ![clientId isEqualToString:self.clientId]) {
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
        
        if (DEBUGCONN) NSLog(@"Connection new session");
        self.session = [[MQTTSession alloc] initWithClientId:clientId
                                                    userName:auth ? user : nil
                                                    password:auth ? pass : nil
                                                   keepAlive:keepalive
                                                cleanSession:clean
                                                        will:YES
                                                   willTopic:willTopic
                                                     willMsg:will
                                                     willQoS:willQos
                                              willRetainFlag:willRetainFlag
                                               protocolLevel:3
                                                     runLoop:[NSRunLoop currentRunLoop]
                                                     forMode:NSDefaultRunLoopMode];
        [self.session setDelegate:self];
        self.reconnectTime = RECONNECT_TIMER;
        self.reconnectFlag = FALSE;
    }
    [self connectToInternal];
    
    NSArray *messages = [Message allMessagesInManagedObjectContext:[CoreData theManagedObjectContext]];
    if (DEBUGCONN) NSLog(@"re-sending %lu messages", (unsigned long)messages.count);
    
    for (Message *message in messages) {
        NSData *data = message.data;
        NSString *topic = message.topic;
        MQTTQosLevel qos = [message.qos intValue];
        BOOL retained = [message.retained boolValue];
        [[CoreData theManagedObjectContext] deleteObject:message];
        [self sendData:data topic:topic qos:qos retain:retained];
    }
}

- (UInt16)sendData:(NSData *)data topic:(NSString *)topic qos:(NSInteger)qos retain:(BOOL)retainFlag
{
    if (DEBUGCONN) NSLog(@"Connection sendData:%@ %@ q%ld r%d", topic, [Connection dataToString:data], (long)qos, retainFlag);
    
    if (self.state != state_connected) {
        [self connectToLast];
    }
    UInt16 msgId = [self.session publishData:data
                                     onTopic:topic
                                      retain:retainFlag
                                         qos:qos];
    if (DEBUGCONN) NSLog(@"sendData m%u", msgId);
    if (msgId) {
        [Message messageWithMid:msgId
                      timestamp:[NSDate date]
                           data:data
                          topic:topic
                            qos:qos
                       retained:retainFlag
         inManagedObjectContext:[CoreData theManagedObjectContext]];
    }
    return msgId;
}

- (void)disconnect
{
    if (DEBUGCONN) NSLog(@"Connection disconnect:");
    self.state = state_closing;
    [self.session close];

    if (self.reconnectTimer) {
        [self.reconnectTimer invalidate];
        self.reconnectTimer = nil;
    }
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
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        UInt8 qos =[delegate.settings intForKey:@"subscriptionqos_preference"];
        
        NSArray *topicFilters = [[delegate.settings theSubscriptions] componentsSeparatedByCharactersInSet:
                                 [NSCharacterSet whitespaceCharacterSet]];
        for (NSString *topicFilter in topicFilters) {
            if (topicFilter.length) {
                [self.session subscribeToTopic:topicFilter atLevel:qos];
            }
        }
        self.reconnectFlag = TRUE;
    }
}

- (void)handleEvent:(MQTTSession *)session event:(MQTTSessionEvent)eventCode error:(NSError *)error
{
    if (DEBUGCONN) {
        const NSDictionary *events = @{
                                       @(MQTTSessionEventConnected): @"connected",
                                       @(MQTTSessionEventConnectionRefused): @"connection refused",
                                       @(MQTTSessionEventConnectionClosed): @"connection closed",
                                       @(MQTTSessionEventConnectionError): @"connection error",
                                       @(MQTTSessionEventProtocolError): @"protocoll error"
                                       };
        NSLog(@"Connection MQTT eventCode: %@ (%ld) %@", events[@(eventCode)], (long)eventCode, error);
    }
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
            if (DEBUGCONN) NSLog(@"Connection setTimer %f", self.reconnectTime);
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

- (void)messageDelivered:(MQTTSession *)session msgID:(UInt16)msgID
{
    if (DEBUGCONN) NSLog(@"messageDelivered m%u", msgID);
    [self.delegate messageDelivered:msgID];
    Message *message = [Message existsMessageWithMid:msgID inManagedObjectContext:[CoreData theManagedObjectContext]];
    if (message) {
        [[CoreData theManagedObjectContext] deleteObject:message];
    }
}

/*
 * Incoming Data Handler for subscriptions
 *
 * all incoming data is responded to by a publish of the current position
 *
 */

- (void)newMessage:(MQTTSession *)session data:(NSData *)data onTopic:(NSString *)topic qos:(MQTTQosLevel)qos retained:(BOOL)retained mid:(unsigned int)mid {
    if (DEBUGCONN) NSLog(@"Connection received %@ %@", topic, [Connection dataToString:data]);
    [self.delegate handleMessage:data onTopic:topic retained:retained];
}

- (void)buffered:(MQTTSession *)session flowingIn:(NSUInteger)flowingIn flowingOut:(NSUInteger)flowingOut {
    if (DEBUGCONN) NSLog(@"Connection buffered i%lu o%lu", (unsigned long)flowingIn, (unsigned long)flowingOut);
    if ((flowingIn + flowingOut) && self.state == state_connected) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = TRUE;
    } else {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = FALSE;
    }
    [self.delegate totalBuffered:flowingOut ? flowingOut : flowingIn];
}

#pragma internal helpers

- (void)connectToInternal {
    if (self.state == state_starting) {
        self.state = state_connecting;
        [self.session connectToHost:self.host
                               port:self.port
                           usingSSL:self.tls];
    } else {
       if (DEBUGCONN)  NSLog(@"Connection not starting, can't connect");
    }
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

+ (NSString *)dataToString:(NSData *)data {
    /* the following lines are necessary to convert data which is possibly not null-terminated into a string */
    NSString *message = [[NSString alloc] init];
    for (int i = 0; i < data.length; i++) {
        char c;
        [data getBytes:&c range:NSMakeRange(i, 1)];
        message = [message stringByAppendingFormat:@"%c", c];
    }
    return message;
}

- (void)setState:(NSInteger)state {
    _state = state;
    if (DEBUGCONN) {
        const NSDictionary *states = @{
                                       @(state_starting): @"starting",
                                       @(state_connecting): @"connecting",
                                       @(state_error): @"error",
                                       @(state_connected): @"connected",
                                       @(state_closing): @"closing",
                                       @(state_closed): @"closed"
                                       };
        
        NSLog(@"Connection state %@ (%ld)", states[@(self.state)], (long)self.state);
    }
    [self.delegate showState:self.state];
}

- (void)reconnect {
    if (DEBUGCONN) NSLog(@"Connection reconnect");
    
    self.reconnectTimer = nil;
    self.state = state_starting;

    if (self.reconnectTime < RECONNECT_TIMER_MAX) {
        self.reconnectTime *= 2;
    }
    [self connectToInternal];
}

- (void)connectToLast {
    if (DEBUGCONN) NSLog(@"Connection connectToLast");
    
    self.reconnectTime = RECONNECT_TIMER;
    
    [self connectToInternal];
}

@end
