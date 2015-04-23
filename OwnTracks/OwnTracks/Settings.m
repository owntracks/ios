//
//  Settings.m
//  OwnTracks
//
//  Created by Christoph Krey on 31.01.14.
//  Copyright (c) 2014-2015 Christoph Krey. All rights reserved.
//

#import "Settings.h"
#import "CoreData.h"
#import "Location+Create.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface Settings ()
@property (strong, nonatomic) NSDictionary *appDefaults;
@property (strong, nonatomic) NSDictionary *publicDefaults;
@property (strong, nonatomic) NSDictionary *hostedDefaults;
@end

@implementation Settings
static const DDLogLevel ddLogLevel = DDLogLevelError;

- (id)init
{
    self = [super init];
    DDLogVerbose(@"ddLogLevel %lu", (unsigned long)ddLogLevel);

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

- (NSError *)fromStream:(NSInputStream *)input
{
    NSError *error;
    
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithStream:input options:0 error:&error];
    if (dictionary) {
        for (NSString *key in [dictionary allKeys]) {
            DDLogVerbose(@"Configuration %@:%@", key, dictionary[key]);
        }
        
        if ([dictionary[@"_type"] isEqualToString:@"configuration"]) {
            NSString *string;
            NSObject *object;
            
            object = dictionary[@"mode"];
            if (object) [self setString:[NSString stringWithFormat:@"%@", object] forKey:@"mode"];
            
            string = dictionary[@"deviceid"];
            if (string) [self setString:string forKey:@"deviceid_preference"];
            
            string = dictionary[@"trackerid"];
            if (string) [self setString:string forKey:@"trackerid_preference"];
            
            string = dictionary[@"clientid"];
            if (string) [self setString:string forKey:@"clientid_preference"];
            
            string = dictionary[@"subTopic"];
            if (string) [self setString:string forKey:@"subscription_preference"];
            
            string = dictionary[@"pubTopicBase"];
            if (string) [self setString:string forKey:@"topic_preference"];
            
            string = dictionary[@"host"];
            if (string) [self setString:string forKey:@"host_preference"];
            
            string = dictionary[@"username"];
            if (string) [self setString:string forKey:@"user_preference"];
            
            string = dictionary[@"password"];
            if (string) [self setString:string forKey:@"pass_preference"];
            
            string = dictionary[@"willTopic"];
            if (string) [self setString:string forKey:@"willtopic_preference"];
            
            string = dictionary[@"user"];
            if (string) [self setString:string forKey:@"user"];
            
            string = dictionary[@"device"];
            if (string) [self setString:string forKey:@"device"];
            
            string = dictionary[@"token"];
            if (string) [self setString:string forKey:@"token"];
            

            
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
            
            string = dictionary[@"tid"];
            if (string) [self setString:string forKey:@"trackerid_preference"];
            
            NSArray *waypoints = dictionary[@"waypoints"];
            [self setWaypoints:waypoints];
            
        } else {
            return [NSError errorWithDomain:@"OwnTracks Settings" code:1 userInfo:@{@"_type": dictionary[@"_type"]}];
        }
    } else {
        return error;
    }
    
    return nil;
}

- (NSError *)waypointsFromStream:(NSInputStream *)input
{
    NSError *error;
    
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithStream:input options:0 error:&error];
    if (dictionary) {
        for (NSString *key in [dictionary allKeys]) {
            DDLogVerbose(@"Waypoints %@:%@", key, dictionary[key]);
        }
        
        if ([dictionary[@"_type"] isEqualToString:@"waypoints"]) {
            NSArray *waypoints = dictionary[@"waypoints"];
            [self setWaypoints:waypoints];
        } else {
            return [NSError errorWithDomain:@"OwnTracks Waypoints" code:1 userInfo:@{@"_type": dictionary[@"_type"]}];
        }
    } else {
        return error;
    }
    return nil;
}

- (void)setWaypoints:(NSArray *)waypoints
{
    if (waypoints) {
        for (NSDictionary *waypoint in waypoints) {
            if ([waypoint[@"_type"] isEqualToString:@"waypoint"]) {
                DDLogVerbose(@"Waypoint tst:%g lon:%g lat:%g",
                             [waypoint[@"tst"] doubleValue],
                             [waypoint[@"lon"] doubleValue],
                             [waypoint[@"lat"] doubleValue]
                             );
                CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(
                                                                               [waypoint[@"lat"] doubleValue],
                                                                               [waypoint[@"lon"] doubleValue]
                                                                               );
                CLLocation *location = [[CLLocation alloc] initWithCoordinate:coordinate
                                                                     altitude:0
                                                           horizontalAccuracy:0
                                                             verticalAccuracy:0
                                                                       course:0
                                                                        speed:0
                                                                    timestamp:[NSDate dateWithTimeIntervalSince1970:[waypoint[@"tst"] doubleValue]]];
                
                [Location locationWithTopic:[self theGeneralTopic]
                                        tid:[self stringForKey:@"trackerid_preference"]
                                  timestamp:location.timestamp
                                 coordinate:location.coordinate
                                   accuracy:location.horizontalAccuracy
                                   altitude:location.altitude
                           verticalaccuracy:location.verticalAccuracy
                                      speed:location.speed
                                     course:location.course
                                  automatic:NO
                                     remark:waypoint[@"desc"]
                                     radius:[waypoint[@"rad"] doubleValue]
                                      share:YES
                     inManagedObjectContext:[CoreData theManagedObjectContext]];
            }
        }
    }
}

