//
//  Settings.m
//  OwnTracks
//
//  Created by Christoph Krey on 31.01.14.
//  Copyright © 2014-2024  Christoph Krey. All rights reserved.
//

#import "Settings.h"
#import "CoreData.h"
#import "OwnTracking.h"
#import "LocationManager.h"
#import <CocoaLumberjack/CocoaLumberjack.h>


@interface SettingsDefaults: NSObject
@property (strong, nonatomic) NSDictionary *mqttDefaults;
@property (strong, nonatomic) NSDictionary *httpDefaults;
@end

static SettingsDefaults *defaults;
static const DDLogLevel ddLogLevel = DDLogLevelInfo;

@implementation SettingsDefaults
+ (SettingsDefaults *)theDefaults {
    if (!defaults) {
        defaults = [[SettingsDefaults alloc] init];
    }
    return defaults;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        NSURL *mqttPlistURL = [[NSBundle mainBundle] URLForResource:@"MQTT"
                                                      withExtension:@"plist"];
        NSURL *httpPlistURL = [[NSBundle mainBundle] URLForResource:@"HTTP"
                                                      withExtension:@"plist"];
        self.mqttDefaults = [NSDictionary dictionaryWithContentsOfURL:mqttPlistURL];
        self.httpDefaults = [NSDictionary dictionaryWithContentsOfURL:httpPlistURL];
    }

    return self;
}

@end

@implementation Settings

+ (NSError *)fromStream:(NSInputStream *)input
                  inMOC:(NSManagedObjectContext *)context {
    NSError *error;
    
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithStream:input
                                                                 options:0
                                                                   error:&error];
    if (dictionary) {
        return [self fromDictionary:dictionary inMOC:context];
    } else {
        return error;
    }
}

