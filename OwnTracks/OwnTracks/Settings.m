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
        NSDictionary *appDefaults = @{
                                      @"mindist_preference" : @(200),
                                      @"mintime_preference" : @(180),
                                      @"deviceid_preference" : @"",
                                      @"clientid_preference" : @"",
                                      @"subscription_preference" : @"owntracks/#",
                                      @"subscriptionqos_preference": @(1),
                                      @"topic_preference" : @"",
                                      @"retain_preference": @(TRUE),
                                      @"qos_preference": @(1),
                                      @"host_preference" : @"host",
                                      @"port_preference" : @(8883),
                                      @"tls_preference": @(YES),
                                      @"auth_preference": @(YES),
                                      @"user_preference": @"user",
                                      @"pass_preference": @"pass",
                                      @"keepalive_preference" : @(60),
                                      @"clean_preference" : @(NO),
                                      @"will_preference": @"lwt",
                                      @"willtopic_preference": @"",
                                      @"willretain_preference":@(NO),
                                      @"willqos_preference": @(1),
                                      @"monitoring_preference": @(1),
                                      @"ab_preference": @(YES)
                                      };
        [self registerDefaults:appDefaults];
        [self synchronize];
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
            NSString *string;
            
            string = dictionary[@"deviceid"];
            if (string) [self setObject:string forKey:@"deviceid_preference"];
            
            string = dictionary[@"clientid"];
            if (string) [self setObject:string forKey:@"clientid_preference"];
            
            string = dictionary[@"subscription"];
            if (string) [self setObject:string forKey:@"subscription_preference"];
            
            string = dictionary[@"topic"];
            if (string) [self setObject:string forKey:@"topic_preference"];
            
            string = dictionary[@"host"];
            if (string) [self setObject:string forKey:@"host_preference"];
            
            string = dictionary[@"user"];
            if (string) [self setObject:string forKey:@"user_preference"];
            
            string = dictionary[@"pass"];
            if (string) [self setObject:string forKey:@"pass_preference"];
            
            string = dictionary[@"will"];
            if (string) [self setObject:string forKey:@"will_preference"];
            
            string = dictionary[@"willtopic"];
            if (string) [self setObject:string forKey:@"willtopic_preference"];
            
            
            string = dictionary[@"subscriptionqos"];
            if (string) [self setObject:@([string integerValue]) forKey:@"subscriptionqos_preference"];
            
            string = dictionary[@"qos"];
            if (string) [self setObject:@([string integerValue]) forKey:@"qos_preference"];
            
            string = dictionary[@"port"];
            if (string) [self setObject:@([string integerValue]) forKey:@"port_preference"];
            
            string = dictionary[@"keepalive"];
            if (string) [self setObject:@([string integerValue]) forKey:@"keepalive_preference"];
            
            string = dictionary[@"willqos"];
            if (string) [self setObject:@([string integerValue]) forKey:@"willqos_preference"];
            
            string = dictionary[@"mindist"];
            if (string) [self setObject:@([string integerValue]) forKey:@"mindist_preference"];
            
            string = dictionary[@"mintime"];
            if (string) [self setObject:@([string integerValue]) forKey:@"mintime_preference"];
            
            string = dictionary[@"monitoring"];
            if (string) [self setObject:@([string integerValue]) forKey:@"monitoring_preference"];
            
            
            string = dictionary[@"retain"];
            if (string) [self setObject:@([string integerValue]) forKey:@"retain_preference"];
            
            string = dictionary[@"tls"];
            if (string) [self setObject:@([string integerValue]) forKey:@"tls_preference"];
            
            string = dictionary[@"auth"];
            if (string) [self setObject:@([string integerValue]) forKey:@"auth_preference"];
            
            string = dictionary[@"clean"];
            if (string) [self setObject:@([string integerValue]) forKey:@"clean_preference"];
            
            string = dictionary[@"willretain"];
            if (string) [self setObject:@([string integerValue]) forKey:@"willretain_preference"];
            
            string = dictionary[@"ab"];
            if (string) [self setObject:@([string integerValue]) forKey:@"ab_preference"];
            
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
                           @"subsription": [self objectForKey:@"subscription_preference"],
                           @"topic": [self objectForKey:@"topic_preference"],
                           @"host": [self objectForKey:@"host_preference"],
                           @"user": [self objectForKey:@"user_preference"],
                           @"pass": @"password",
                           @"will": [self objectForKey:@"will_preference"],
                           @"willtopic": [self objectForKey:@"willtopic_preference"],
                           
                           @"subscriptionqos": [self objectForKey:@"subscriptionqos_preference"],
                           @"qos": [self objectForKey:@"qos_preference"],
                           @"port": [self objectForKey:@"port_preference"],
                           @"keepalive": [self objectForKey:@"keepalive_preference"],
                           @"willqos": [self objectForKey:@"willqos_preference"],
                           @"mindist": [self objectForKey:@"mindist_preference"],
                           @"mintime": [self objectForKey:@"mintime_preference"],
                           @"monitoring": [self objectForKey:@"monitoring_preference"],
                           
                           @"retain": [self objectForKey:@"retain_preference"],
                           @"tls": [self objectForKey:@"tls_preference"],
                           @"auth": [self objectForKey:@"auth_preference"],
                           @"clean": [self objectForKey:@"clean_preference"],
                           @"willretain": [self objectForKey:@"willretain_preference"],
                           @"ab": [self objectForKey:@"ab_preference"],
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
