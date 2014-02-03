//
//  Settings.h
//  OwnTracks
//
//  Created by Christoph Krey on 31.01.14.
//  Copyright (c) 2014 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Settings : NSUserDefaults
- (NSError *)fromStream:(NSInputStream *)input;
- (NSData *)toData;

- (NSString *)theGeneralTopic;
- (NSString *)theWillTopic;
- (NSString *)theClientId;
- (NSString *)theDeviceId;

@end