+ (NSError *)fromDictionary:(NSDictionary *)dictionary
                      inMOC:(NSManagedObjectContext *)context {
    if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
        for (NSString *key in dictionary.allKeys) {
            NSObject *object = dictionary[key];
            DDLogInfo(@"Configuration %@:%@ (%@)", key, object, object.class);
        }
        
        NSString *type = dictionary[@"_type"];
        if (type && [type isKindOfClass:[NSString class]] && [type isEqualToString:@"configuration"]) {
            NSObject *object;

            ConnectionMode importMode = CONNECTION_MODE_MQTT;
            NSNumber *mode = dictionary[@"mode"];
            if (mode && [mode isKindOfClass:[NSNumber class]]) {
                [self setString:object forKey:@"mode" inMOC:context];
                importMode = mode.intValue;
            } else {
                DDLogError(@"[Settings] fromDictionary invalid mode");
                return [NSError errorWithDomain:@"OwnTracks Settings"
                                           code:1
                                       userInfo:@{@"mode": [NSString stringWithFormat:@"%@", dictionary[@"mode"]]}];
            }

            object = dictionary[@"deviceId"];
            if (object) {
                if ([object isKindOfClass:[NSNull class]]) {
                    [self setString:@"" forKey:@"deviceid_preference" inMOC:context];
                } else if ([object isKindOfClass:[NSString class]]) {
                    [self setString:(NSString *)object forKey:@"deviceid_preference" inMOC:context];
                }
            }
            
            object = dictionary[@"tid"];
            if (object) [self setString:object forKey:@"trackerid_preference" inMOC:context];
            
            object = dictionary[@"clientId"];
            if (object) [self setString:object forKey:@"clientid_preference" inMOC:context];
            
            object = dictionary[@"subTopic"];
            if (object) [self setString:object forKey:@"subscription_preference" inMOC:context];
            
            object = dictionary[@"pubTopicBase"];
            if (object) [self setString:object forKey:@"topic_preference" inMOC:context];
            
            object = dictionary[@"host"];
            if (object) [self setString:object forKey:@"host_preference" inMOC:context];
            
            object = dictionary[@"url"];
            if (object) [self setString:object forKey:@"url_preference" inMOC:context];

            object = dictionary[@"httpHeaders"];
            if (object) [self setString:object forKey:@"httpheaders_preference" inMOC:context];

            object = dictionary[@"encryptionKey"];
            if (object) [self setString:object forKey:@"secret_preference" inMOC:context];

            object = dictionary[@"username"];
            if (object) [self setString:object forKey:@"user_preference" inMOC:context];

            object = dictionary[@"password"];
            if (object) [self setString:object forKey:@"pass_preference" inMOC:context];

            object = dictionary[@"willTopic"];
            if (object) [self setString:object forKey:@"willtopic_preference" inMOC:context];
        
            object = dictionary[@"subQos"];
            if (object) [self setString:object forKey:@"subscriptionqos_preference" inMOC:context];
            
            object = dictionary[@"pubQos"];
            if (object) [self setString:object forKey:@"qos_preference" inMOC:context];
            
            object = dictionary[@"port"];
            if (object) [self setString:object forKey:@"port_preference" inMOC:context];

            object = dictionary[@"mqttProtocolLevel"];
            if (object) [self setString:object forKey:SETTINGS_PROTOCOL inMOC:context];

            object = dictionary[@"ignoreStaleLocations"];
            if (object) [self setString:object forKey:@"ignorestalelocations_preference" inMOC:context];

            object = dictionary[@"ignoreInaccurateLocations"];
            if (object) [self setString:object forKey:@"ignoreinaccuratelocations_preference" inMOC:context];

            object = dictionary[@"keepalive"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"keepalive_preference" inMOC:context];
            
            object = dictionary[@"willQos"];
            if (object) [self setString:object forKey:@"willqos_preference" inMOC:context];
            
            object = dictionary[@"locatorDisplacement"];
            if (object) {
                [self setString:[NSString stringWithFormat:@"%@", object]
                             forKey:@"mindist_preference"
                                      inMOC:context];
                [LocationManager sharedInstance].minDist =
                [Settings doubleForKey:@"mindist_preference"
                              inMOC:context];
            }
            
            object = dictionary[@"locatorInterval"];
            if (object) {
                [self setString:[NSString stringWithFormat:@"%@", object]
                                    forKey:@"mintime_preference"
                                     inMOC:context];
                [LocationManager sharedInstance].minTime =
                [Settings doubleForKey:@"mintime_preference"
                              inMOC:context];
            }
            
            object = dictionary[@"monitoring"];
            if (object) {
                [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
                [self setString:[NSString stringWithFormat:@"%@", object]
                         forKey:@"monitoring_preference"
                          inMOC:context];
                [LocationManager sharedInstance].monitoring =
                [Settings intForKey:@"monitoring_preference"
                              inMOC:context];
            }

            object = dictionary[@"downgrade"];
            if (object) [self setString:object forKey:@"downgrade_preference" inMOC:context];
            
            object = dictionary[@"ranging"];
            if (object) [self setString:object forKey:@"ranging_preference" inMOC:context];
            
            object = dictionary[@"cmd"];
            if (object) [self setString:object forKey:@"cmd_preference" inMOC:context];

            object = dictionary[@"sub"];
            if (object) [self setString:object forKey:@"sub_preference" inMOC:context];

            object = dictionary[@"pubRetain"];
            if (object) [self setString:object forKey:@"retain_preference" inMOC:context];
            
            object = dictionary[@"tls"];
            if (object) [self setString:object forKey:@"tls_preference" inMOC:context];

            object = dictionary[@"ws"];
            if (object) [self setString:object forKey:@"ws_preference" inMOC:context];

            object = dictionary[@"auth"];
            if (object) [self setString:object forKey:@"auth_preference" inMOC:context];

            object = dictionary[@"usePassword"];
            if (object) [self setString:object forKey:@"usepassword_preference" inMOC:context];

            object = dictionary[@"cleanSession"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"clean_preference"
                                  inMOC:context];
            
            object = dictionary[@"willRetain"];
            if (object) [self setString:object forKey:@"willretain_preference" inMOC:context];
            
            object = dictionary[@"positions"];
            if (object) [self setString:object forKey:@"positions_preference" inMOC:context];

            object = dictionary[@"maxHistory"];
            if (object) [self setString:object forKey:@"maxhistory_preference" inMOC:context];

            object = dictionary[@"allowRemoteLocation"];
            if (object) [self setString:object forKey:@"allowremotelocation_preference" inMOC:context];
            
            object = dictionary[@"extendedData"];
            if (object) [self setString:object forKey:@"extendeddata_preference" inMOC:context];
            
            object = dictionary[@"locked"];
            if (object) [self setString:object forKey:@"locked" inMOC:context];
            
            object = dictionary[@"clientpkcs"];
            if (object) [self setString:object forKey:@"clientpkcs" inMOC:context];

            object = dictionary[@"passphrase"];
            if (object) [self setString:object forKey:@"passphrase" inMOC:context];
            
            object = dictionary[@"servercer"];
            if (object) [self setString:object forKey:@"servercer" inMOC:context];
            
            object = dictionary[@"policymode"];
            if (object) [self setString:object forKey:@"policymode" inMOC:context];

            object = dictionary[@"usepolicy"];
            if (object) [self setString:object forKey:@"usepolicy" inMOC:context];
            
            object = dictionary[@"allowinvalidcerts"];
            if (object) [self setString:object forKey:@"allowinvalidcerts" inMOC:context];
            
            object = dictionary[@"validatecertificatechain"];
            if (object) [self setString:object forKey:@"validatecertificatechain" inMOC:context];
            
            object = dictionary[@"validatedomainname"];
            if (object) [self setString:object forKey:@"validatedomainname" inMOC:context];
            
            object = dictionary[@"tid"];
            if (object) [self setString:object forKey:@"trackerid_preference" inMOC:context];
            
            NSArray *waypoints = dictionary[@"waypoints"];
            [self setWaypoints:waypoints inMOC:context];
            
        } else {
            DDLogError(@"[Settings] fromDictionary invalid _type");
            return [NSError errorWithDomain:@"OwnTracks Settings"
                                       code:1
                                   userInfo:@{@"_type": [NSString stringWithFormat:@"%@", dictionary[@"_type"]]}];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"reload" object:nil];
    } else {
        DDLogError(@"[Settings] fromDictionary invalid dictionary");
        return [NSError errorWithDomain:@"OwnTracks Settings"
                                   code:2
                               userInfo:@{}];
    }

    return nil;
}