- (NSDictionary *)toDictionary
{
    NSMutableArray *waypoints = [[NSMutableArray alloc] init];
    
    for (Location *location in [Location allWaypointsOfTopic:[self theGeneralTopic]
                                      inManagedObjectContext:[CoreData theManagedObjectContext]]) {
        NSDictionary *waypoint = @{@"_type": @"waypoint",
                                   @"lat": @(location.coordinate.latitude),
                                   @"lon": @(location.coordinate.longitude),
                                   @"tst": @((int)[location.timestamp timeIntervalSince1970]),
                                   @"rad": location.regionradius,
                                   @"desc": location.remark
                                   };
        [waypoints addObject:waypoint];
    }
    
    NSDictionary *dict = @{@"_type": @"configuration",
                           @"deviceid": [self stringForKey:@"deviceid_preference"],
                           @"clientid": [self stringForKey:@"clientid_preference"],
                           @"subTopic": [self stringForKey:@"subscription_preference"],
                           @"pubTopicBase": [self stringForKey:@"topic_preference"],
                           @"host": [self stringForKey:@"host_preference"],
                           @"username": [self stringForKey:@"user_preference"],
                           @"password": [self stringForKey:@"pass_preference"],
                           @"willTopic": [self stringForKey:@"willtopic_preference"],
                           @"tid": [self stringForKey:@"trackerid_preference"],
                           @"user": [self stringForKey:@"user"],
                           @"device": [self stringForKey:@"device"],
                           @"token": [self stringForKey:@"token"],
                           
                           @"subQos": @([self intForKey:@"subscriptionqos_preference"]),
                           @"pubQos": @([self intForKey:@"qos_preference"]),
                           @"port": @([self intForKey:@"port_preference"]),
                           @"keepalive": @([self intForKey:@"keepalive_preference"]),
                           @"willQos": @([self intForKey:@"willqos_preference"]),
                           @"locatorDisplacement": @([self intForKey:@"mindist_preference"]),
                           @"locatorInterval": @([self intForKey:@"mintime_preference"]),
                           @"monitoring": @([self intForKey:@"monitoring_preference"]),
                           @"positions": @([self intForKey:@"positions_preference"]),
                           
                           @"ranging": @([self boolForKey:@"ranging_preference"]),
                           @"cmd": @([self boolForKey:@"cmd_preference"]),
                           @"pubRetain": @([self boolForKey:@"retain_preference"]),
                           @"tls": @([self boolForKey:@"tls_preference"]),
                           @"auth": @([self boolForKey:@"auth_preference"]),
                           @"cleanSession": @([self boolForKey:@"clean_preference"]),
                           @"willRetain": @([self boolForKey:@"willretain_preference"]),
                           @"updateAddressBook": @([self boolForKey:@"ab_preference"]),
                           @"allowRemoteLocation": @([self boolForKey:@"allowremotelocation_preference"]),
                           @"publicMode": @([self intForKey:@"mode"]),
                           @"extendedData": @([self boolForKey:@"extendeddata_preference"]),
                           
                           @"waypoints": waypoints
                           };
    return dict;
}

- (NSData *)toData
{
    NSDictionary *dict = [self toDictionary];
    
    NSError *error;
    NSData *myData = [NSJSONSerialization dataWithJSONObject:dict
                                                     options:NSJSONWritingPrettyPrinted
                                                       error:&error];
    return myData;
}

- (BOOL)validInPublicMode:(NSString *)key {
    return ([key isEqualToString:@"mode"] ||
            [key isEqualToString:@"monitoring_preference"] ||
            [key isEqualToString:@"mindist_preference"] ||
            [key isEqualToString:@"mintime_preference"] ||
            [key isEqualToString:@"positions_preference"] ||
            [key isEqualToString:@"trackerid_preference"] ||
            [key isEqualToString:@"ranging_preference"]);
    
}

- (BOOL)validInHostedMode:(NSString *)key {
    return ([key isEqualToString:@"mode"] ||
            [key isEqualToString:@"monitoring_preference"] ||
            [key isEqualToString:@"mindist_preference"] ||
            [key isEqualToString:@"mintime_preference"] ||
            [key isEqualToString:@"positions_preference"] ||
            [key isEqualToString:@"trackerid_preference"] ||
            [key isEqualToString:@"user"] ||
            [key isEqualToString:@"device"] ||
            [key isEqualToString:@"token"] ||
            [key isEqualToString:@"ranging_preference"]);
    
}

