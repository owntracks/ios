//
//  Settings.m
//  OwnTracks
//
//  Created by Christoph Krey on 31.01.14.
//  Copyright © 2014-2017 Christoph Krey. All rights reserved.
//

#import "Settings.h"
#import "CoreData.h"
#import "OwnTracking.h"
#import <CocoaLumberjack/CocoaLumberjack.h>


@interface SettingsDefaults: NSObject
@property (strong, nonatomic) NSDictionary *appDefaults;
@property (strong, nonatomic) NSDictionary *publicDefaults;
@property (strong, nonatomic) NSDictionary *hostedDefaults;
@property (strong, nonatomic) NSDictionary *httpDefaults;
@property (strong, nonatomic) NSDictionary *watsonDefaults;
@property (strong, nonatomic) NSDictionary *watsonRegisteredDefaults;
@end

static SettingsDefaults *defaults;
static const DDLogLevel ddLogLevel = DDLogLevelWarning;

@implementation SettingsDefaults
+ (SettingsDefaults *)theDefaults {
    if (!defaults) {
        defaults = [[SettingsDefaults alloc] init];
    }
    return defaults;
}

- (id)init {
    self = [super init];

    if (self) {
        NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];
        NSURL *settingsPlistURL = [bundleURL URLByAppendingPathComponent:@"Settings.plist"];
        NSURL *publicPlistURL = [bundleURL URLByAppendingPathComponent:@"Public.plist"];
        NSURL *httpPlistURL = [bundleURL URLByAppendingPathComponent:@"HTTP.plist"];
        NSURL *hostedPlistURL = [bundleURL URLByAppendingPathComponent:@"Hosted.plist"];
        NSURL *watsonPlistURL = [bundleURL URLByAppendingPathComponent:@"Watson.plist"];
        NSURL *watsonRegisteredPlistURL = [bundleURL URLByAppendingPathComponent:@"WatsonRegistered.plist"];

        self.appDefaults = [NSDictionary dictionaryWithContentsOfURL:settingsPlistURL];
        self.publicDefaults = [NSDictionary dictionaryWithContentsOfURL:publicPlistURL];
        self.hostedDefaults = [NSDictionary dictionaryWithContentsOfURL:hostedPlistURL];
        self.httpDefaults = [NSDictionary dictionaryWithContentsOfURL:httpPlistURL];
        self.watsonDefaults = [NSDictionary dictionaryWithContentsOfURL:watsonPlistURL];
        self.watsonRegisteredDefaults = [NSDictionary dictionaryWithContentsOfURL:watsonRegisteredPlistURL];
    }

    return self;
}

@end

@implementation Settings

+ (NSError *)fromStream:(NSInputStream *)input {
    NSError *error;
    
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithStream:input
                                                                 options:0
                                                                   error:&error];
    if (dictionary) {
        return [self fromDictionary:dictionary];
    } else {
        return error;
    }
}