+ (NSError *)waypointsFromStream:(NSInputStream *)input
                           inMOC:(NSManagedObjectContext *)context  {
    NSError *error;
    
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithStream:input
                                                                 options:0
                                                                   error:&error];
    if (dictionary) {
        return [self waypointsFromDictionary:dictionary inMOC:context];
    } else {
        return error;
    }
}

+ (NSError *)waypointsFromDictionary:(NSDictionary *)dictionary
                               inMOC:(NSManagedObjectContext *)context {
    if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
        for (NSString *key in dictionary.allKeys) {
            DDLogVerbose(@"Waypoints %@:%@", key, dictionary[key]);
        }
        
        if ([dictionary[@"_type"] isEqualToString:@"waypoints"]) {
            NSArray *waypoints = dictionary[@"waypoints"];
            [self setWaypoints:waypoints inMOC:context];
        } else {
            return [NSError errorWithDomain:@"OwnTracks Waypoints"
                                       code:1
                                   userInfo:@{@"_type": dictionary[@"_type"]}];
        }
    }
    return nil;
}

+ (void)setWaypoints:(NSArray *)waypoints
               inMOC:(NSManagedObjectContext *)context {
    if (waypoints) {
        for (NSDictionary *waypoint in waypoints) {
            if ([waypoint[@"_type"] isEqualToString:@"waypoint"]) {
                DDLogVerbose(@"[Settings][setWaypoints] rid:%@ desc:%@ lon:%@ lat:%@, tst:%@",
                             waypoint[@"rid"],
                             waypoint[@"desc"],
                             waypoint[@"lon"],
                             waypoint[@"lat"],
                             waypoint[@"tst"]
                             );

                NSArray *components = [waypoint[@"desc"] componentsSeparatedByString:@":"];
                NSString *name = components.count >= 1 ? components[0] : nil;
                NSString *uuid = components.count >= 2 ? components[1] : nil;
                unsigned int major = components.count >= 3 ? [components[2] unsignedIntValue]: 0;
                unsigned int minor = components.count >= 4 ? [components[3] unsignedIntValue]: 0;

                NSDate *tst = [NSDate dateWithTimeIntervalSince1970:
                               [waypoint[@"tst"] doubleValue]];

                NSString *rid = waypoint[@"rid"];
                if (!rid) {
                    rid = [Region ridFromTst:tst andName:name];
                }

                Friend *friend = [Friend friendWithTopic:[self theGeneralTopicInMOC:context]
                                        inManagedObjectContext:context];

                for (Region *region in friend.hasRegions) {
                    if ([region.getAndFillRid isEqualToString:rid]) {
                        DDLogVerbose(@"[Settings][setWaypoints] removeRegion %@", rid);
                        [[OwnTracking sharedInstance] removeRegion:region context:context];
                        break;
                    }
                }

                CLLocationCoordinate2D coordinate =
                CLLocationCoordinate2DMake([waypoint[@"lat"] doubleValue],
                                           [waypoint[@"lon"] doubleValue]);
                if (CLLocationCoordinate2DIsValid(coordinate)) {
                    DDLogVerbose(@"[Settings][setWaypoints] addRegion desc:%@",
                                 waypoint[@"desc"]);
                    [[OwnTracking sharedInstance] addRegionFor:rid
                                                        friend:friend
                                                          name:name
                                                           tst:tst
                                                          uuid:uuid
                                                         major:major
                                                         minor:minor
                                                        radius:[waypoint[@"rad"] doubleValue]
                                                           lat:[waypoint[@"lat"] doubleValue]
                                                           lon:[waypoint[@"lon"] doubleValue]];
//                } else {
//                    for (Region *region in friend.hasRegions) {
//                        if ([region.name isEqualToString:name]) {
//                            [[OwnTracking sharedInstance] removeRegion:region context:context];
//                            break;
//                        }
//                    }
                }
            }
        }
    }
}