- (void)setString:(NSString *)string forKey:(NSString *)key
{
    if ([self intForKey:@"mode"] == 0 ||
        ([self intForKey:@"mode"] == 1 && [self validInHostedMode:key]) ||
        ([self intForKey:@"mode"] == 2 && [self validInPublicMode:key])) {
        Setting *setting = [Setting settingWithKey:key inManagedObjectContext:[CoreData theManagedObjectContext]];
        setting.value = string;
    }
}

- (void)setInt:(int)i forKey:(NSString *)key
{
    [self setString:[NSString stringWithFormat:@"%d", i] forKey:key];
}

- (void)setDouble:(double)d forKey:(NSString *)key
{
    [self setString:[NSString stringWithFormat:@"%f", d] forKey:key];
}

- (void)setBool:(BOOL)b forKey:(NSString *)key
{
    [self setString:[NSString stringWithFormat:@"%d", b] forKey:key];
}

- (NSString *)stringForKey:(NSString *)key
{
    NSString *value = nil;
    
    if ([[self stringForKeyRaw:@"mode"] intValue] == 2 && ![self validInPublicMode:key]) {
        id object = [self.publicDefaults objectForKey:key];
        if (object) {
            if ([object isKindOfClass:[NSString class]]) {
                value = (NSString *)object;
            } else if ([object isKindOfClass:[NSNumber class]]) {
                value = [(NSNumber *)object stringValue];
            }
        }
    } else if ([[self stringForKeyRaw:@"mode"] intValue] == 1 && ![self validInHostedMode:key]) {
        id object = [self.hostedDefaults objectForKey:key];
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

- (NSString *)stringForKeyRaw:(NSString *)key {
    NSString *value = nil;
    
    Setting *setting = [Setting existsSettingWithKey:key inManagedObjectContext:[CoreData theManagedObjectContext]];
    if (setting) {
        value = setting.value;
    } else {
        // if not found in Core Data or NSUserdefaults, use defaults from .plist
        id object = [self.appDefaults objectForKey:key];
        if (object) {
            if ([object isKindOfClass:[NSString class]]) {
                value = (NSString *)object;
            } else if ([object isKindOfClass:[NSNumber class]]) {
                value = [(NSNumber *)object stringValue];
            }
        }
    }
    return value;
}

- (int)intForKey:(NSString *)key
{
    return [[self stringForKey:key] intValue];
}

- (double)doubleForKey:(NSString *)key
{
    return [[self stringForKey:key] doubleValue];
}

- (BOOL)boolForKey:(NSString *)key
{
    return [[self stringForKey:key] boolValue];
}


- (NSString *)theGeneralTopic
{
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
        default:
            topic = [self stringForKey:@"topic_preference"];
            
            if (!topic || [topic isEqualToString:@""]) {
                topic = [NSString stringWithFormat:@"owntracks/%@", [self theId]];
            }
            break;
    }
    return topic;
}

- (NSString *)theWillTopic
{
    NSString *topic = [self stringForKey:@"willtopic_preference"];
    
    if (!topic || [topic isEqualToString:@""]) {
        topic = [self theGeneralTopic];
    }
    
    return topic;
}

- (NSString *)theClientId
{
    NSString *clientId;
    clientId = [self stringForKey:@"clientid_preference"];
    
    if (!clientId || [clientId isEqualToString:@""]) {
        clientId = [self theId];
    }
    return clientId;
}

- (NSString *)theId
{
    int mode = [self intForKey:@"mode"];
    NSString *theId;
    
    switch (mode) {
        case 2:
        case 1:
            theId = [NSString stringWithFormat:@"%@/%@", [self theUserId], [self theDeviceId]];
            break;
        case 0:
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

- (NSString *)theDeviceId
{
    int mode = [self intForKey:@"mode"];
    NSString *deviceId;
    
    switch (mode) {
        case 2:
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

- (NSString *)theSubscriptions
{
    int mode = [self intForKey:@"mode"];
    NSString *subscriptions;
    
    switch (mode) {
        case 2:
            subscriptions = [NSString stringWithFormat:@"public/user/+ public/user/+/event public/user/+/info public/user/%@/cmd",
                             [self theDeviceId]];
            break;
        case 1:
        case 0:
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

- (NSString *)theUserId {
    int mode = [self intForKey:@"mode"];
    switch (mode) {
        case 2:
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

- (NSString *)theMqttUser {
    int mode = [self intForKey:@"mode"];
    switch (mode) {
        case 2:
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

- (NSString *)theMqttPass {
    int mode = [self intForKey:@"mode"];
    switch (mode) {
        case 2:
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

- (BOOL)theMqttAuth {
    int mode = [self intForKey:@"mode"];
    switch (mode) {
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


@end