+ (NSError *)fromDictionary:(NSDictionary *)dictionary {
    if (dictionary) {
        for (NSString *key in [dictionary allKeys]) {
            DDLogVerbose(@"Configuration %@:%@", key, dictionary[key]);
        }
        
        if ([dictionary[@"_type"] isEqualToString:@"configuration"]) {
            NSObject *object;

            // Language replacements
            for (NSString *key in [dictionary allKeys]) {
                if ([key rangeOfString:@"pl"].location == 0) {
                    object = dictionary[key];
                    if (object) [self setString:object forKey:key];
                }
            }

            ConnectionMode importMode = CONNECTION_MODE_PRIVATE;
            object = dictionary[@"mode"];
            if (object) {
                [self setString:object forKey:@"mode"];
                if ([object respondsToSelector:@selector(intValue)]) {
                    importMode = (int)[object performSelector:@selector(intValue)];
                }
            }

            object = dictionary[@"deviceId"];
            if (object) {
                switch (importMode) {
                    case CONNECTION_MODE_PRIVATE:
                        if ([object isKindOfClass:[NSNull class]]) {
                            [self  setString:@"" forKey:@"deviceid_preference"];
                        } else if ([object isKindOfClass:[NSString class]]) {
                            [self setString:(NSString *)object forKey:@"deviceid_preference"];
                        }
                        break;
                    case CONNECTION_MODE_HOSTED:
                        if ([object isKindOfClass:[NSNull class]]) {
                            [self  setString:@"" forKey:@"device"];
                        } else if ([object isKindOfClass:[NSString class]]) {
                            [self setString:(NSString *)object forKey:@"device"];
                        }
                        break;
                    default:
                        break;
                }
            }
            
            object = dictionary[@"tid"];
            if (object) [self setString:object forKey:@"trackerid_preference"];
            
            object = dictionary[@"clientId"];
            if (object) [self setString:object forKey:@"clientid_preference"];
            
            object = dictionary[@"subTopic"];
            if (object) [self setString:object forKey:@"subscription_preference"];
            
            object = dictionary[@"pubTopicBase"];
            if (object) [self setString:object forKey:@"topic_preference"];
            
            object = dictionary[@"host"];
            if (object) [self setString:object forKey:@"host_preference"];
            
            object = dictionary[@"url"];
            if (object) [self setString:object forKey:@"url_preference"];

            object = dictionary[@"quickstartId"];
            if (object) [self setString:object forKey:@"quickstartid_preference"];

            object = dictionary[@"watsonOrganization"];
            if (object) [self setString:object forKey:@"watsonorganization_preference"];

            object = dictionary[@"watsonDeviceType"];
            if (object) [self setString:object forKey:@"watsondevicetype_preference"];

            object = dictionary[@"watsonDeviceId"];
            if (object) [self setString:object forKey:@"watsondeviceid_preference"];

            object = dictionary[@"watsonAuthToken"];
            if (object) [self setString:object forKey:@"watsonauthtoken_preference"];

            object = dictionary[@"username"];
            if (object) {
                switch (importMode) {
                    case CONNECTION_MODE_PRIVATE:
                        [self setString:object forKey:@"user_preference"];
                        break;
                    case CONNECTION_MODE_HOSTED:
                        [self setString:object forKey:@"user"];
                        break;
                    default:
                        break;
                }
            }
            
            object = dictionary[@"password"];
            if (object) {
                switch (importMode) {
                    case CONNECTION_MODE_PRIVATE:
                        [self setString:object forKey:@"pass_preference"];
                        break;
                    case CONNECTION_MODE_HOSTED:
                        [self setString:object forKey:@"token"];
                        break;
                    default:
                        break;
                }
            }

            object = dictionary[@"willTopic"];
            if (object) [self setString:object forKey:@"willtopic_preference"];
        
            object = dictionary[@"subQos"];
            if (object) [self setString:object forKey:@"subscriptionqos_preference"];
            
            object = dictionary[@"pubQos"];
            if (object) [self setString:object forKey:@"qos_preference"];
            
            object = dictionary[@"port"];
            if (object) [self setString:object forKey:@"port_preference"];

            object = dictionary[@"mqttProtocolLevel"];
            if (object) [self setString:object forKey:@"mqttProtocolLevel"];

            object = dictionary[@"ignoreStaleLocations"];
            if (object) [self setString:object forKey:@"ignorestalelocations_preference"];

            object = dictionary[@"ignoreInaccurateLocations"];
            if (object) [self setString:object forKey:@"ignoreinaccuratelocations_preference"];

            object = dictionary[@"keepalive"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"keepalive_preference"];
            
            object = dictionary[@"willQos"];
            if (object) [self setString:object forKey:@"willqos_preference"];
            
            object = dictionary[@"locatorDisplacement"];
            if (object) [self setString:object forKey:@"mindist_preference"];
            
            object = dictionary[@"locatorInterval"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"mintime_preference"];
            
            object = dictionary[@"monitoring"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"monitoring_preference"];
            
            object = dictionary[@"ranging"];
            if (object) [self setString:object forKey:@"ranging_preference"];
            
            object = dictionary[@"cmd"];
            if (object) [self setString:object forKey:@"cmd_preference"];

            object = dictionary[@"sub"];
            if (object) [self setString:object forKey:@"sub_preference"];


            object = dictionary[@"pubRetain"];
            if (object) [self setString:object forKey:@"retain_preference"];
            
            object = dictionary[@"tls"];
            if (object) [self setString:object forKey:@"tls_preference"];

            object = dictionary[@"ws"];
            if (object) [self setString:object forKey:@"ws_preference"];

            object = dictionary[@"auth"];
            if (object) [self setString:object forKey:@"auth_preference"];
            
            object = dictionary[@"cleanSession"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"clean_preference"];
            
            object = dictionary[@"willRetain"];
            if (object) [self setString:object forKey:@"willretain_preference"];
            
            object = dictionary[@"updateAddressBook"];
            if (object) [self setString:object forKey:@"ab_preference"];
            
            object = dictionary[@"positions"];
            if (object) [self setString:object forKey:@"positions_preference"];
            
            object = dictionary[@"allowRemoteLocation"];
            if (object) [self setString:object forKey:@"allowremotelocation_preference"];
            
            object = dictionary[@"extendedData"];
            if (object) [self setString:object forKey:@"extendeddata_preference"];
            
            object = dictionary[@"locked"];
            if (object) [self setString:object forKey:@"locked"];
            
            object = dictionary[@"clientpkcs"];
            if (object) [self setString:object forKey:@"clientpkcs"];

            object = dictionary[@"passphrase"];
            if (object) [self setString:object forKey:@"passphrase"];
            
            object = dictionary[@"servercer"];
            if (object) [self setString:object forKey:@"servercer"];
            
            object = dictionary[@"policymode"];
            if (object) [self setString:object forKey:@"policymode"];

            object = dictionary[@"usepolicy"];
            if (object) [self setString:object forKey:@"usepolicy"];
            
            object = dictionary[@"allowinvalidcerts"];
            if (object) [self setString:object forKey:@"allowinvalidcerts"];
            
            object = dictionary[@"validatecertificatechain"];
            if (object) [self setString:object forKey:@"validatecertificatechain"];
            
            object = dictionary[@"validatedomainname"];
            if (object) [self setString:object forKey:@"validatedomainname"];
            
            object = dictionary[@"tid"];
            if (object) [self setString:object forKey:@"trackerid_preference"];
            
            NSArray *waypoints = dictionary[@"waypoints"];
            [self setWaypoints:waypoints];
            
        } else {
            return [NSError errorWithDomain:@"OwnTracks Settings"
                                       code:1
                                   userInfo:@{@"_type": [NSString stringWithFormat:@"%@", dictionary[@"_type"]]}];
        }
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"reload" object:nil];
    return nil;
}

