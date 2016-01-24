//
//  Connection.h
//  OwnTracks
//
//  Created by Christoph Krey on 25.08.13.
//  Copyright © 2013-2016 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MQTTClient/MQTTClient.h>

@class Connection;

@protocol ConnectionDelegate <NSObject>

enum state {
    state_starting,
    state_connecting,
    state_error,
    state_connected,
    state_closing,
    state_closed
};

- (void)showState:(Connection *)connection state:(NSInteger)state;
- (BOOL)handleMessage:(Connection *)connection data:(NSData *)data onTopic:(NSString *)topic retained:(BOOL)retained;
- (void)messageDelivered:(Connection *)connection msgID:(UInt16)msgID;
- (void)totalBuffered:(Connection *)connection count:(NSUInteger)count;

@end

@interface Connection: NSThread <MQTTSessionDelegate>

@property (weak, nonatomic) id<ConnectionDelegate> delegate;
@property (nonatomic) BOOL terminate;
@property (nonatomic, readonly) NSInteger state;
@property (nonatomic, readonly) NSError *lastErrorCode;
@property (strong, nonatomic) NSArray *subscriptions;
@property (strong, nonatomic) NSDictionary *variableSubscriptions;
@property (strong, nonatomic) NSString *key;

@property (nonatomic) MQTTQosLevel subscriptionQos;

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
     certificates:(NSArray *)certificates;

- (void)connectToLast;

- (UInt16)sendData:(NSData *)data topic:(NSString *)topic qos:(NSInteger)qos retain:(BOOL)retainFlag;
- (void)disconnect;

- (NSString *)parameters;

- (void)unsubscribeFromTopic:(NSString *)topic;
@end