+ (NSError *)clearWaypoints:(NSManagedObjectContext *)context {
    Friend *friend = [Friend friendWithTopic:[self theGeneralTopicInMOC:context]
                            inManagedObjectContext:context];

    for (Region *region in friend.hasRegions) {
            DDLogVerbose(@"[Settings][clearWaypoints] removeRegion %@", region.rid);
            [[OwnTracking sharedInstance] removeRegion:region context:context];
    }
    return nil;
}

+ (NSArray *)waypointsToArrayInMOC:(NSManagedObjectContext *)context {
    NSMutableArray *waypoints = [[NSMutableArray alloc] init];
    Friend *friend = [Friend existsFriendWithTopic:[self theGeneralTopicInMOC:context]
                            inManagedObjectContext:context];
    for (Region *region in friend.hasRegions) {
        [waypoints addObject:[[OwnTracking sharedInstance] regionAsJSON:region]];
    }
    
    return waypoints;
}



+ (NSDictionary *)waypointsToDictionaryInMOC:(NSManagedObjectContext *)context {
    return @{@"_type": @"waypoints", @"waypoints": [self waypointsToArrayInMOC:context]};
}

+ (NSDictionary *)toDictionaryInMOC:(NSManagedObjectContext *)context {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    dict[@"_type"] =                        @"configuration";
    dict[@"mode"] =                         @([Settings intForKey:@"mode" inMOC:context]);
    dict[@"ranging"] =                      @([Settings boolForKey:@"ranging_preference" inMOC:context]);
    dict[@"locked"] =                       @([Settings boolForKey:@"locked" inMOC:context]);
    dict[@"tid"] =                          [Settings stringOrZeroForKey:@"trackerid_preference" inMOC:context];
    dict[@"pubTopicBase"] =                 [Settings stringOrZeroForKey:@"topic_preference" inMOC:context];
    dict[@"monitoring"] =                   @([Settings intForKey:@"monitoring_preference" inMOC:context]);
    dict[@"downgrade"] =                    @([Settings intForKey:@"downgrade_preference" inMOC:context]);
    dict[@"waypoints"] =                    [Settings waypointsToArrayInMOC:context];
    dict[@"positions"] =                    @([Settings intForKey:@"positions_preference" inMOC:context]);
    dict[@"maxHistory"] =                   @([Settings intForKey:@"maxhistory_preference" inMOC:context]);
    dict[@"locatorDisplacement"] =          @([Settings intForKey:@"mindist_preference" inMOC:context]);
    dict[@"locatorInterval"] =              @([Settings intForKey:@"mintime_preference" inMOC:context]);
    dict[@"extendedData"] =                 @([Settings boolForKey:@"extendeddata_preference" inMOC:context]);
    dict[@"ignoreStaleLocations"] =         @([Settings doubleForKey:@"ignorestalelocations_preference" inMOC:context]);
    dict[@"ignoreInaccurateLocations"] =    @([Settings intForKey:@"ignoreinaccuratelocations_preference" inMOC:context]);

    dict[@"deviceId"] =             [Settings stringOrZeroForKey:@"deviceid_preference" inMOC:context];
    dict[@"cmd"] =                  @([Settings boolForKey:@"cmd_preference" inMOC:context]);
    dict[@"allowRemoteLocation"] =  @([Settings boolForKey:@"allowremotelocation_preference" inMOC:context]);
    dict[@"auth"] =                 @([Settings boolForKey:@"auth_preference" inMOC:context]);
    dict[@"usePassword"] =          @([Settings boolForKey:@"usepassword_preference" inMOC:context]);
    dict[@"encryptionKey"] =        [Settings stringOrZeroForKey:@"secret_preference" inMOC:context];
    dict[@"username"] =             [Settings stringOrZeroForKey:@"user_preference" inMOC:context];
    dict[@"password"] =             [Settings stringOrZeroForKey:@"pass_preference" inMOC:context];

    switch ([Settings intForKey:@"mode" inMOC:context]) {
        case CONNECTION_MODE_MQTT:
            dict[@"clientId"] =             [Settings stringOrZeroForKey:@"clientid_preference" inMOC:context];
            dict[@"sub"] =                  @([Settings boolForKey:@"sub_preference" inMOC:context]);
            dict[@"subTopic"] =             [Settings stringOrZeroForKey:@"subscription_preference" inMOC:context];
            dict[@"host"] =                 [Settings stringOrZeroForKey:@"host_preference" inMOC:context];
            dict[@"willTopic"] =            [Settings stringOrZeroForKey:@"willtopic_preference" inMOC:context];
            dict[@"clientpkcs"] =           [Settings stringOrZeroForKey:@"clientpkcs" inMOC:context];
            dict[@"passphrase"] =           [Settings stringOrZeroForKey:@"passphrase" inMOC:context];
            
            dict[@"subQos"] =               @([Settings intForKey:@"subscriptionqos_preference" inMOC:context]);
            dict[@"pubQos"] =               @([Settings intForKey:@"qos_preference" inMOC:context]);
            dict[@"port"] =                 @([Settings intForKey:@"port_preference" inMOC:context]);
            dict[@"mqttProtocolLevel"] =    @([Settings intForKey:SETTINGS_PROTOCOL inMOC:context]);
            dict[@"keepalive"] =            @([Settings intForKey:@"keepalive_preference" inMOC:context]);
            dict[@"willQos"] =              @([Settings intForKey:@"willqos_preference" inMOC:context]);

            dict[@"pubRetain"] =            @([Settings boolForKey:@"retain_preference" inMOC:context]);
            dict[@"tls"] =                  @([Settings boolForKey:@"tls_preference" inMOC:context]);
            dict[@"allowinvalidcerts"] =    @([Settings boolForKey:@"allowinvalidcerts" inMOC:context]);
            dict[@"ws"] =                   @([Settings boolForKey:@"ws_preference" inMOC:context]);
            dict[@"cleanSession"] =         @([Settings boolForKey:@"clean_preference" inMOC:context]);
            dict[@"willRetain"] =           @([Settings boolForKey:@"willretain_preference" inMOC:context]);
            break;

        case CONNECTION_MODE_HTTP:
            dict[@"url"] =                  [Settings stringOrZeroForKey:@"url_preference" inMOC:context];
            dict[@"httpHeaders"] =          [Settings stringOrZeroForKey:@"httpheaders_preference" inMOC:context];
            break;

        default:
            break;
    }
    return dict;
}

