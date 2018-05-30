//
//  Settings.h
//  OwnTracks
//
//  Created by Christoph Krey on 31.01.14.
//  Copyright © 2014-2018 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Setting+CoreDataClass.h"
#import "MQTTMessage.h"

#define SETTINGS_ACTION @"action"
#define SETTINGS_ACTIONURL @"actionurl"
#define SETTINGS_ACTIONEXTERN @"actionextern"
#define SETTINGS_ADDRESSBOOK @"ab_preference"
#define SETTINGS_PROTOCOL @"mqttProtocolLevel"

typedef NS_ENUM(int, ConnectionMode) {
    CONNECTION_MODE_MQTT = 0,
    CONNECTION_MODE_HTTP = 3
};

@interface Settings : NSObject

+ (NSError *)fromStream:(NSInputStream *)input inMOC:(NSManagedObjectContext *)context;
+ (NSError *)fromDictionary:(NSDictionary *)dictionary inMOC:(NSManagedObjectContext *)context;
+ (NSError *)waypointsFromStream:(NSInputStream *)input inMOC:(NSManagedObjectContext *)context;
+ (NSError *)waypointsFromDictionary:(NSDictionary *)dictionary inMOC:(NSManagedObjectContext *)context;
+ (NSData *)toDataInMOC:(NSManagedObjectContext *)context;
+ (NSData *)waypointsToDataInMOC:(NSManagedObjectContext *)context;
+ (NSDictionary *)waypointsToDictionaryInMOC:(NSManagedObjectContext *)context;
+ (NSDictionary *)toDictionaryInMOC:(NSManagedObjectContext *)context;

+ (NSString *)stringForKey:(NSString *)key inMOC:(NSManagedObjectContext *)context;
+ (int)intForKey:(NSString *)key inMOC:(NSManagedObjectContext *)context;
+ (double)doubleForKey:(NSString *)key inMOC:(NSManagedObjectContext *)context;
+ (BOOL)boolForKey:(NSString *)key inMOC:(NSManagedObjectContext *)context;

+ (void)setString:(NSObject *)object forKey:(NSString *)key inMOC:(NSManagedObjectContext *)context;
+ (void)setInt:(int)i forKey:(NSString *)key inMOC:(NSManagedObjectContext *)context;
+ (void)setDouble:(double)d forKey:(NSString *)key inMOC:(NSManagedObjectContext *)context;
+ (void)setBool:(BOOL)b forKey:(NSString *)key inMOC:(NSManagedObjectContext *)context;

+ (NSString *)theHostInMOC:(NSManagedObjectContext *)context;
+ (NSString *)theGeneralTopicInMOC:(NSManagedObjectContext *)context;
+ (NSString *)theWillTopicInMOC:(NSManagedObjectContext *)context;
+ (NSString *)theClientIdInMOC:(NSManagedObjectContext *)context;
+ (NSString *)theDeviceIdInMOC:(NSManagedObjectContext *)context;
+ (NSString *)theUserIdInMOC:(NSManagedObjectContext *)context;
+ (NSString *)theSubscriptionsInMOC:(NSManagedObjectContext *)context;

+ (NSString *)theMqttUserInMOC:(NSManagedObjectContext *)context;
+ (NSString *)theMqttPassInMOC:(NSManagedObjectContext *)context;
+ (BOOL)theMqttAuthInMOC:(NSManagedObjectContext *)context;

+ (BOOL)validKey:(NSString *)key inMode:(ConnectionMode)mode;

+ (BOOL)validIdsInMOC:(NSManagedObjectContext *)context;

+ (Settings *)sharedInstance;

@end




