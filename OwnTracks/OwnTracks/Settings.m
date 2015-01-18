//
//  Settings.m
//  OwnTracks
//
//  Created by Christoph Krey on 31.01.14.
//  Copyright (c) 2014-2015 Christoph Krey. All rights reserved.
//

#import "Settings.h"
#import "Setting+Create.h"
#import "CoreData.h"
#import "Location+Create.h"

@interface Settings ()
@property (strong, nonatomic) NSDictionary *appDefaults;
@end

@implementation Settings

- (id)init
{
    self = [super init];
    if (self) {
        
        NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];
        NSURL *plistURL = [bundleURL URLByAppendingPathComponent:@"Settings.plist"];

        self.appDefaults = [NSDictionary dictionaryWithContentsOfURL:plistURL];
    }
    return self;
}

- (NSError *)fromStream:(NSInputStream *)input
{
    NSError *error;
    
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithStream:input options:0 error:&error];
    if (dictionary) {
#ifdef DEBUG
        for (NSString *key in [dictionary allKeys]) {
            NSLog(@"Configuration %@:%@", key, dictionary[key]);
        }
#endif
        
        if ([dictionary[@"_type"] isEqualToString:@"configuration"]) {
            NSString *stringOld;
            NSString *string;
            
            string = dictionary[@"deviceid"];
            if (string) [self setString:string forKey:@"deviceid_preference"];
            
            string = dictionary[@"trackerid"];
            if (string) [self setString:string forKey:@"trackerid_preference"];
            
            string = dictionary[@"clientid"];
            if (string) [self setString:string forKey:@"clientid_preference"];
            
            string = dictionary[@"subTopic"];
            stringOld = dictionary[@"subscription"];
            if (string) [self setString:string forKey:@"subscription_preference"];
            else if (stringOld) [self setString:string forKey:@"subscription_preference"];
            
            string = dictionary[@"pubTopicBase"];
            stringOld = dictionary[@"topic"];
            if (string) [self setString:string forKey:@"topic_preference"];
            else if (stringOld) [self setString:stringOld forKey:@"topic_preference"];
            
            string = dictionary[@"host"];
            if (string) [self setString:string forKey:@"host_preference"];
            
            string = dictionary[@"username"];
            stringOld = dictionary[@"user"];
            if (string) [self setString:string forKey:@"user_preference"];
            else if (stringOld) [self setString:stringOld forKey:@"user_preference"];
            
            string = dictionary[@"pass"];
            stringOld = dictionary[@"password"];
            if (string) [self setString:string forKey:@"pass_preference"];
            else if (stringOld) [self setString:stringOld forKey:@"pass_preference"];
            
            string = dictionary[@"willTopic"];
            stringOld = dictionary[@"willtopic"];
            if (string) [self setString:string forKey:@"willtopic_preference"];
            else if (stringOld) [self setString:stringOld forKey:@"willtopic_preference"];
            
            
            string = dictionary[@"subQos"];
            stringOld = dictionary[@"subscriptionqos"];
            if (string) [self setString:string forKey:@"subscriptionqos_preference"];
            else if (stringOld) [self setString:stringOld forKey:@"subscriptionqos_preference"];
            
            string = dictionary[@"pubQos"];
            stringOld = dictionary[@"qos"];
            if (string) [self setString:string forKey:@"qos_preference"];
            else if (stringOld) [self setString:stringOld forKey:@"qos_preference"];
            
            string = dictionary[@"port"];
            if (string) [self setString:string forKey:@"port_preference"];
            
            string = dictionary[@"keepalive"];
            if (string) [self setString:string forKey:@"keepalive_preference"];
            
            string = dictionary[@"willQos"];
            stringOld = dictionary[@"willqos"];
            if (string) [self setString:string forKey:@"willqos_preference"];
            else if (stringOld) [self setString:stringOld forKey:@"willqos_preference"];
            
            string = dictionary[@"locatorDisplacement"];
            stringOld = dictionary[@"mindist"];
            if (string) [self setString:string forKey:@"mindist_preference"];
            else if (stringOld) [self setString:stringOld forKey:@"mindist_preference"];
            
            string = dictionary[@"locatorInterval"];
            stringOld = dictionary[@"mintime"];
            if (string) [self setString:string forKey:@"mintime_preference"];
            else if (stringOld) [self setString:stringOld forKey:@"mintime_preference"];
            
            string = dictionary[@"monitoring"];
            if (string) [self setString:string forKey:@"monitoring_preference"];
            
            string = dictionary[@"ranging"];
            if (string) [self setString:string forKey:@"ranging_preference"];

            string = dictionary[@"cmd"];
            if (string) [self setString:string forKey:@"cmd_preference"];
            
            
            string = dictionary[@"pubRetain"];
            stringOld = dictionary[@"retain"];
            if (string) [self setString:string forKey:@"retain_preference"];
            else if (stringOld) [self setString:stringOld forKey:@"retain_preference"];
            
            string = dictionary[@"tls"];
            if (string) [self setString:string forKey:@"tls_preference"];
            
            string = dictionary[@"auth"];
            if (string) [self setString:string forKey:@"auth_preference"];
            
            string = dictionary[@"cleanSession"];
            stringOld = dictionary[@"clean"];
            if (string) [self setString:string forKey:@"clean_preference"];
            else if (stringOld) [self setString:stringOld forKey:@"clean_preference"];
            
            string = dictionary[@"willRetain"];
            stringOld = dictionary[@"willretain"];
            if (string) [self setString:string forKey:@"willretain_preference"];
            else if (stringOld) [self setString:stringOld forKey:@"willretain_preference"];
            
            string = dictionary[@"updateAddressBook"];
            stringOld = dictionary[@"ab"];
            if (string) [self setString:string forKey:@"ab_preference"];
            else if (stringOld) [self setString:stringOld forKey:@"ab_preference"];
            
            string = dictionary[@"positions"];
            if (string) [self setString:string forKey:@"positions_preference"];
            
            string = dictionary[@"allowRemoteLocation"];
            if (string) [self setString:string forKey:@"allowremotelocation_preference"];
            
            string = dictionary[@"extendedData"];
            if (string) [self setString:string forKey:@"extendeddata_preference"];

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
#ifdef DEBUG
        for (NSString *key in [dictionary allKeys]) {
            NSLog(@"Waypoints %@:%@", key, dictionary[key]);
        }
#endif
        
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
#ifdef DEBUG
                NSLog(@"Waypoint tst:%g lon:%g lat:%g",
                      [waypoint[@"tst"] doubleValue],
                      [waypoint[@"lon"] doubleValue],
                      [waypoint[@"lat"] doubleValue]
                      );
#endif
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
                                        tid:nil
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
                                   @"lat": [NSString stringWithFormat:@"%g", location.coordinate.latitude],
                                   @"lon": [NSString stringWithFormat:@"%g", location.coordinate.longitude],
                                   @"tst": [NSString stringWithFormat:@"%.0f", [location.timestamp timeIntervalSince1970]],
                                   @"rad": [NSString stringWithFormat:@"%g", [location.regionradius doubleValue]],
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
                           
                           @"subQos": [self stringForKey:@"subscriptionqos_preference"],
                           @"pubQos": [self stringForKey:@"qos_preference"],
                           @"port": [self stringForKey:@"port_preference"],
                           @"keepalive": [self stringForKey:@"keepalive_preference"],
                           @"willQos": [self stringForKey:@"willqos_preference"],
                           @"locatorDisplacement": [self stringForKey:@"mindist_preference"],
                           @"locatorInterval": [self stringForKey:@"mintime_preference"],
                           @"monitoring": [self stringForKey:@"monitoring_preference"],
                           @"ranging": [self stringForKey:@"ranging_preference"],
                           @"cmd": [self stringForKey:@"cmd_preference"],
                           
                           @"pubRetain": [self stringForKey:@"retain_preference"],
                           @"tls": [self stringForKey:@"tls_preference"],
                           @"auth": [self stringForKey:@"auth_preference"],
                           @"cleanSession": [self stringForKey:@"clean_preference"],
                           @"willRetain": [self stringForKey:@"willretain_preference"],
                           @"updateAddressBook": [self stringForKey:@"ab_preference"],
                           @"allowRemoteLocation": [self stringForKey:@"allowremotelocation_preference"],
                           @"extendedData": [self stringForKey:@"extendeddata_preference"],
                           @"positions": [self stringForKey:@"positions_preference"],
                           @"tid": [self stringForKey:@"trackerid_preference"],
                           
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


- (void)setString:(NSString *)string forKey:(NSString *)key
{
    Setting *setting = [Setting settingWithKey:key inManagedObjectContext:[CoreData theManagedObjectContext]];
    setting.value = string;
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
    
    Setting *setting = [Setting existsSettingWithKey:key inManagedObjectContext:[CoreData theManagedObjectContext]];
    if (setting) {
        value = setting.value;
    } else {
        // if value not found in Core Data, try to MIGRATE it from NSUserdefaults
        id object = [[NSUserDefaults standardUserDefaults] objectForKey:key];
        if (object) {
            if ([object isKindOfClass:[NSString class]]) {
                value = (NSString *)object;
            } else if ([object isKindOfClass:[NSNumber class]]) {
                value = [(NSNumber *)object stringValue];
            }
            if (value) {
                [self setString:value forKey:key];
            }
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
    NSString *topic;
    topic = [self stringForKey:@"topic_preference"];
    
    if (!topic || [topic isEqualToString:@""]) {
        topic = [NSString stringWithFormat:@"owntracks/%@", [self theId]];
    }
    return topic;
}

- (NSString *)theWillTopic
{
    NSString *topic;
    topic = [self stringForKey:@"willtopic_preference"];
    
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
    NSString *theId;
    NSString *user;
    user = [self stringForKey:@"user_preference"];
    NSString *deviceId;
    deviceId = [self stringForKey:@"deviceid_preference"];
    
    if (!user || [user isEqualToString:@""]) {
        if (!deviceId || [deviceId isEqualToString:@""]) {
            theId = [[UIDevice currentDevice] name];
        } else {
            theId = deviceId;
        }
    } else {
        if (!deviceId || [deviceId isEqualToString:@""]) {
            theId = user;
        } else {
            theId = [NSString stringWithFormat:@"%@/%@", user, deviceId];
        }
    }
    
    return theId;
}

- (NSString *)theDeviceId
{
    NSString *deviceId;
    deviceId = [self stringForKey:@"deviceid_preference"];
    return deviceId;
}

- (NSString *)theSubscriptions
{
    NSString *subscriptions;
    subscriptions = [self stringForKey:@"subscription_preference"];
    
    if (!subscriptions || [subscriptions isEqualToString:@""]) {
        subscriptions = [NSString stringWithFormat:@"owntracks/+/+ owntracks/%@/#", [self theId]];
    }
    return subscriptions;
}



@end