+ (NSData *)waypointsToDataInMOC:(NSManagedObjectContext *)context {
    NSDictionary *dict = [Settings waypointsToDictionaryInMOC:context];
    
    NSError *error;
    NSData *myData = [NSJSONSerialization dataWithJSONObject:dict
                                                     options:NSJSONWritingPrettyPrinted
                                                       error:&error];
    return myData;
}

+ (NSData *)toDataInMOC:(NSManagedObjectContext *)context {
    NSDictionary *dict = [self toDictionaryInMOC:context];
    
    NSError *error;
    NSData *myData = [NSJSONSerialization dataWithJSONObject:dict
                                                     options:NSJSONWritingPrettyPrinted
                                                       error:&error];
    return myData;
}

+ (void)setString:(NSObject *)object
           forKey:(NSString *)key
            inMOC:(NSManagedObjectContext *)context {
    if (object && ![object isKindOfClass:[NSNull class]]) {
        Setting *setting = [Setting settingWithKey:key inMOC:context];
        setting.value = [NSString stringWithFormat:@"%@", object];
    } else {
        Setting *setting = [Setting existsSettingWithKey:key inMOC:context];
        if (setting) {
            [context deleteObject:setting];
        }
    }
}

+ (void)setInt:(int)i
        forKey:(NSString *)key
         inMOC:(NSManagedObjectContext *)context {
    [self setString:[NSString stringWithFormat:@"%d", i] forKey:key inMOC:context];
}

