//
//  Settings.m
//  OwnTracks
//
//  Created by Christoph Krey on 31.01.14.
//  Copyright © 2014-2016 Christoph Krey. All rights reserved.
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
@end

static SettingsDefaults *defaults;
static const DDLogLevel ddLogLevel = DDLogLevelError;

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
        NSURL *hostedPlistURL = [bundleURL URLByAppendingPathComponent:@"Hosted.plist"];
        
        self.appDefaults = [NSDictionary dictionaryWithContentsOfURL:settingsPlistURL];
        self.publicDefaults = [NSDictionary dictionaryWithContentsOfURL:publicPlistURL];
        self.hostedDefaults = [NSDictionary dictionaryWithContentsOfURL:hostedPlistURL];
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
            NSString *string;
            NSObject *object;
            int importMode = 0;
            
            object = dictionary[@"mode"];
            if (object) {
                NSString *string = [NSString stringWithFormat:@"%@", object];
                [self setString:string forKey:@"mode"];
                importMode = [string intValue];
            }
            
            string = dictionary[@"deviceId"];
            if (string) {
                switch (importMode) {
                    case 0:
                        [self setString:string forKey:@"deviceid_preference"];
                        break;
                    case 1:
                        [self setString:string forKey:@"device"];
                        break;
                    case 2:
                    default:
                        break;
                }
            }
            
            string = dictionary[@"tid"];
            if (string) [self setString:string forKey:@"trackerid_preference"];
            
            string = dictionary[@"clientId"];
            if (string) [self setString:string forKey:@"clientid_preference"];
            
            string = dictionary[@"subTopic"];
            if (string) [self setString:string forKey:@"subscription_preference"];
            
            string = dictionary[@"pubTopicBase"];
            if (string) [self setString:string forKey:@"topic_preference"];
            
            string = dictionary[@"host"];
            if (string) [self setString:string forKey:@"host_preference"];
            
            string = dictionary[@"url"];
            if (string) [self setString:string forKey:@"url_preference"];
            
            string = dictionary[@"username"];
            if (string) {
                switch (importMode) {
                    case 0:
                        [self setString:string forKey:@"user_preference"];
                        break;
                    case 1:
                        [self setString:string forKey:@"user"];
                        break;
                    case 2:
                    default:
                        break;
                }
            }
            
            string = dictionary[@"password"];
            if (string) {
                switch (importMode) {
                    case 0:
                        [self setString:string forKey:@"pass_preference"];
                        break;
                    case 1:
                        [self setString:string forKey:@"token"];
                        break;
                    case 2:
                    default:
                        break;
                }
            }
                [self setString:string forKey:@"pass_preference"];
            
            string = dictionary[@"willTopic"];
            if (string) [self setString:string forKey:@"willtopic_preference"];
        
            object = dictionary[@"subQos"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"subscriptionqos_preference"];
            
            object = dictionary[@"pubQos"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"qos_preference"];
            
            object = dictionary[@"port"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"port_preference"];
            
            object = dictionary[@"keepalive"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"keepalive_preference"];
            
            object = dictionary[@"willQos"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"willqos_preference"];
            
            object = dictionary[@"locatorDisplacement"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"mindist_preference"];
            
            object = dictionary[@"locatorInterval"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"mintime_preference"];
            
            object = dictionary[@"monitoring"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"monitoring_preference"];
            
            object = dictionary[@"ranging"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"ranging_preference"];
            
            object = dictionary[@"cmd"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"cmd_preference"];
            
            
            object = dictionary[@"pubRetain"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"retain_preference"];
            
            object = dictionary[@"tls"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"tls_preference"];
            
            object = dictionary[@"auth"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"auth_preference"];
            
            object = dictionary[@"cleanSession"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"clean_preference"];
            
            object = dictionary[@"willRetain"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"willretain_preference"];
            
            object = dictionary[@"updateAddressBook"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"ab_preference"];
            
            object = dictionary[@"positions"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object]
                                 forKey:@"positions_preference"];
            
            object = dictionary[@"allowRemoteLocation"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object] forKey:@"allowremotelocation_preference"];
            
            object = dictionary[@"extendedData"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object] forKey:@"extendeddata_preference"];
            
            object = dictionary[@"locked"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object] forKey:@"locked"];
            
            object = dictionary[@"clientpkcs"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object] forKey:@"clientpkcs"];

            object = dictionary[@"passphrase"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object] forKey:@"passphrase"];
            
            object = dictionary[@"servercer"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object] forKey:@"servercer"];
            
            object = dictionary[@"policymode"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object] forKey:@"policymode"];

            object = dictionary[@"usepolicy"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object] forKey:@"usepolicy"];
            
            object = dictionary[@"allowinvalidcerts"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object] forKey:@"allowinvalidcerts"];
            
            object = dictionary[@"validatecertificatechain"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object] forKey:@"validatecertificatechain"];
            
            object = dictionary[@"validatedomainname"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object] forKey:@"validatedomainname"];
            
            string = dictionary[@"tid"];
            if (string) [self setString:string forKey:@"trackerid_preference"];
            
            NSArray *waypoints = dictionary[@"waypoints"];
            [self setWaypoints:waypoints];
            
        } else {
            return [NSError errorWithDomain:@"OwnTracks Settings" code:1 userInfo:@{@"_type": dictionary[@"_type"]}];
        }
    }
    
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
    if (dictionary) {
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
    dict[@"mode"] =                 @([Settings intForKey:@"mode"]);
    dict[@"ranging"] =              @([Settings boolForKey:@"ranging_preference"]);
    dict[@"locked"] =              @([Settings boolForKey:@"locked"]);
    dict[@"tid"] =                  [Settings stringOrZeroForKey:@"trackerid_preference"];
    dict[@"monitoring"] =           @([Settings intForKey:@"monitoring_preference"]);
    dict[@"waypoints"] =            [Settings waypointsToArray];

    switch ([Settings intForKey:@"mode"]) {
        case 0:
            dict[@"deviceId"] =     [Settings stringOrZeroForKey:@"deviceid_preference"];
            dict[@"clientId"] =     [Settings stringOrZeroForKey:@"clientid_preference"];
            dict[@"subTopic"] =     [Settings stringOrZeroForKey:@"subscription_preference"];
            dict[@"pubTopicBase"] = [Settings stringOrZeroForKey:@"topic_preference"];
            dict[@"host"] =         [Settings stringOrZeroForKey:@"host_preference"];
            dict[@"url"] =         [Settings stringOrZeroForKey:@"url_preference"];
            dict[@"username"] =     [Settings stringOrZeroForKey:@"user_preference"];
            dict[@"password"] =     [Settings stringOrZeroForKey:@"pass_preference"];
            dict[@"willTopic"] =    [Settings stringOrZeroForKey:@"willtopic_preference"];
            dict[@"clientpkcs"] =    [Settings stringOrZeroForKey:@"clientpkcs"];
            dict[@"passphrase"] =    [Settings stringOrZeroForKey:@"passphrase"];
            dict[@"servercer"] =    [Settings stringOrZeroForKey:@"servercer"];
            
            dict[@"subQos"] =       @([Settings intForKey:@"subscriptionqos_preference"]);
            dict[@"pubQos"] =       @([Settings intForKey:@"qos_preference"]);
            dict[@"port"] =         @([Settings intForKey:@"port_preference"]);
            dict[@"keepalive"] =    @([Settings intForKey:@"keepalive_preference"]);
            dict[@"willQos"] =      @([Settings intForKey:@"willqos_preference"]);
            dict[@"policymode"] =      @([Settings intForKey:@"policymode"]);
            dict[@"positions"] =            @([Settings intForKey:@"positions_preference"]);
            dict[@"locatorDisplacement"] =  @([Settings intForKey:@"mindist_preference"]);
            dict[@"locatorInterval"] =      @([Settings intForKey:@"mintime_preference"]);
            
            dict[@"cmd"] =                  @([Settings boolForKey:@"cmd_preference"]);
            dict[@"pubRetain"] =            @([Settings boolForKey:@"retain_preference"]);
            dict[@"tls"] =                  @([Settings boolForKey:@"tls_preference"]);
            dict[@"auth"] =                 @([Settings boolForKey:@"auth_preference"]);
            dict[@"cleanSession"] =         @([Settings boolForKey:@"clean_preference"]);
            dict[@"willRetain"] =           @([Settings boolForKey:@"willretain_preference"]);
            dict[@"updateAddressBook"] =    @([Settings boolForKey:@"ab_preference"]);
            dict[@"allowRemoteLocation"] =  @([Settings boolForKey:@"allowremotelocation_preference"]);
            dict[@"extendedData"] =         @([Settings boolForKey:@"extendeddata_preference"]);
            dict[@"usepolicy"] =         @([Settings boolForKey:@"usepolicy"]);
            dict[@"allowinvalidcerts"] =         @([Settings boolForKey:@"allowinvalidcerts"]);
            dict[@"validatecertificatechain"] =         @([Settings boolForKey:@"validatecertificatechain"]);
            dict[@"validatedomainname"] =         @([Settings boolForKey:@"validatedomainname"]);
            
            break;

        case 3:
            dict[@"deviceId"] =     [Settings stringOrZeroForKey:@"deviceid_preference"];
            dict[@"url"] =         [Settings stringOrZeroForKey:@"url_preference"];
            dict[@"positions"] =            @([Settings intForKey:@"positions_preference"]);
            dict[@"locatorDisplacement"] =  @([Settings intForKey:@"mindist_preference"]);
            dict[@"locatorInterval"] =      @([Settings intForKey:@"mintime_preference"]);
            
            dict[@"cmd"] =                  @([Settings boolForKey:@"cmd_preference"]);
            dict[@"updateAddressBook"] =    @([Settings boolForKey:@"ab_preference"]);
            dict[@"allowRemoteLocation"] =  @([Settings boolForKey:@"allowremotelocation_preference"]);
            dict[@"extendedData"] =         @([Settings boolForKey:@"extendeddata_preference"]);
            dict[@"allowinvalidcerts"] =         @([Settings boolForKey:@"allowinvalidcerts"]);

            break;
        case 1:
            dict[@"username"] = [Settings stringOrZeroForKey:@"user"];
            dict[@"deviceId"] = [Settings stringOrZeroForKey:@"device"];
            dict[@"password"] = [Settings stringOrZeroForKey:@"token"];
            break;
        case 2:
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

+ (BOOL)validInPublicMode:(NSString *)key {
    return ([key isEqualToString:@"mode"] ||
            [key isEqualToString:@"locked"] ||
            [key isEqualToString:@"monitoring_preference"] ||
            [key isEqualToString:@"trackerid_preference"] ||
            [key isEqualToString:@"ranging_preference"]);
    
}

+ (BOOL)validInHostedMode:(NSString *)key {
    return ([key isEqualToString:@"mode"] ||
            [key isEqualToString:@"locked"] ||
            [key isEqualToString:@"monitoring_preference"] ||
            [key isEqualToString:@"trackerid_preference"] ||
            [key isEqualToString:@"user"] ||
            [key isEqualToString:@"device"] ||
            [key isEqualToString:@"token"] ||
            [key isEqualToString:@"ranging_preference"]);
    
}

+ (void)setString:(NSString *)string forKey:(NSString *)key {
    if ([self intForKey:@"mode"] == 0 || [self intForKey:@"mode"] == 3 ||
        ([self intForKey:@"mode"] == 1 && [self validInHostedMode:key]) ||
        ([self intForKey:@"mode"] == 2 && [self validInPublicMode:key])) {
        [[CoreData theManagedObjectContext] performBlockAndWait:^{
            Setting *setting = [Setting settingWithKey:key inManagedObjectContext:[CoreData theManagedObjectContext]];
            setting.value = string;
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
    
    if ([[self stringForKeyRaw:@"mode"] intValue] == 2 && ![self validInPublicMode:key]) {
        id object = [[SettingsDefaults theDefaults].publicDefaults objectForKey:key];
        if (object) {
            if ([object isKindOfClass:[NSString class]]) {
                value = (NSString *)object;
            } else if ([object isKindOfClass:[NSNumber class]]) {
                value = [(NSNumber *)object stringValue];
            }
        }
    } else if ([[self stringForKeyRaw:@"mode"] intValue] == 1 && ![self validInHostedMode:key]) {
        id object = [[SettingsDefaults theDefaults].hostedDefaults objectForKey:key];
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
        case 2:
            topic = [NSString stringWithFormat:@"public/user/%@", [self theDeviceId]];
            break;
        case 1:
            topic = [NSString stringWithFormat:@"owntracks/%@", [self theId]];
            break;
        case 0:
        case 3:
        default:
            topic = [self stringForKey:@"topic_preference"];
            
            if (!topic || [topic isEqualToString:@""]) {
                topic = [NSString stringWithFormat:@"owntracks/%@", [self theId]];
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
        case 2:
        case 1:
            theId = [NSString stringWithFormat:@"%@/%@", [self theUserId], [self theDeviceId]];
            break;
        case 0:
        case 3:
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
                    theId = [NSString stringWithFormat:@"%@/%@", userId, deviceId];
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
        case 2:
        case 3:
            deviceId = [[UIDevice currentDevice].identifierForVendor UUIDString];
            break;
        case 1:
            deviceId = [self stringForKey:@"device"];
            break;
        case 0:
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
        case 2:
            subscriptions = [NSString stringWithFormat:@"public/user/+ public/user/+/event public/user/+/info public/user/%@/cmd",
                             [self theDeviceId]];
            break;
        case 1:
        case 0:
        case 3:
        default:
            subscriptions = [self stringForKey:@"subscription_preference"];
            
            if (!subscriptions || subscriptions.length == 0) {
                NSArray *baseComponents = [[self theGeneralTopic] componentsSeparatedByCharactersInSet:
                                           [NSCharacterSet characterSetWithCharactersInString:@"/"]];
                
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
        case 2:
        case 3:
            return @"user";
            break;
        case 1:
            return [self stringForKey:@"user"];
            break;
        case 0:
        default:
            return [self stringForKey:@"user_preference"];
            break;
    }
}

+ (NSString *)theMqttUser {
    int mode = [self intForKey:@"mode"];
    switch (mode) {
        case 2:
        case 3:
            return nil;
            break;
        case 1:
            return [NSString stringWithFormat:@"%@|%@",
                    [self stringForKey:@"user"],
                    [self theDeviceId]];
            break;
        case 0:
        default:
            return [self stringForKey:@"user_preference"];
            break;
    }
}

+ (NSString *)theMqttPass {
    int mode = [self intForKey:@"mode"];
    switch (mode) {
        case 2:
        case 3:
            return nil;
            break;
        case 1:
            return [self stringForKey:@"token"];
            break;
        case 0:
        default:
            return [self stringForKey:@"pass_preference"];
            break;
    }
}

+ (BOOL)theMqttAuth {
    int mode = [self intForKey:@"mode"];
    switch (mode) {
        case 3:
        case 2:
            return FALSE;
            break;
        case 1:
            return TRUE;
            break;
        case 0:
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