+ (NSError *)waypointsFromStream:(NSInputStream *)input {
    NSError *error;
    
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithStream:input
                                                                 options:0
                                                                   error:&error];
    if (dictionary) {
        return [self waypointsFromDictionary:dictionary];
    } else {
        return error;
    }
}

+ (NSError *)waypointsFromDictionary:(NSDictionary *)dictionary {
    if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
        for (NSString *key in [dictionary allKeys]) {
            DDLogVerbose(@"Waypoints %@:%@", key, dictionary[key]);
        }
        
        if ([dictionary[@"_type"] isEqualToString:@"waypoints"]) {
            NSArray *waypoints = dictionary[@"waypoints"];
            [self setWaypoints:waypoints];
        } else {
            return [NSError errorWithDomain:@"OwnTracks Waypoints"
                                       code:1
                                   userInfo:@{@"_type": dictionary[@"_type"]}];
        }
    }
    return nil;
}

+ (void)setWaypoints:(NSArray *)waypoints {
    if (waypoints) {
        for (NSDictionary *waypoint in waypoints) {
            if ([waypoint[@"_type"] isEqualToString:@"waypoint"]) {
                DDLogVerbose(@"Waypoint desc:%@ lon:%g lat:%g",
                             waypoint[@"desc"],
                             [waypoint[@"lon"] doubleValue],
                             [waypoint[@"lat"] doubleValue]
                             );
                
                NSArray *components = [waypoint[@"desc"] componentsSeparatedByString:@":"];
                NSString *name = components.count >= 1 ? components[0] : nil;
                NSString *uuid = components.count >= 2 ? components[1] : nil;
                unsigned int major = components.count >= 3 ? [components[2] unsignedIntValue]: 0;
                unsigned int minor = components.count >= 4 ? [components[3] unsignedIntValue]: 0;
                
                Friend *friend = [Friend friendWithTopic:[self theGeneralTopic]
                                        inManagedObjectContext:[CoreData theManagedObjectContext]];

                for (Region *region in friend.hasRegions) {
                    if ([region.name isEqualToString:name]) {
                        [[OwnTracking sharedInstance] removeRegion:region context:[CoreData theManagedObjectContext]];
                        break;
                    }
                }

                CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(
                                                                               [waypoint[@"lat"] doubleValue],
                                                                               [waypoint[@"lon"] doubleValue]
                                                                               );
                if (CLLocationCoordinate2DIsValid(coordinate)) {
                    [[OwnTracking sharedInstance] addRegionFor:friend
                                                          name:name
                                                          uuid:uuid
                                                         major:major
                                                         minor:minor
                                                         share:YES
                                                        radius:[waypoint[@"rad"] doubleValue]
                                                           lat:[waypoint[@"lat"] doubleValue]
                                                           lon:[waypoint[@"lon"] doubleValue]
                                                       context:[CoreData theManagedObjectContext]];
                } else {
                    for (Region *region in friend.hasRegions) {
                        if ([region.name isEqualToString:name]) {
                            [[OwnTracking sharedInstance] removeRegion:region context:[CoreData theManagedObjectContext]];
                            break;
                        }
                    }
                }
            }
        }
    }
}