+ (void)setDouble:(double)d
           forKey:(NSString *)key
            inMOC:(NSManagedObjectContext *)context {
    [self setString:[NSString stringWithFormat:@"%f", d] forKey:key inMOC:context];
}

+ (void)setBool:(BOOL)b
         forKey:(NSString *)key
          inMOC:(NSManagedObjectContext *)context {
    DDLogVerbose(@"setBoolForKey:%@ = %d", key, b);
    [self setString:[NSString stringWithFormat:@"%d", b] forKey:key inMOC:context];
}

+ (NSString *)stringOrZeroForKey:(NSString *)key
                           inMOC:(NSManagedObjectContext *)context {
    NSString *value = [self stringForKey:key inMOC:context];
    if (!value) {
        DDLogVerbose(@"stringOrZeroForKey %@", key);
        value = @"";
    }
    return value;
}

+ (NSString *)stringForKey:(NSString *)key
                     inMOC:(NSManagedObjectContext *)context {
    return [Settings stringForKeyRaw:key inMOC:context];
}

+ (NSString *)stringForKeyRaw:(NSString *)key
                        inMOC:(NSManagedObjectContext *)context {
    __block NSString *value = nil;
        Setting *setting = [Setting existsSettingWithKey:key inMOC:context];
        if (setting) {
            value = setting.value;
        } else {
            id object = ([SettingsDefaults theDefaults].mqttDefaults)[key];
            if (object) {
                if ([object isKindOfClass:[NSString class]]) {
                    value = (NSString *)object;
                } else if ([object isKindOfClass:[NSNumber class]]) {
                    value = ((NSNumber *)object).stringValue;
                }
            }
        }
    return value;
}

