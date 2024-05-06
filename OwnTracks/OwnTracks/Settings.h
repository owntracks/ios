//
//  Settings.h
//  OwnTracks
//
//  Created by Christoph Krey on 31.01.14.
//  Copyright © 2014-2024  Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Setting+CoreDataClass.h"
#import "MQTTMessage.h"

#define SETTINGS_ACTION @"action"
#define SETTINGS_ACTIONURL @"actionurl"
#define SETTINGS_ACTIONEXTERN @"actionextern"
#define SETTINGS_PROTOCOL @"mqttProtocolLevel"

typedef NS_ENUM(int, ConnectionMode) {
    CONNECTION_MODE_MQTT = 0,
    CONNECTION_MODE_HTTP = 3
};

@interface Settings : NSObject

+ (NSError * _Nullable)fromStream:(NSInputStream * _Nonnull)input
                            inMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSError * _Nullable)fromDictionary:(NSDictionary * _Nonnull)dictionary
                                inMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSError * _Nullable)waypointsFromStream:(NSInputStream * _Nonnull)input
                                     inMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSError * _Nullable)waypointsFromDictionary:(NSDictionary * _Nonnull)dictionary
                                         inMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSError * _Nullable)clearWaypoints:(NSManagedObjectContext * _Nonnull)context;
+ (NSData * _Nonnull)toDataInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSData * _Nonnull)waypointsToDataInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSDictionary * _Nonnull)waypointsToDictionaryInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSDictionary * _Nonnull)toDictionaryInMOC:(NSManagedObjectContext * _Nonnull)context;

+ (NSString * _Nullable)stringForKey:(NSString * _Nonnull)key 
                               inMOC:(NSManagedObjectContext * _Nonnull)context;
+ (int)intForKey:(NSString * _Nonnull)key
           inMOC:(NSManagedObjectContext * _Nonnull)context;
+ (double)doubleForKey:(NSString * _Nonnull)key
                 inMOC:(NSManagedObjectContext * _Nonnull)context;
+ (BOOL)boolForKey:(NSString * _Nonnull)key
             inMOC:(NSManagedObjectContext * _Nonnull)context;

+ (void)setString:(NSObject  * _Nullable )object 
           forKey:(NSString * _Nonnull)key
            inMOC:(NSManagedObjectContext * _Nonnull)context;
+ (void)setInt:(int)i 
        forKey:(NSString *_Nonnull)key
         inMOC:(NSManagedObjectContext *_Nonnull)context;
+ (void)setDouble:(double)d 
           forKey:(NSString *_Nonnull)key
            inMOC:(NSManagedObjectContext *_Nonnull)context;
+ (void)setBool:(BOOL)b
         forKey:(NSString *_Nonnull)key 
          inMOC:(NSManagedObjectContext *_Nonnull)context;

+ (NSString * _Nonnull)theHostInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSString * _Nonnull)theGeneralTopicInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSString * _Nonnull)theWillTopicInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSString * _Nonnull)theClientIdInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSString * _Nonnull)theDeviceIdInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSString * _Nullable)theUserIdInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSString * _Nonnull)theSubscriptionsInMOC:(NSManagedObjectContext * _Nonnull)context;

+ (NSString * _Nullable)theMqttUserInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSString * _Nullable)theMqttPassInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (BOOL)theMqttUsePasswordInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (BOOL)theMqttAuthInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (BOOL)theLockedInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (MQTTQosLevel)theWillQosInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (BOOL)theWillRetainFlagInMOC:(NSManagedObjectContext * _Nonnull)context;

+ (int)theMaximumHistoryInMOC:(NSManagedObjectContext * _Nonnull)context;

+ (NSString * _Nullable)theOSMTemplate:(NSManagedObjectContext * _Nonnull)context;
+ (void)setOSMTemplate:(NSString * _Nullable)osmTemplate inMOC:(NSManagedObjectContext * _Nonnull)context;

+ (NSString * _Nullable)theOSMCopyrightInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (void)setOSMCopyright:(NSString * _Nullable)osmCopyright inMOC:(NSManagedObjectContext * _Nonnull)context;

+ (BOOL)validIdsInMOC:(NSManagedObjectContext * _Nonnull)context;

+ (Settings * _Nonnull)sharedInstance;

@end




