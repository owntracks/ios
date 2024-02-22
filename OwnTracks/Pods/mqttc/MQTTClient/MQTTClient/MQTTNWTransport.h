//
//  MQTTNWTransport.h
//  MQTTClient
//
//  Created by Christoph Krey on 01.10.19.
//  Copyright © 2019-2022 Christoph Krey. All rights reserved.
//

#import <mqttc/MQTTTransport.h>
#import <Network/Network.h>

NS_ASSUME_NONNULL_BEGIN

@interface MQTTNWTransport : MQTTTransport <MQTTTransport, NSURLSessionDelegate, NSURLSessionStreamDelegate, NSURLSessionTaskDelegate>

/** tls a boolean indicating whether the transport should be using websocket protocol
 * defaults to NO
 */
@property (nonatomic) BOOL ws;

@end

NS_ASSUME_NONNULL_END