+ (int)intForKey:(NSString *)key
           inMOC:(NSManagedObjectContext *)context {
    return [self stringForKey:key inMOC:context].intValue;
}

+ (double)doubleForKey:(NSString *)key
                 inMOC:(NSManagedObjectContext *)context {
    return [self stringForKey:key inMOC:context].doubleValue;
}

+ (BOOL)boolForKey:(NSString *)key
             inMOC:(NSManagedObjectContext *)context {
    NSString *value = [self stringForKey:key inMOC:context];
    DDLogVerbose(@"boolForKey:%@ = %@", key, value);
    return value.boolValue;
}


+ (NSString *)theGeneralTopicInMOC:(NSManagedObjectContext *)context {
    NSString *topic = [self stringForKey:@"topic_preference" inMOC:context];
            
    if (!topic || [topic isEqualToString:@""]) {
        NSString *userId = [self theUserIdInMOC:context];
        NSString *deviceId = [self theDeviceIdInMOC:context];

        if (!userId || [userId isEqualToString:@""]) {
            userId = @"user";
        }
        if (!deviceId || [deviceId isEqualToString:@""]) {
            deviceId = @"device";
        }

        topic = [NSString stringWithFormat:@"owntracks/%@/%@", userId, deviceId];
    } else {
        topic = [topic stringByReplacingOccurrencesOfString:@"%u"
                                                 withString:[Settings theUserIdInMOC:context]];
        topic = [topic stringByReplacingOccurrencesOfString:@"%d"
                                                 withString:[Settings theDeviceIdInMOC:context]];
    }
    return topic;
}

+ (NSString *)theWillTopicInMOC:(NSManagedObjectContext *)context {
    NSString *topic = [self stringForKey:@"willtopic_preference" inMOC:context];
    
    if (!topic || [topic isEqualToString:@""]) {
        topic = [self theGeneralTopicInMOC:context];
    } else {
        topic = [topic stringByReplacingOccurrencesOfString:@"%u"
                                                 withString:[Settings theUserIdInMOC:context]];
        topic = [topic stringByReplacingOccurrencesOfString:@"%d"
                                                 withString:[Settings theDeviceIdInMOC:context]];
    }

    return topic;
}

+ (NSString *)theClientIdInMOC:(NSManagedObjectContext *)context {
    NSString *clientId;
    clientId = [self stringForKey:@"clientid_preference" inMOC:context];
    
    if (!clientId || [clientId isEqualToString:@""]) {
        clientId = [self theIdInMOC:context];
    }
    return clientId;
}

+ (NSString *)theIdInMOC:(NSManagedObjectContext *)context {
    NSString *theId;
    
    NSString *userId = [self theUserIdInMOC:context];
    NSString *deviceId = [self theDeviceIdInMOC:context];

    if (!userId || [userId isEqualToString:@""]) {
        if (!deviceId || [deviceId isEqualToString:@""]) {
            theId = [UIDevice currentDevice].name;
        } else {
            theId = deviceId;
        }
    } else {
        if (!deviceId || [deviceId isEqualToString:@""]) {
            theId = userId;
        } else {
            theId = [NSString stringWithFormat:@"%@%@",
                     userId,
                     deviceId];
        }
    }
    NSCharacterSet *allowed = [NSCharacterSet alphanumericCharacterSet];
    NSCharacterSet *notAllowed = allowed.invertedSet;
    theId = [[theId componentsSeparatedByCharactersInSet:notAllowed]
             componentsJoinedByString:@""];

    return theId;
}

+ (NSString *)theDeviceIdInMOC:(NSManagedObjectContext *)context {
    NSString *deviceId = [self stringForKey:@"deviceid_preference" inMOC:context];
    if (!deviceId || deviceId.length == 0) {
        deviceId = ([UIDevice currentDevice].identifierForVendor).UUIDString;
    }
    return deviceId;
}

