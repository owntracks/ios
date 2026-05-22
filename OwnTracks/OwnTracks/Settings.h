//
//  Settings.h
//  OwnTracks
//
//  Created by Christoph Krey on 31.01.14.
//  Copyright © 2014-2025  Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Setting+CoreDataClass.h"

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
/// Removes all persisted `Setting` rows so every preference reads from bundled `MQTT.plist` / `HTTP.plist` defaults. Refreshes `LocationManager` monitoring/ranging/locator limits from those defaults.
+ (void)resetStoredPreferencesToBundledDefaultsInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSData * _Nonnull)toDataInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSData * _Nonnull)waypointsToDataInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSDictionary * _Nonnull)waypointsToDictionaryInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (NSDictionary * _Nonnull)toDictionaryInMOC:(NSManagedObjectContext * _Nonnull)context;

+ (NSString * _Nullable)stringForKey:(NSString * _Nonnull)key 
                               inMOC:(NSManagedObjectContext * _Nonnull)context;
/// Stored value when non-empty; otherwise bundled `HTTP.plist` / `MQTT.plist` default for `key`.
+ (NSString * _Nonnull)stringForKeyUsingPlistDefaultWhenEmpty:(NSString * _Nonnull)key
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
+ (NSInteger)theWillQosInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (BOOL)theWillRetainFlagInMOC:(NSManagedObjectContext * _Nonnull)context;

+ (int)theMaximumHistoryInMOC:(NSManagedObjectContext * _Nonnull)context;

+ (NSString * _Nullable)theOSMTemplate:(NSManagedObjectContext * _Nonnull)context;
+ (void)setOSMTemplate:(NSString * _Nullable)osmTemplate inMOC:(NSManagedObjectContext * _Nonnull)context;

+ (NSString * _Nullable)theOSMCopyrightInMOC:(NSManagedObjectContext * _Nonnull)context;
+ (void)setOSMCopyright:(NSString * _Nullable)osmCopyright inMOC:(NSManagedObjectContext * _Nonnull)context;

+ (BOOL)validIdsInMOC:(NSManagedObjectContext * _Nonnull)context;

/// UserDefaults-backed flag: after reset / migration, embedded WebView sends `needs_provision=1` until cleared.
+ (void)setNeedsWebProvisioning:(BOOL)needs;
+ (BOOL)userDefaultsIndicatesNeedsWebProvisioning;
/// Placeholder broker host (`host` or empty) from Core Data + plist defaults.
+ (BOOL)legacyBrokerHostIndicatesNeedsWebProvisioningInMOC:(NSManagedObjectContext * _Nonnull)moc;
/// YES if the UserDefaults flag is set OR legacy placeholder host applies (used for embedded URL query).
+ (BOOL)appEmbeddedWebShouldRequestProvisioningInMOC:(NSManagedObjectContext * _Nonnull)moc;
/// One-time migration for upgrades: initialize the UserDefaults flag from legacy host semantics.
+ (void)migrateWebProvisioningFlagIfNeededInMOC:(NSManagedObjectContext * _Nonnull)moc;
/// After `fromDictionary` succeeds, clears the flag when `dictionary` has `_type` == `configuration`.
+ (void)markWebProvisioningSatisfiedAfterApplyingConfigurationDictionary:(NSDictionary * _Nonnull)dictionary
                                                                    error:(NSError * _Nullable)error;
/// One-line summary for logs: UserDefaults flag, legacy placeholder host, and `theHostInMOC`.
+ (NSString * _Nonnull)webProvisioningDebugSummaryInMOC:(NSManagedObjectContext * _Nonnull)moc;

/// Validates JSON from `POST /api/config/provision` before applying. Identity must be server-issued and unambiguous; returns nil if OK.
+ (NSError * _Nullable)validationErrorForRemoteProvisionConfiguration:(NSDictionary * _Nonnull)payload
                                                               inMOC:(NSManagedObjectContext * _Nonnull)moc;

/// When provision JSON fails `validationErrorForRemoteProvisionConfiguration:`, rewrite identity fields (`username`, `deviceId`, `clientId`, `tid`) for client-side compatibility. Does not change `pubTopicBase` so the backend publish topic remains unchanged (no server change required for topic).
+ (void)applyLocalProvisionIdentityRepairToMutableConfiguration:(NSMutableDictionary * _Nonnull)payload
                                                         inMOC:(NSManagedObjectContext * _Nonnull)moc;

/// If `deviceId` is suspect but `pubTopicBase` ends with a non-suspect segment, set `deviceId` to that segment so validation matches the configured topic (server sometimes echoes a display name).
+ (void)applyCanonicalDeviceIdFromPubTopicTailIfDeviceIdSuspectToMutableConfiguration:(NSMutableDictionary * _Nonnull)payload;

+ (Settings * _Nonnull)sharedInstance;

@end




