//
//  ConnType.h
//  OwnTracks
//
//  Created by Christoph Krey on 05.10.16.
//  Copyright © 2016-2022  OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Enumeration of MQTTSession states
 */
typedef NS_ENUM(NSInteger, ConnectionType) {
    ConnectionTypeUnknown,
    ConnectionTypeNone,
    ConnectionTypeWWAN,
    ConnectionTypeWIFI
};

@interface ConnType : NSObject
+ (NSString *)SSID;
+ (NSString *)BSSID;
+ (ConnectionType)connectionType:(NSString *)host;
@end
