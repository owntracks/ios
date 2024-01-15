//
//  Connection.h
//  OwnTracks
//
//  Created by Christoph Krey on 25.08.13.
//  Copyright © 2013-2024  Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mqttc/MQTTSession.h>

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

- (void)showState:(Connection * _Nonnull)connection state:(NSInteger)state;
- (BOOL)handleMessage:(Connection * _Nonnull)connection
                 data:(NSData * _Nullable)data
              onTopic:(NSString * _Nonnull)topic
             retained:(BOOL)retained;
- (void)messageDelivered:(Connection * _Nonnull)connection msgID:(UInt16)msgID;
- (void)totalBuffered:(Connection * _Nonnull)connection count:(NSUInteger)count;

@end

@interface Connection: NSThread <MQTTSessionDelegate>

@property (weak, nonatomic) _Nullable id<ConnectionDelegate> delegate;
@property (nonatomic) BOOL terminate;
@property (nonatomic, readonly) NSInteger state;
@property (nonatomic, readonly) NSError * _Nullable lastErrorCode;
@property (strong, nonatomic) NSArray * _Nullable subscriptions;
@property (strong, nonatomic) NSString *_Nullable key;

@property (nonatomic) MQTTQosLevel subscriptionQos;

- (void)connectTo:(NSString * _Nonnull)host
             port:(UInt32)port
               ws:(BOOL)ws
              tls:(BOOL)tls
  protocolVersion:(MQTTProtocolVersion)protocolVersion
        keepalive:(NSInteger)keepalive
            clean:(BOOL)clean
             auth:(BOOL)auth
             user:(NSString * _Nullable)user
             pass:(NSString * _Nullable)pass
        willTopic:(NSString * _Nullable)willTopic
             will:(NSData * _Nullable)will
          willQos:(NSInteger)willQos
   willRetainFlag:(BOOL)willRetainFlag
     withClientId:(NSString * _Nullable)clientId
allowUntrustedCertificates:(BOOL)allowUntrustedCertificates
     certificates:(NSArray * _Nullable)certificates;

- (void)connectHTTP:(NSString * _Nullable)url
               auth:(BOOL)auth
               user:(NSString * _Nullable)user
               pass:(NSString * _Nullable)pass
             device:(NSString * _Nonnull)device
        httpHeaders:(NSString *_Nullable)httpHeaders;

- (void)connectToLast;

- (UInt16)sendData:(NSData * _Nullable)data
             topic:(NSString * _Nonnull)topic
        topicAlias:(NSNumber * _Nullable)topicAlias
               qos:(NSInteger)qos
            retain:(BOOL)retainFlag;
- (void)disconnect;
- (void)reset;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * _Nonnull parameters;
@end
