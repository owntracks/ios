//
//  LBS.m
//  OwnTracks
//
//  Created by Christoph Krey on 20.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "LBS.h"
#import "Message+Create.h"
#import "CoreData.h"
#import "OwnTracksAppDelegate.h"
#import <objc-geohash/GeoHash.h>
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

#define GEOHASH_LEN 7
#define GEOHASH_PRE @"lbs/"
#define GEOHASH_KEY @"lastGeoHash"

@interface LBS()
@property (strong, nonatomic) NSString *oldGeoHash;
@end

@implementation LBS

static const DDLogLevel ddLogLevel = DDLogLevelError;

- (instancetype)init {
    self = [super init];
    DDLogVerbose(@"LBS ddLogLevel %lu", (unsigned long)ddLogLevel);
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    self.lastGeoHash = [delegate.settings stringForKey:GEOHASH_KEY];
    self.oldGeoHash = @"";
    return self;
}

- (void)reset:(NSManagedObjectContext *)context {
    NSString *geoHash = self.lastGeoHash;
    self.oldGeoHash = self.lastGeoHash;
    self.lastGeoHash = @"";
    [self manageSubscriptions:context];
    [Message removeMessages:context];
    self.oldGeoHash = @"";
    self.lastGeoHash = geoHash;
    [self manageSubscriptions:context];
}

- (void)manageSubscriptions:(NSManagedObjectContext *)context {
    for (int i = 0; i < self.oldGeoHash.length; i++) {
        NSString *old = [self.oldGeoHash substringWithRange:NSMakeRange(i, 1)];
        NSString *last;
        if (i < self.lastGeoHash.length) {
            last = [self.lastGeoHash substringWithRange:NSMakeRange(i, 1)];
        } else {
            last = @"";
        }
        if (![old isEqualToString:last]) {
            OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[[UIApplication sharedApplication] delegate];
            NSString *topic = [NSString stringWithFormat:@"%@+/%@",
                               GEOHASH_PRE,
                               [self.oldGeoHash substringToIndex:i + 1]];
            [delegate.connectionIn removeSubscriptionFrom:topic];
            [Message removeMessages:[self.oldGeoHash substringToIndex:i + 1] context:context];
        }
    }
    for (int i = 0; i < self.lastGeoHash.length; i++) {
        NSString *last = [self.lastGeoHash substringWithRange:NSMakeRange(i, 1)];
        NSString *old;
        if (i < self.oldGeoHash.length) {
            old = [self.oldGeoHash substringWithRange:NSMakeRange(i, 1)];
        } else {
            old = @"";
        }
        if (![last isEqualToString:old]) {
            OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[[UIApplication sharedApplication] delegate];
            [delegate.connectionIn addSubscriptionTo:[NSString stringWithFormat:@"%@+/%@",
                                                      GEOHASH_PRE,
                                                      [self.lastGeoHash substringToIndex:i + 1]]
                                                 qos:MQTTQosLevelExactlyOnce];
        }
    }
    NSError *error = nil;
    if (![context save:&error]) {
        DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
        [[Crashlytics sharedInstance] setObjectValue:@"manageSubscriptions" forKey:@"CrashType"];
        [[Crashlytics sharedInstance] crash];
    }
}

- (void)newLocation:(double)latitude longitude:(double)longitude context:(NSManagedObjectContext *)context {
    NSString *geoHash = [GeoHash hashForLatitude:latitude
                                       longitude:longitude
                                          length:GEOHASH_LEN];
    DDLogVerbose(@"geoHash %@", geoHash);
    
    if (![self.lastGeoHash isEqualToString:geoHash]) {
        self.oldGeoHash = self.lastGeoHash;
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[[UIApplication sharedApplication] delegate];
        [delegate.settings setString: geoHash forKey:GEOHASH_KEY];
        self.lastGeoHash = geoHash;
        DDLogVerbose(@"geoHash %@", geoHash);
        
        [self manageSubscriptions:context];
    }
}

- (BOOL)processMessage:(NSString *)topic
                  data:(NSData *)data
              retained:(BOOL)retained
               context:(NSManagedObjectContext *)context {
    if ([topic hasPrefix:GEOHASH_PRE]) {
        NSArray *components = [topic componentsSeparatedByString:@"/"];
        if (components.count == 3) {
            NSString *geoHash = components[2];
            if ([self.lastGeoHash hasPrefix:geoHash]) {
                NSError *error;
                NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                if (dictionary) {
                    NSString *desc = dictionary[@"desc"];
                    NSString *url = dictionary[@"url"];
                    
                    [context performBlock:^{
                        Message *message = [Message messageWithTopic:topic
                                                           timestamp:[NSDate date]
                                                              expiry:[NSDate dateWithTimeIntervalSinceNow:24*2600]
                                                                desc:desc
                                                                 url:url
                                              inManagedObjectContext:context];
                        DDLogVerbose(@"Message %@", message);
                        NSError *error = nil;
                        if (![context save:&error]) {
                            DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
                            [[Crashlytics sharedInstance] setObjectValue:@"messageWithTopic" forKey:@"CrashType"];
                            [[Crashlytics sharedInstance] crash];
                        }
                        
                    }];
                    
                } else {
                    DDLogVerbose(@"illegal json %@ %@ %@", error.localizedDescription, error.userInfo, data.description);
                }
                return TRUE;
            } else {
                DDLogVerbose(@"remove topic %@", topic);
                OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[[UIApplication sharedApplication] delegate];
                [delegate.connectionIn removeSubscriptionFrom:topic];
                [Message removeMessages:topic context:context];
                return TRUE;
            }
        } else {
            DDLogVerbose(@"illegal lbs topic %@", topic);
            return FALSE;
        }
    } else {
        return FALSE;
    }
}

@end