+ (NSArray *)waypointsToArray {
    NSMutableArray *waypoints = [[NSMutableArray alloc] init];
    Friend *friend = [Friend existsFriendWithTopic:[self theGeneralTopic]
                            inManagedObjectContext:[CoreData theManagedObjectContext]];
    for (Region *region in friend.hasRegions) {
        [waypoints addObject:[[OwnTracking sharedInstance] regionAsJSON:region]];
    }
    
    return waypoints;
}



+ (NSDictionary *)waypointsToDictionary {
    return @{@"_type": @"waypoints", @"waypoints": [self waypointsToArray]};
}

+ (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:@{@"_type": @"configuration"}];
    dict[@"mode"] =                         @([Settings intForKey:@"mode"]);
    dict[@"ranging"] =                      @([Settings boolForKey:@"ranging_preference"]);
    dict[@"locked"] =                       @([Settings boolForKey:@"locked"]);
    dict[@"tid"] =                          [Settings stringOrZeroForKey:@"trackerid_preference"];
    dict[@"monitoring"] =                   @([Settings intForKey:@"monitoring_preference"]);
    dict[@"waypoints"] =                    [Settings waypointsToArray];
    dict[@"sub"] =                          @([Settings boolForKey:@"sub_preference"]);
    dict[@"positions"] =                    @([Settings intForKey:@"positions_preference"]);
    dict[@"locatorDisplacement"] =          @([Settings intForKey:@"mindist_preference"]);
    dict[@"locatorInterval"] =              @([Settings intForKey:@"mintime_preference"]);
    dict[@"extendedData"] =                 @([Settings boolForKey:@"extendeddata_preference"]);
    dict[@"updateAddressBook"] =            @([Settings boolForKey:@"ab_preference"]);
    dict[@"ignoreStaleLocations"] =         @([Settings intForKey:@"ignorestalelocations_preference"]);
    dict[@"ignoreInaccurateLocations"] =    @([Settings intForKey:@"ignoreinaccuratelocations_preference"]);


    for (Setting *setting in [Setting allSettingsInManagedObjectContext:[CoreData theManagedObjectContext]]) {
        NSString *key = setting.key;
        if ([key rangeOfString:@"pl"].location == 0) {
            dict[key] = setting.value;
        }
    }

    switch ([Settings intForKey:@"mode"]) {
        case CONNECTION_MODE_PRIVATE:
            dict[@"deviceId"] =             [Settings stringOrZeroForKey:@"deviceid_preference"];
            dict[@"clientId"] =             [Settings stringOrZeroForKey:@"clientid_preference"];
            dict[@"subTopic"] =             [Settings stringOrZeroForKey:@"subscription_preference"];
            dict[@"pubTopicBase"] =         [Settings stringOrZeroForKey:@"topic_preference"];
            dict[@"host"] =                 [Settings stringOrZeroForKey:@"host_preference"];
            dict[@"url"] =                  [Settings stringOrZeroForKey:@"url_preference"];
            dict[@"username"] =             [Settings stringOrZeroForKey:@"user_preference"];
            dict[@"password"] =             [Settings stringOrZeroForKey:@"pass_preference"];
            dict[@"willTopic"] =            [Settings stringOrZeroForKey:@"willtopic_preference"];
            dict[@"clientpkcs"] =           [Settings stringOrZeroForKey:@"clientpkcs"];
            dict[@"passphrase"] =           [Settings stringOrZeroForKey:@"passphrase"];
            dict[@"servercer"] =            [Settings stringOrZeroForKey:@"servercer"];
            
            dict[@"subQos"] =               @([Settings intForKey:@"subscriptionqos_preference"]);
            dict[@"pubQos"] =               @([Settings intForKey:@"qos_preference"]);
            dict[@"port"] =                 @([Settings intForKey:@"port_preference"]);
            dict[@"mqttProtocolLevel"] =    @([Settings intForKey:@"mqttProtocolLevel"]);
            dict[@"keepalive"] =            @([Settings intForKey:@"keepalive_preference"]);
            dict[@"willQos"] =              @([Settings intForKey:@"willqos_preference"]);
            dict[@"policymode"] =           @([Settings intForKey:@"policymode"]);
            dict[@"positions"] =            @([Settings intForKey:@"positions_preference"]);
            dict[@"locatorDisplacement"] =  @([Settings intForKey:@"mindist_preference"]);
            dict[@"locatorInterval"] =      @([Settings intForKey:@"mintime_preference"]);
            
            dict[@"cmd"] =                  @([Settings boolForKey:@"cmd_preference"]);
            dict[@"pubRetain"] =            @([Settings boolForKey:@"retain_preference"]);
            dict[@"tls"] =                  @([Settings boolForKey:@"tls_preference"]);
            dict[@"ws"] =                  @([Settings boolForKey:@"ws_preference"]);
            dict[@"auth"] =                 @([Settings boolForKey:@"auth_preference"]);
            dict[@"cleanSession"] =         @([Settings boolForKey:@"clean_preference"]);
            dict[@"willRetain"] =           @([Settings boolForKey:@"willretain_preference"]);
            dict[@"updateAddressBook"] =    @([Settings boolForKey:@"ab_preference"]);
            dict[@"allowRemoteLocation"] =  @([Settings boolForKey:@"allowremotelocation_preference"]);
            dict[@"extendedData"] =         @([Settings boolForKey:@"extendeddata_preference"]);
            dict[@"usepolicy"] =            @([Settings boolForKey:@"usepolicy"]);
            dict[@"allowinvalidcerts"] =    @([Settings boolForKey:@"allowinvalidcerts"]);
            dict[@"validatecertificatechain"] =  @([Settings boolForKey:@"validatecertificatechain"]);
            dict[@"validatedomainname"] =   @([Settings boolForKey:@"validatedomainname"]);
            break;

        case CONNECTION_MODE_HTTP:
            dict[@"deviceId"] =             [Settings stringOrZeroForKey:@"deviceid_preference"];
            dict[@"url"] =                  [Settings stringOrZeroForKey:@"url_preference"];
            dict[@"cmd"] =                  @([Settings boolForKey:@"cmd_preference"]);
            dict[@"allowRemoteLocation"] =  @([Settings boolForKey:@"allowremotelocation_preference"]);
            dict[@"allowinvalidcerts"] =    @([Settings boolForKey:@"allowinvalidcerts"]);
            break;

        case CONNECTION_MODE_HOSTED:
            dict[@"username"] = [Settings stringOrZeroForKey:@"user"];
            dict[@"deviceId"] = [Settings stringOrZeroForKey:@"device"];
            dict[@"password"] = [Settings stringOrZeroForKey:@"token"];
            break;

        case CONNECTION_MODE_WATSON:
            dict[@"quickstartId"] =         [Settings stringOrZeroForKey:@"quickstartid_preference"];
            break;

        case CONNECTION_MODE_WATSONREGISTERED:
            dict[@"watsonOrganization"] =   [Settings stringOrZeroForKey:@"watsonorganization_preference"];
            dict[@"watsonDeviceType"] =     [Settings stringOrZeroForKey:@"watsondevicetype_preference"];
            dict[@"watsonDeviceId"] =       [Settings stringOrZeroForKey:@"watsondeviceid_preference"];
            dict[@"watsonAuthToken"] =      [Settings stringOrZeroForKey:@"watsonauthtoken_preference"];
            break;

        case CONNECTION_MODE_PUBLIC:
        default:
            break;
    }
    return dict;
}

