//
//  Connection.m
//  OwnTracks
//
//  Created by Christoph Krey on 25.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "Connection.h"
#import "CoreData.h"
#import "OwnTracksAppDelegate.h"

@interface Connection()

@property (nonatomic) NSInteger state;

@property (strong, nonatomic) NSTimer *reconnectTimer;
@property (nonatomic) double reconnectTime;
@property (nonatomic) BOOL reconnectFlag;

@property (strong, nonatomic) MQTTSession *session;

@property (strong, nonatomic) NSString *host;
@property (nonatomic) NSInteger port;
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
#ifdef DEBUG
    NSLog(@"Connection init");
#endif

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
#ifdef DEBUG
    NSLog(@"Connection connectTo: %@:%@@%@:%d %@ (%d) c%d / %@ %@ q%d r%d as %@",
          auth ? user : @"",
          auth ? pass : @"",
          host,
          port,
          tls ? @"TLS" : @"PLAIN",
          keepalive,
          clean,
          willTopic,
          [Connection dataToString:will],
          willQos,
          willRetainFlag,
          clientId
          );
#endif

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
        self.port = port;
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
        
#ifdef DEBUG
        NSLog(@"Connection new session");
#endif

        self.session = [[MQTTSession alloc] initWithClientId:clientId
                                                    userName:auth ? user : @""
                                                    password:auth ? pass : @""
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
}

- (UInt16)sendData:(NSData *)data topic:(NSString *)topic qos:(NSInteger)qos retain:(BOOL)retainFlag
{
#ifdef DEBUG
    NSLog(@"Connection sendData:%@ %@ q%d r%d", topic, [Connection dataToString:data], qos, retainFlag);
#endif
    
    if (self.state != state_connected) {
        [self connectToLast];
    }
    UInt16 msgId = [self.session publishData:data
                                     onTopic:topic
                                      retain:retainFlag
                                         qos:qos];
    return msgId;
}

- (void)disconnect
{
#ifdef DEBUG
    NSLog(@"Connection disconnect:");
#endif
    self.state = state_closing;
    [self.session close];

    if (self.reconnectTimer) {
        [self.reconnectTimer invalidate];
        self.reconnectTimer = nil;
    }
}

#pragma mark - MQTT Callback methods

- (void)handleEvent:(MQTTSession *)session event:(MQTTSessionEvent)eventCode error:(NSError *)error
{
#ifdef DEBUG
    const NSDictionary *events = @{
                                   @(MQTTSessionEventConnected): @"connected",
                                   @(MQTTSessionEventConnectionRefused): @"connection refused",
                                   @(MQTTSessionEventConnectionClosed): @"connection closed",
                                   @(MQTTSessionEventConnectionError): @"connection error",
                                   @(MQTTSessionEventProtocolError): @"protocoll error"
                                   };
    NSLog(@"Connection MQTT eventCode: %@ (%d) %@", events[@(eventCode)], eventCode, error);
#endif
    [self.reconnectTimer invalidate];
    switch (eventCode) {
        case MQTTSessionEventConnected:
        {
            self.lastErrorCode = nil;
            self.state = state_connected;
            
            /*
             * if clean-session is set or if it's the first time we connect in non-clean-session-mode, subscribe to topic
             */
            if (self.clean || !self.reconnectFlag) {
                OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
                NSString *topic = [delegate.settings stringForKey:@"subscription_preference"];
                UInt8 qos =[delegate.settings integerForKey:@"subscriptionqos_preference"];
                if (topic && ![topic isEqualToString:@""]) {
                    [self.session subscribeToTopic:topic atLevel:qos];
                }
                self.reconnectFlag = TRUE;
            }

            break;
        }
        case MQTTSessionEventConnectionClosed:
            /* this informs the caller that the connection is closed
             * specifically, the caller can end the background task now */
            self.state = state_closed;
            self.state = state_starting;
            break;
        case MQTTSessionEventProtocolError:
        case MQTTSessionEventConnectionRefused:
        case MQTTSessionEventConnectionError:
        {
#ifdef DEBUG
            NSLog(@"Connection setTimer %f", self.reconnectTime);
#endif
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
    [self.delegate messageDelivered:msgID];
}

/*
 * Incoming Data Handler for subscriptions
 *
 * all incoming data is responded to by a publish of the current position
 *
 */

- (void)newMessage:(MQTTSession *)session data:(NSData *)data onTopic:(NSString *)topic qos:(int)qos retained:(BOOL)retained mid:(unsigned int)mid
{
#ifdef DEBUG
    NSLog(@"Connection received %@ %@", topic, [Connection dataToString:data]);
#endif
    [self.delegate handleMessage:data onTopic:topic];
    if ([self.delegate respondsToSelector:@selector(saveContext)]) {
        [self.delegate performSelector:@selector(saveContext)];
    }
}

- (void)buffered:(MQTTSession *)session queued:(NSUInteger)queued flowingIn:(NSUInteger)flowingIn flowingOut:(NSUInteger)flowingOut
{
#ifdef DEBUG
    NSLog(@"Connection buffered q%u i%u o%u", queued, flowingIn, flowingOut);
#endif
    if ((queued + flowingIn + flowingOut) && self.state == state_connected) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = TRUE;
    } else {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = FALSE;
    }
    [self.delegate totalBuffered:queued ? queued : flowingOut ? flowingOut : flowingIn];
}

#pragma internal helpers

- (void)connectToInternal
{
    if (self.state == state_starting) {
        self.state = state_connecting;
        [self.session connectToHost:self.host
                               port:self.port
                           usingSSL:self.tls];
    } else {
        NSLog(@"Connection not starting, can't connect");
    }
}

- (NSString *)url
{
    return [NSString stringWithFormat:@"%@%@:%d",
            self.auth ? [NSString stringWithFormat:@"%@@", self.user] : @"",
            self.host,
            self.port
            ];
}

+ (NSString *)dataToString:(NSData *)data
{
    /* the following lines are necessary to convert data which is possibly not null-terminated into a string */
    NSString *message = [[NSString alloc] init];
    for (int i = 0; i < data.length; i++) {
        char c;
        [data getBytes:&c range:NSMakeRange(i, 1)];
        message = [message stringByAppendingFormat:@"%c", c];
    }
    return message;
}

- (void)setState:(NSInteger)state
{
    _state = state;
#ifdef DEBUG
    const NSDictionary *states = @{
                                   @(state_starting): @"starting",
                                   @(state_connecting): @"connecting",
                                   @(state_error): @"error",
                                   @(state_connected): @"connected",
                                   @(state_closing): @"closing",
                                   @(state_closed): @"closed"
                                   };
    
    NSLog(@"Connection state %@ (%d)", states[@(self.state)], self.state);
#endif
    [self.delegate showState:self.state];
}

- (void)reconnect
{
#ifdef DEBUG
    NSLog(@"Connection reconnect");
#endif
    
    self.reconnectTimer = nil;
    self.state = state_starting;

    if (self.reconnectTime < RECONNECT_TIMER_MAX) {
        self.reconnectTime *= 2;
    }
    [self connectToInternal];
}

- (void)connectToLast
{
#ifdef DEBUG
    NSLog(@"Connection connectToLast");
#endif
    
    self.reconnectTime = RECONNECT_TIMER;
    
    [self connectToInternal];
}

@end
