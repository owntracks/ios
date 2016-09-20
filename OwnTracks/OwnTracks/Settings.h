//
//  Settings.h
//  OwnTracks
//
//  Created by Christoph Krey on 31.01.14.
//  Copyright © 2014-2016 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Setting.h"

#define SETTINGS_ACTION @"action"
#define SETTINGS_ACTIONURL @"actionurl"
#define SETTINGS_ACTIONEXTERN @"actionextern"

typedef NS_ENUM(int, ConnectionMode) {
    CONNECTION_MODE_PRIVATE = 0,
    CONNECTION_MODE_HOSTED = 1,
    CONNECTION_MODE_PUBLIC = 2,
    CONNECTION_MODE_HTTP = 3,
    CONNECTION_MODE_WATSON = 4,
    CONNECTION_MODE_WATSONREGISTERED = 5
};

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

+ (NSString *)theHost;
+ (NSString *)theGeneralTopic;
+ (NSString *)theWillTopic;
+ (NSString *)theClientId;
+ (NSString *)theDeviceId;
+ (NSString *)theUserId;
+ (NSString *)theSubscriptions;

+ (NSString *)theMqttUser;
+ (NSString *)theMqttPass;
+ (BOOL)theMqttAuth;

+ (BOOL)validKey:(NSString *)key inMode:(ConnectionMode)mode;

+ (BOOL)validIds;

@end