+ (NSData *)waypointsToData {
    NSDictionary *dict = [Settings waypointsToDictionary];
    
    NSError *error;
    NSData *myData = [NSJSONSerialization dataWithJSONObject:dict
                                                     options:NSJSONWritingPrettyPrinted
                                                       error:&error];
    return myData;
}

+ (NSData *)toData {
    NSDictionary *dict = [self toDictionary];
    
    NSError *error;
    NSData *myData = [NSJSONSerialization dataWithJSONObject:dict
                                                     options:NSJSONWritingPrettyPrinted
                                                       error:&error];
    return myData;
}

+ (BOOL)validKey:(NSString *)key inMode:(ConnectionMode)mode {
    if ([key isEqualToString:@"mode"] ||
        [key isEqualToString:@"locked"] ||
        [key isEqualToString:@"sub"] ||
        [key isEqualToString:@"extendedData_preference"] ||
        [key isEqualToString:@"ab_preference"] ||
        [key isEqualToString:@"monitoring_preference"] ||
        [key isEqualToString:@"trackerid_preference"] ||
        [key isEqualToString:@"ranging_preference"]) {
        return true;
    }

    switch (mode) {
        case CONNECTION_MODE_WATSON:
            return ([key isEqualToString:@"quickstartid_preference"]);
            break;

        case CONNECTION_MODE_WATSONREGISTERED:
            return ([key isEqualToString:@"watsonorganization_preference"] ||
                    [key isEqualToString:@"watsondevicetype_preference"] ||
                    [key isEqualToString:@"watsondeviceid_preference"] ||
                    [key isEqualToString:@"watsonauthtoken_preference"]);
            break;

        case CONNECTION_MODE_PUBLIC:
            return false;
            break;

        case CONNECTION_MODE_HOSTED:
            return ([key isEqualToString:@"user"] ||
                    [key isEqualToString:@"device"] ||
                    [key isEqualToString:@"token"]);
            break;

        default:
            return true;

    }
}

