//
//  Settings.h
//  OwnTracks
//
//  Created by Christoph Krey on 31.01.14.
//  Copyright (c) 2014-2015 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Setting+Create.h"

@interface Settings : NSObject
- (NSError *)fromStream:(NSInputStream *)input;
- (NSError *)waypointsFromStream:(NSInputStream *)input;
- (NSData *)toData;
- (NSDictionary *)toDictionary;

- (NSString *)stringForKey:(NSString *)key;
- (int)intForKey:(NSString *)key;
- (double)doubleForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;

- (void)setString:(NSString *)string forKey:(NSString *)key;
- (void)setInt:(int)i forKey:(NSString *)key;
- (void)setDouble:(double)d forKey:(NSString *)key;
- (void)setBool:(BOOL)b forKey:(NSString *)key;

- (NSString *)theGeneralTopic;
- (NSString *)theWillTopic;
- (NSString *)theClientId;
- (NSString *)theDeviceId;
- (NSString *)theUserId;
- (NSString *)theSubscriptions;

- (BOOL)validInPublicMode:(NSString *)key;
- (BOOL)validInHostedMode:(NSString *)key;

@end
