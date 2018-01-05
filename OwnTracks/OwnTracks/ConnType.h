//
//  ConnType.h
//  OwnTracks
//
//  Created by Christoph Krey on 05.10.16.
//  Copyright © 2016-2018 OwnTracks. All rights reserved.
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
+ (ConnectionType)connectionType:(NSString *)host;
@end