+ (void)setString:(NSObject *)object forKey:(NSString *)key {
    if ([self validKey:key inMode:[self intForKey:@"mode"]]) {
        [[CoreData theManagedObjectContext] performBlockAndWait:^{
            if (object && ![object isKindOfClass:[NSNull class]]) {
                Setting *setting = [Setting settingWithKey:key
                                    inManagedObjectContext:[CoreData theManagedObjectContext]];
                setting.value = [NSString stringWithFormat:@"%@", object];
            } else {
                Setting *setting = [Setting existsSettingWithKey:key inManagedObjectContext:[CoreData theManagedObjectContext]];
                if (setting) {
                    [[CoreData theManagedObjectContext] deleteObject:setting];
                }
            }
        }];
    }
}

+ (void)setInt:(int)i forKey:(NSString *)key {
    [self setString:[NSString stringWithFormat:@"%d", i] forKey:key];
}

+ (void)setDouble:(double)d forKey:(NSString *)key {
    [self setString:[NSString stringWithFormat:@"%f", d] forKey:key];
}

+ (void)setBool:(BOOL)b forKey:(NSString *)key {
    DDLogVerbose(@"setBoolForKey:%@ = %d", key, b);
    [self setString:[NSString stringWithFormat:@"%d", b] forKey:key];
}

+ (NSString *)stringOrZeroForKey:(NSString *)key {
    NSString *value = [self stringForKey:key];
    if (!value) {
        DDLogVerbose(@"stringOrZeroForKey %@", key);
        value = @"";
    }
    return value;
}

+ (NSString *)stringForKey:(NSString *)key {
    NSString *value = nil;

    int mode = [[self stringForKeyRaw:@"mode"] intValue];
    id object;
    if (![self validKey:key inMode:mode]) {
        switch (mode) {
            case CONNECTION_MODE_PUBLIC:
                object = [[SettingsDefaults theDefaults].publicDefaults objectForKey:key];
                break;
            case CONNECTION_MODE_HOSTED:
                object = [[SettingsDefaults theDefaults].hostedDefaults objectForKey:key];
                break;
            case CONNECTION_MODE_HTTP:
                object = [[SettingsDefaults theDefaults].httpDefaults objectForKey:key];
                break;
            case CONNECTION_MODE_WATSON:
                object = [[SettingsDefaults theDefaults].watsonDefaults objectForKey:key];
                break;
            case CONNECTION_MODE_WATSONREGISTERED:
                object = [[SettingsDefaults theDefaults].watsonRegisteredDefaults objectForKey:key];
                break;
            case CONNECTION_MODE_PRIVATE:
            default:
                object = [[SettingsDefaults theDefaults].appDefaults objectForKey:key];
                break;
        }
        if (object) {
            if ([object isKindOfClass:[NSString class]]) {
                value = (NSString *)object;
            } else if ([object isKindOfClass:[NSNumber class]]) {
                value = [(NSNumber *)object stringValue];
            }
        }
    } else {
        value = [self stringForKeyRaw:key];
    }
    return value;
}

+ (NSString *)stringForKeyRaw:(NSString *)key {
    __block NSString *value = nil;
    [[CoreData theManagedObjectContext] performBlockAndWait:^{
        Setting *setting = [Setting existsSettingWithKey:key inManagedObjectContext:[CoreData theManagedObjectContext]];
        if (setting) {
            value = setting.value;
        } else {
            // if not found in Core Data or NSUserdefaults, use defaults from .plist
            id object = [[SettingsDefaults theDefaults].appDefaults objectForKey:key];
            if (object) {
                if ([object isKindOfClass:[NSString class]]) {
                    value = (NSString *)object;
                } else if ([object isKindOfClass:[NSNumber class]]) {
                    value = [(NSNumber *)object stringValue];
                }
            }
        }
    }];
    return value;
}

+ (int)intForKey:(NSString *)key {
    return [[self stringForKey:key] intValue];
}

+ (double)doubleForKey:(NSString *)key {
    return [[self stringForKey:key] doubleValue];
}

+ (BOOL)boolForKey:(NSString *)key {
    NSString *value = [self stringForKey:key];
    DDLogVerbose(@"boolForKey:%@ = %@", key, value);
    return [value boolValue];
}


