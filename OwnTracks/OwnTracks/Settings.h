//
//  Settings.h
//  OwnTracks
//
//  Created by Christoph Krey on 31.01.14.
//  Copyright © 2014-2016 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Setting+Create.h"

#define SETTINGS_MESSAGING @"messaging"
#define SETTINGS_ACTION @"action"
#define SETTINGS_ACTIONURL @"actionurl"

@interface Settings : NSObject

+ (NSError *)fromStream:(NSInputStream *)input;
+ (NSError *)fromDictionary:(NSDictionary *)dictionary;
+ (NSError *)waypointsFromStream:(NSInputStream *)input;
+ (NSError *)waypointsFromDictionary:(NSDictionary *)dictionary;
+ (NSData *)toData;
+ (NSData *)waypointsToData;
+ (NSDictionary *)waypointsToDictionary;
+ (NSDictionary *)toDictionary;

+ (NSString *)stringForKey:(NSString *)key;
+ (int)intForKey:(NSString *)key;
+ (double)doubleForKey:(NSString *)key;
+ (BOOL)boolForKey:(NSString *)key;

+ (void)setString:(NSString *)string forKey:(NSString *)key;
+ (void)setInt:(int)i forKey:(NSString *)key;
+ (void)setDouble:(double)d forKey:(NSString *)key;
+ (void)setBool:(BOOL)b forKey:(NSString *)key;

+ (NSString *)theGeneralTopic;
+ (NSString *)theWillTopic;
+ (NSString *)theClientId;
+ (NSString *)theDeviceId;
+ (NSString *)theUserId;
+ (NSString *)theSubscriptions;

+ (NSString *)theMqttUser;
+ (NSString *)theMqttPass;
+ (BOOL)theMqttAuth;

+ (BOOL)validInPublicMode:(NSString *)key;
+ (BOOL)validInHostedMode:(NSString *)key;

+ (BOOL)validIds;

@end
