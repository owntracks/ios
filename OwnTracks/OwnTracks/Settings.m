//
//  Settings.m
//  OwnTracks
//
//  Created by Christoph Krey on 31.01.14.
//  Copyright (c) 2014 Christoph Krey. All rights reserved.
//

#import "Settings.h"

@implementation Settings

- (id)init
{
    self = [super init];
    if (self) {
        
        NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];
        NSURL *plistURL = [bundleURL URLByAppendingPathComponent:@"Settings.plist"];

        NSDictionary *appDefaults = [NSDictionary dictionaryWithContentsOfURL:plistURL];
        [self registerDefaults:appDefaults];
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
            if (string) [self setObject:string forKey:@"deviceid_preference"];
            
            string = dictionary[@"clientid"];
            if (string) [self setObject:string forKey:@"clientid_preference"];
            
            string = dictionary[@"subTopic"];
            stringOld = dictionary[@"subscription"];
            if (string) [self setObject:string forKey:@"subscription_preference"];
            else if (stringOld) [self setObject:stringOld forKey:@"subscription_preference"];
            
            string = dictionary[@"pubTopicBase"];
            stringOld = dictionary[@"topic"];
            if (string) [self setObject:string forKey:@"topic_preference"];
            else if (stringOld) [self setObject:stringOld forKey:@"topic_preference"];
            
            string = dictionary[@"host"];
            if (string) [self setObject:string forKey:@"host_preference"];
            
            string = dictionary[@"username"];
            stringOld = dictionary[@"user"];
            if (string) [self setObject:string forKey:@"user_preference"];
            else if (stringOld) [self setObject:stringOld forKey:@"user_preference"];
            
            string = dictionary[@"pass"];
            stringOld = dictionary[@"password"];
            if (string) [self setObject:string forKey:@"pass_preference"];
            else if (stringOld) [self setObject:stringOld forKey:@"pass_preference"];
            
            string = dictionary[@"willTopic"];
            stringOld = dictionary[@"willtopic"];
            if (string) [self setObject:string forKey:@"willtopic_preference"];
            else if (stringOld) [self setObject:stringOld forKey:@"willtopic_preference"];
            
            
            string = dictionary[@"subQos"];
            stringOld = dictionary[@"subscriptionqos"];
            if (string) [self setObject:@([string integerValue]) forKey:@"subscriptionqos_preference"];
            else if (stringOld) [self setObject:@([stringOld integerValue]) forKey:@"subscriptionqos_preference"];
            
            string = dictionary[@"pubQos"];
            stringOld = dictionary[@"qos"];
            if (string) [self setObject:@([string integerValue]) forKey:@"qos_preference"];
            else if (stringOld) [self setObject:@([stringOld integerValue]) forKey:@"qos_preference"];
            
            string = dictionary[@"port"];
            if (string) [self setObject:@([string integerValue]) forKey:@"port_preference"];
            
            string = dictionary[@"keepalive"];
            if (string) [self setObject:@([string integerValue]) forKey:@"keepalive_preference"];
            
            string = dictionary[@"willQos"];
            stringOld = dictionary[@"willqos"];
            if (string) [self setObject:@([string integerValue]) forKey:@"willqos_preference"];
            else if (stringOld) [self setObject:@([stringOld integerValue]) forKey:@"willqos_preference"];
            
            string = dictionary[@"locatorDisplacement"];
            stringOld = dictionary[@"mindist"];
            if (string) [self setObject:@([string integerValue]) forKey:@"mindist_preference"];
            else if (stringOld) [self setObject:@([stringOld integerValue]) forKey:@"mindist_preference"];
            
            string = dictionary[@"locatorInterval"];
            stringOld = dictionary[@"mintime"];
            if (string) [self setObject:@([string integerValue]) forKey:@"mintime_preference"];
            else if (stringOld) [self setObject:@([stringOld integerValue]) forKey:@"mintime_preference"];
            
            string = dictionary[@"monitoring"];
            if (string) [self setObject:@([string integerValue]) forKey:@"monitoring_preference"];
            
            
            string = dictionary[@"pubRetain"];
            stringOld = dictionary[@"retain"];
            if (string) [self setObject:@([string integerValue]) forKey:@"retain_preference"];
            else if (stringOld) [self setObject:@([stringOld integerValue]) forKey:@"retain_preference"];
            
            string = dictionary[@"tls"];
            if (string) [self setObject:@([string integerValue]) forKey:@"tls_preference"];
            
            string = dictionary[@"auth"];
            if (string) [self setObject:@([string integerValue]) forKey:@"auth_preference"];
            
            string = dictionary[@"cleanSession"];
            stringOld = dictionary[@"clean"];
            if (string) [self setObject:@([string integerValue]) forKey:@"clean_preference"];
            else if (stringOld) [self setObject:@([stringOld integerValue]) forKey:@"clean_preference"];
            
            string = dictionary[@"willRetain"];
            stringOld = dictionary[@"willretain"];
            if (string) [self setObject:@([string integerValue]) forKey:@"willretain_preference"];
            else if (stringOld) [self setObject:@([stringOld integerValue]) forKey:@"willretain_preference"];
            
            string = dictionary[@"updateAddressBook"];
            stringOld = dictionary[@"ab"];
            if (string) [self setObject:@([string integerValue]) forKey:@"ab_preference"];
            else if (stringOld) [self setObject:@([stringOld integerValue]) forKey:@"ab_preference"];
            
            string = dictionary[@"positions"];
            if (string) [self setObject:@([string integerValue]) forKey:@"positions_preference"];
            
        } else {
            return [NSError errorWithDomain:@"OwnTracks Settings" code:1 userInfo:@{@"_type": dictionary[@"_type"]}];
        }
    } else {
        return error;
    }
    
    [self synchronize];
    return nil;
}