+ (NSString *)theGeneralTopic {
    int mode = [self intForKey:@"mode"];
    NSString *topic;
    
    switch (mode) {
        case CONNECTION_MODE_WATSON:
        case CONNECTION_MODE_WATSONREGISTERED:
            topic = [NSString stringWithFormat:@"iot-2/evt/location/fmt/json"];
            break;

        case CONNECTION_MODE_PUBLIC:
            topic = [NSString stringWithFormat:@"public/user/%@", [self theDeviceId]];
            break;

        case CONNECTION_MODE_HOSTED:
            topic = [NSString stringWithFormat:@"owntracks/%@", [self theId]];
            break;

        case CONNECTION_MODE_PRIVATE:
        case CONNECTION_MODE_HTTP:
        default:
            topic = [self stringForKey:@"topic_preference"];
            
            if (!topic || [topic isEqualToString:@""]) {
                NSString *userId = [self theUserId];
                NSString *deviceId = [self theDeviceId];

                if (!userId || [userId isEqualToString:@""]) {
                    userId = @"user";
                }
                if (!deviceId || [deviceId isEqualToString:@""]) {
                    deviceId = @"device";
                }

                topic = [NSString stringWithFormat:@"owntracks/%@/%@", userId, deviceId];
            } else {
                topic = [topic stringByReplacingOccurrencesOfString:@"%%u"
                                                         withString:[Settings theUserId]];
                topic = [topic stringByReplacingOccurrencesOfString:@"%%d"
                                                         withString:[Settings theDeviceId]];
            }
            break;
    }
    return topic;
}

+ (NSString *)theWillTopic
{
    NSString *topic = [self stringForKey:@"willtopic_preference"];
    
    if (!topic || [topic isEqualToString:@""]) {
        topic = [self theGeneralTopic];
    }
    
    return topic;
}

+ (NSString *)theClientId {
    NSString *clientId;
    clientId = [self stringForKey:@"clientid_preference"];
    
    if (!clientId || [clientId isEqualToString:@""]) {
        clientId = [self theId];
    }
    return clientId;
}

