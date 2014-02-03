//
//  Connection.h
//  OwnTracks
//
//  Created by Christoph Krey on 25.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MQTTClient/MQTTClient.h>
@protocol ConnectionDelegate <NSObject>

enum state {
    state_starting,
    state_connecting,
    state_error,
    state_connected,
    state_closing,
    state_closed
};

- (void)showState:(NSInteger)state;
- (void)handleMessage:(NSData *)data onTopic:(NSString *)topic;
- (void)messageDelivered:(UInt16)msgID;
- (void)totalBuffered:(NSUInteger)count;

@end

@interface Connection: NSObject <MQTTSessionDelegate>

@property (weak, nonatomic) id<ConnectionDelegate> delegate;
@property (nonatomic, readonly) NSInteger state;
@property (nonatomic, readonly) NSError *lastErrorCode;

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
     withClientId:(NSString *)clientId;

- (void)connectToLast;

- (UInt16)sendData:(NSData *)data topic:(NSString *)topic qos:(NSInteger)qos retain:(BOOL)retainFlag;
- (void)disconnect;

- (NSString *)url;
+ (NSString *)dataToString:(NSData *)data;

@end