+ (NSString *)theSubscriptionsInMOC:(NSManagedObjectContext *)context {
    NSString *subscriptions = [self stringForKey:@"subscription_preference" inMOC:context];

    if (!subscriptions || subscriptions.length == 0) {
        NSArray *baseComponents = [[self theGeneralTopicInMOC:context] componentsSeparatedByString:@"/"];

        NSString *anyDevice = @"";
        int any = 1;
        NSString *firstString = nil;
        if (baseComponents.count > 0) {
            firstString = baseComponents[0];
        }
        if (firstString && firstString.length == 0) {
            any++;
        }

        for (int i = 0; i < any; i++) {
            if (i > 0) {
                anyDevice = [anyDevice stringByAppendingString:@"/"];
            }
            anyDevice = [anyDevice stringByAppendingString:baseComponents[i]];
        }

        for (int i = any; i < baseComponents.count; i++) {
            if (i > 0) {
                anyDevice = [anyDevice stringByAppendingString:@"/"];
            }
            anyDevice = [anyDevice stringByAppendingString:@"+"];
        }

        subscriptions = [NSString stringWithFormat:@"%@ %@/event %@/info %@/cmd",
                         anyDevice,
                         anyDevice,
                         anyDevice,
                         [self theGeneralTopicInMOC:context]];
    }
    NSString *userId = [Settings theUserIdInMOC:context];
    if (userId) {
        subscriptions = [subscriptions stringByReplacingOccurrencesOfString:@"%u"
                                                                 withString:userId];
    }
    NSString *deviceId = [Settings theDeviceIdInMOC:context];
    if (deviceId) {
        subscriptions = [subscriptions stringByReplacingOccurrencesOfString:@"%d"
                                                                 withString:deviceId];
    }

    return subscriptions;
}

+ (NSString *)theUserIdInMOC:(NSManagedObjectContext *)context {
    return [self stringForKey:@"user_preference" inMOC:context];
}

+ (NSString *)theHostInMOC:(NSManagedObjectContext *)context {
    int mode = [self intForKey:@"mode" inMOC:context];
    switch (mode) {
        case CONNECTION_MODE_HTTP: {
            NSURL *url = [NSURL URLWithString:[self stringForKey:@"url_preference" inMOC:context]];
            NSString *host = url.host;
            return host ? host : @"host";
            break;
        }

        case CONNECTION_MODE_MQTT:
        default:
            return [self stringForKey:@"host_preference" inMOC:context];
            break;
    }
}

+ (NSString *)theMqttUserInMOC:(NSManagedObjectContext *)context {
    return [self stringForKey:@"user_preference" inMOC:context];
}

+ (NSString *)theMqttPassInMOC:(NSManagedObjectContext *)context {
    return [self stringForKey:@"pass_preference" inMOC:context];
}

+ (BOOL)theMqttUsePasswordInMOC:(NSManagedObjectContext *)context {
    return [self boolForKey:@"usepassword_preference" inMOC:context];
}

+ (BOOL)theLockedInMOC:(NSManagedObjectContext *)context {
    return [self boolForKey:@"locked" inMOC:context];
}

+ (BOOL)theMqttAuthInMOC:(NSManagedObjectContext *)context {
    return [self boolForKey:@"auth_preference" inMOC:context];
}

+ (int)theMaximumHistoryInMOC:(NSManagedObjectContext *)context {
    return [self intForKey:@"maxhistory_preference" inMOC:context];
}

+ (BOOL)validIdsInMOC:(NSManagedObjectContext *)context {
    NSString *user = [self theUserIdInMOC:context];
    NSString *device = [self theDeviceIdInMOC:context];
    
    return (user && user.length != 0 && device && device.length != 0);
}

+ (instancetype)sharedInstance {
    static dispatch_once_t once = 0;
    static id sharedInstance = nil;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    return self;
}

@end