+ (NSString *)theId {
    int mode = [self intForKey:@"mode"];
    NSString *theId;
    
    switch (mode) {
        case CONNECTION_MODE_WATSON:
            theId = [NSString stringWithFormat:@"d:quickstart:owntracks:%@",
                     [self theDeviceId]];
            break;

        case CONNECTION_MODE_WATSONREGISTERED:
            theId = [NSString stringWithFormat:@"d:%@:%@:%@",
                     [self stringForKey:@"watsonorganization_preference"],
                     [self stringForKey:@"watsondevicetype_preference"],
                     [self theDeviceId]];
            break;

        case CONNECTION_MODE_PUBLIC:
        case CONNECTION_MODE_HOSTED:
            theId = [NSString stringWithFormat:@"%@%@",
                     [self theUserId],
                     [self theDeviceId]];
            break;

        case CONNECTION_MODE_PRIVATE:
        case CONNECTION_MODE_HTTP:
        default: {
            NSString *userId = [self theUserId];
            NSString *deviceId = [self theDeviceId];
            
            if (!userId || [userId isEqualToString:@""]) {
                if (!deviceId || [deviceId isEqualToString:@""]) {
                    theId = [[UIDevice currentDevice] name];
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
        }
            break;
    }

    
    return theId;
}

+ (NSString *)theDeviceId {
    int mode = [self intForKey:@"mode"];
    NSString *deviceId;
    
    switch (mode) {
        case CONNECTION_MODE_WATSON:
            deviceId = [self stringForKey:@"quickstartid_preference"];
            break;

        case CONNECTION_MODE_WATSONREGISTERED:
            deviceId = [self stringForKey:@"watsondeviceid_preference"];
            break;

        case CONNECTION_MODE_HTTP:
            deviceId = [self stringForKey:@"trackerid_preference"];
            if (!deviceId || deviceId.length == 0) {
                deviceId = [[UIDevice currentDevice].identifierForVendor UUIDString];
            }
            break;
        case CONNECTION_MODE_PUBLIC:
            deviceId = [[UIDevice currentDevice].identifierForVendor UUIDString];
            break;
        case CONNECTION_MODE_HOSTED:
            deviceId = [self stringForKey:@"device"];
            break;
        case CONNECTION_MODE_PRIVATE:
        default:
            deviceId = [self stringForKey:@"deviceid_preference"];
            break;
    }
    return deviceId;
}

+ (NSString *)theSubscriptions {
    int mode = [self intForKey:@"mode"];
    NSString *subscriptions;
    
    switch (mode) {
        case CONNECTION_MODE_WATSON:
        case CONNECTION_MODE_WATSONREGISTERED:
            break;

        case CONNECTION_MODE_PUBLIC:
            subscriptions = [NSString stringWithFormat:@"public/user/+ public/user/+/event public/user/+/info public/user/%@/cmd",
                             [self theDeviceId]];
            break;

        case CONNECTION_MODE_HOSTED:
        case CONNECTION_MODE_PRIVATE:
        case CONNECTION_MODE_HTTP:
        default:
            subscriptions = [self stringForKey:@"subscription_preference"];
            
            if (!subscriptions || subscriptions.length == 0) {
                NSArray *baseComponents = [[self theGeneralTopic] componentsSeparatedByString:@"/"];
                
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
                
                for (int i = any; i < [baseComponents count]; i++) {
                    if (i > 0) {
                        anyDevice = [anyDevice stringByAppendingString:@"/"];
                    }
                    anyDevice = [anyDevice stringByAppendingString:@"+"];
                }
                
                subscriptions = [NSString stringWithFormat:@"%@ %@/event %@/info %@/cmd",
                                 anyDevice,
                                 anyDevice,
                                 anyDevice,
                                 [self theGeneralTopic]];
            }
            break;
    }

    return subscriptions;
}

+ (NSString *)theUserId {
    int mode = [self intForKey:@"mode"];
    switch (mode) {
        case CONNECTION_MODE_HTTP:
            return @"http";
            break;

        case CONNECTION_MODE_PUBLIC:
            return @"user";
            break;

        case CONNECTION_MODE_HOSTED:
            return [self stringForKey:@"user"];
            break;

        case CONNECTION_MODE_PRIVATE:
        default:
            return [self stringForKey:@"user_preference"];
            break;
    }
}

+ (NSString *)theHost {
    int mode = [self intForKey:@"mode"];
    switch (mode) {
        case CONNECTION_MODE_PUBLIC:
            return @"public-mqtt.owntracks.org";
            break;

        case CONNECTION_MODE_WATSON:
            return @"quickstart.messaging.internetofthings.ibmcloud.com";
            break;

        case CONNECTION_MODE_WATSONREGISTERED:
            return [NSString stringWithFormat:@"%@.messaging.internetofthings.ibmcloud.com",
                    [self stringForKey:@"watsonorganization_preference"]];
            break;

        case CONNECTION_MODE_HOSTED:
            return @"hosted-mqtt.owntracks.org";
            break;

        case CONNECTION_MODE_HTTP: {
            NSURL *url = [NSURL URLWithString:[self stringForKey:@"url_preference"]];
            NSString *host = url.host;
            return host ? host : @"hosted.owntracks.org";
            break;
        }

        case CONNECTION_MODE_PRIVATE:
        default:
            return [self stringForKey:@"host_preference"];
            break;
    }
}

+ (NSString *)theMqttUser {
    int mode = [self intForKey:@"mode"];
    switch (mode) {
        case CONNECTION_MODE_PUBLIC:
        case CONNECTION_MODE_HTTP:
        case CONNECTION_MODE_WATSON:
            return nil;
            break;

        case CONNECTION_MODE_WATSONREGISTERED:
            return @"use-token-auth";
            break;

        case CONNECTION_MODE_HOSTED:
            return [NSString stringWithFormat:@"%@|%@",
                    [self stringForKey:@"user"],
                    [self theDeviceId]];
            break;

        case CONNECTION_MODE_PRIVATE:
        default:
            return [self stringForKey:@"user_preference"];
            break;
    }
}

+ (NSString *)theMqttPass {
    int mode = [self intForKey:@"mode"];
    switch (mode) {
        case CONNECTION_MODE_PUBLIC:
        case CONNECTION_MODE_HTTP:
        case CONNECTION_MODE_WATSON:
            return nil;
            break;

        case CONNECTION_MODE_WATSONREGISTERED:
            return [self stringForKey:@"watsonauthtoken_preference"];
            break;

        case CONNECTION_MODE_HOSTED:
            return [self stringForKey:@"token"];
            break;

        case CONNECTION_MODE_PRIVATE:
        default:
            return [self stringForKey:@"pass_preference"];
            break;
    }
}

+ (BOOL)theMqttAuth {
    int mode = [self intForKey:@"mode"];
    switch (mode) {
        case CONNECTION_MODE_HTTP:
        case CONNECTION_MODE_PUBLIC:
        case CONNECTION_MODE_WATSON:
            return FALSE;
            break;

        case CONNECTION_MODE_HOSTED:
        case CONNECTION_MODE_WATSONREGISTERED:
            return TRUE;
            break;

        case CONNECTION_MODE_PRIVATE:
        default:
            return [self boolForKey:@"auth_preference"];
            break;
    }
}

+ (BOOL)validIds {
    NSString *user = [self theUserId];
    NSString *device = [self theDeviceId];
    
    return (user && user.length != 0 && device && device.length != 0);
}

@end