- (NSData *)toData
{
    NSDictionary *dict = @{@"_type": @"configuration",
                           @"deviceid": [self objectForKey:@"deviceid_preference"],
                           @"clientid": [self objectForKey:@"clientid_preference"],
                           @"subTopic": [self objectForKey:@"subscription_preference"],
                           @"pubTopicBase": [self objectForKey:@"topic_preference"],
                           @"host": [self objectForKey:@"host_preference"],
                           @"username": [self objectForKey:@"user_preference"],
                           @"password": @"password",
                           @"willTopic": [self objectForKey:@"willtopic_preference"],
                           
                           @"subQos": [self objectForKey:@"subscriptionqos_preference"],
                           @"pubQos": [self objectForKey:@"qos_preference"],
                           @"port": [self objectForKey:@"port_preference"],
                           @"keepalive": [self objectForKey:@"keepalive_preference"],
                           @"willQos": [self objectForKey:@"willqos_preference"],
                           @"locatorDisplacement": [self objectForKey:@"mindist_preference"],
                           @"locatorInterval": [self objectForKey:@"mintime_preference"],
                           @"monitoring": [self objectForKey:@"monitoring_preference"],
                           
                           @"pubRetain": [self objectForKey:@"retain_preference"],
                           @"tls": [self objectForKey:@"tls_preference"],
                           @"auth": [self objectForKey:@"auth_preference"],
                           @"cleanSession": [self objectForKey:@"clean_preference"],
                           @"willRetain": [self objectForKey:@"willretain_preference"],
                           @"updateAddressBook": [self objectForKey:@"ab_preference"],
                           @"positions": [self objectForKey:@"positions_preference"],
                           };
    
    NSError *error;
    NSData *myData = [NSJSONSerialization dataWithJSONObject:dict
                                                     options:NSJSONWritingPrettyPrinted
                                                       error:&error];
    return myData;
}

- (void)setObject:(id)value forKey:(NSString *)defaultName
{
    [super setObject:value forKey:defaultName];
    [self synchronize];
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


@end
