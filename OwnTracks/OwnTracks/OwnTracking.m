//
//  OwnTracking.m
//  OwnTracks
//
//  Created by Christoph Krey on 28.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "OwnTracking.h"
#import "Settings.h"
#import "OwnTracksAppDelegate.h"
#import "AlertView.h"
#import "Waypoint.h"
#import "CoreData.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

@implementation OwnTracking
static const DDLogLevel ddLogLevel = DDLogLevelError;
static OwnTracking *theInstance = nil;

+ (OwnTracking *)sharedInstance {
    if (theInstance == nil) {
        theInstance = [[OwnTracking alloc] init];
    }
    return theInstance;
}

- (instancetype)init {
    self = [super init];
    DDLogVerbose(@"ddLogLevel %lu", (unsigned long)ddLogLevel);
    self.inQueue = @(0);
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil queue:nil usingBlock:^(NSNotification *note){
                                                          [self share];
                                                      }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                      object:nil queue:nil usingBlock:^(NSNotification *note){
                                                          [self share];
                                                      }];
    return self;
}

- (void)syncProcessing {
    while ([self.inQueue unsignedLongValue] > 0) {
        DDLogVerbose(@"syncProcessing %lu", [self.inQueue unsignedLongValue]);
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    };
}

- (BOOL)processMessage:(NSString *)topic
                  data:(NSData *)data
              retained:(BOOL)retained
               context:(NSManagedObjectContext *)context {
    
    @synchronized (self.inQueue) {
        self.inQueue = @([self.inQueue unsignedLongValue] + 1);
    }
    [context performBlock:^{
            NSError *error;
            NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (dictionary) {
                NSArray *topicComponents = [topic componentsSeparatedByCharactersInSet:
                                            [NSCharacterSet characterSetWithCharactersInString:@"/"]];
                NSArray *baseComponents = [[Settings theGeneralTopic] componentsSeparatedByCharactersInSet:
                                           [NSCharacterSet characterSetWithCharactersInString:@"/"]];
                
                NSString *device = @"";
                BOOL ownDevice = true;
                
                for (int i = 0; i < [baseComponents count]; i++) {
                    if (i > 0) {
                        device = [device stringByAppendingString:@"/"];
                    }
                    if (i < topicComponents.count) {
                        device = [device stringByAppendingString:topicComponents[i]];
                        if (![baseComponents[i] isEqualToString:topicComponents [i]]) {
                            ownDevice = false;
                        }
                    } else {
                        ownDevice = false;
                    }
                }
                
                if (ownDevice) {
                    if ([dictionary[@"_type"] isEqualToString:@"card"]) {
                        [context performBlock:^{
                            Friend *friend = [Friend friendWithTopic:device
                                              inManagedObjectContext:context];
                            [self processFace:friend dictionary:dictionary];
                        }];
                    } else {
                        DDLogInfo(@"unhandled record type %@", dictionary[@"_type"]);
                    }
                } else /* not own device */ {
                    if (data.length) {
                        
                        if ([dictionary[@"_type"] isEqualToString:@"location"]) {
                            CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(
                                                                                           [dictionary[@"lat"] doubleValue],
                                                                                           [dictionary[@"lon"] doubleValue]
                                                                                           );
                            
                            CLLocation *location = [[CLLocation alloc] initWithCoordinate:coordinate
                                                                                 altitude:[dictionary[@"alt"] intValue]
                                                                       horizontalAccuracy:[dictionary[@"acc"] doubleValue]
                                                                         verticalAccuracy:[dictionary[@"vac"] intValue]
                                                                                   course:[dictionary[@"cog"] intValue]
                                                                                    speed:[dictionary[@"vel"] intValue]
                                                                                timestamp:[NSDate dateWithTimeIntervalSince1970:[dictionary[@"tst"] doubleValue]]];
                            Friend *friend = [Friend friendWithTopic:device inManagedObjectContext:context];
                            [self addWaypointFor:friend location:location trigger:dictionary[@"t"] context:context];
                            [self limitWaypointsFor:friend
                                          toMaximum:[Settings intForKey:@"positions_preference"]
                             inManagedObjectContext:context];
                        } else if ([dictionary[@"_type"] isEqualToString:@"transition"]) {
                            NSString *type = dictionary[@"t"];
                            if (!type || ![type isEqualToString:@"b"]) {
                                UILocalNotification *notification = [[UILocalNotification alloc] init];
                                notification.alertBody = [NSString stringWithFormat:@"%@ %@s %@",
                                                          dictionary[@"tid"],
                                                          dictionary[@"event"],
                                                          dictionary[@"desc"]];
                                notification.userInfo = @{@"notify": @"friend"};
                                notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:1.0];
                                [[UIApplication sharedApplication] scheduleLocalNotification:notification];
                                [AlertView alert:@"Friend" message:notification.alertBody dismissAfter:2.0];
                            }
                            
                        } else if ([dictionary[@"_type"] isEqualToString:@"card"]) {
                            Friend *friend = [Friend friendWithTopic:device
                                              inManagedObjectContext:context];
                            [self processFace:friend dictionary:dictionary];
                            
                        } else {
                            DDLogInfo(@"unknown record type %@)", dictionary[@"_type"]);
                        }
                    } else /* data.length == 0 -> delete friend */ {
                        Friend *friend = [Friend existsFriendWithTopic:device inManagedObjectContext:context];
                        if (friend) {
                            [context deleteObject:friend];
                        }
                    }
                }
            } else {
                DDLogError(@"illegal json %@, %@ %@)", error.localizedDescription, error.userInfo, data.description);
            }
        
        @synchronized (self.inQueue) {
            self.inQueue = @([self.inQueue unsignedLongValue] - 1);
        }
        if ([self.inQueue intValue] == 0) {
            [context save:nil];
            [self performSelectorOnMainThread:@selector(share) withObject:nil waitUntilDone:NO];
        }
    }];
    
    return TRUE;
}

- (void)processFace:(Friend *)friend dictionary:(NSDictionary *)dictionary {
    if (friend) {
        id string = dictionary[@"name"];
        if (string && [string isKindOfClass:[NSString class]]) {
            friend.cardName = (NSString *)string;
        } else {
            friend.cardName = nil;
        }
        id imageString = dictionary[@"face"];
        if (imageString && [imageString isKindOfClass:[NSString class]]) {
            NSData *imageData = [[NSData alloc] initWithBase64EncodedString:imageString options:0];
            friend.cardImage = imageData;
        } else {
            friend.cardImage = nil;
        }
    }
}

- (void)limitWaypointsFor:(Friend *)friend toMaximum:(NSInteger)max inManagedObjectContext:(NSManagedObjectContext *)context {
    while (friend.hasWaypoints.count > max) {
        DDLogVerbose(@"%@ hasWaypoints.count %lu", friend.topic, (unsigned long)friend.hasWaypoints.count);
        Waypoint *oldestWaypoint = nil;
        for (Waypoint *waypoint in friend.hasWaypoints) {
            if (!oldestWaypoint || (!waypoint.isDeleted && [oldestWaypoint.tst compare:waypoint.tst] == NSOrderedDescending)) {
                oldestWaypoint = waypoint;
            }
        }
        if (oldestWaypoint) {
            [context deleteObject:oldestWaypoint];
            [CoreData saveContext:context];
        }
    }
}

- (void)share {
    
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0"] != NSOrderedAscending) {
        NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:@"group.org.owntracks.Owntracks"];
        NSArray *friends = [Friend allFriendsInManagedObjectContext:[CoreData theManagedObjectContext]];
        NSMutableDictionary *sharedFriends = [[NSMutableDictionary alloc] init];
        CLLocation *myCLLocation = [LocationManager sharedInstance].location;
        
        for (Friend *friend in friends) {
            NSString *name = [friend name];
            NSData *image = [friend image];
            
            if (!image) {
                image = UIImageJPEGRepresentation([UIImage imageNamed:@"Friend"], 0.5);
            }
            
            Waypoint *waypoint = [friend newestWaypoint];
            if (waypoint) {
                CLLocation *location = [[CLLocation alloc]
                                        initWithLatitude:[waypoint.lat doubleValue]
                                        longitude:[waypoint.lon doubleValue]];
                NSNumber *distance = @([myCLLocation distanceFromLocation:location]);
                if (name) {
                    if (waypoint.tst &&
                        waypoint.lat &&
                        waypoint.lon &&
                        friend.topic &&
                        image) {
                        NSMutableDictionary *aFriend = [[NSMutableDictionary alloc] init];
                        [aFriend setObject:image forKey:@"image"];
                        [aFriend setObject:distance forKey:@"distance"];
                        [aFriend setObject:waypoint.lon forKey:@"longitude"];
                        [aFriend setObject:waypoint.lat forKey:@"latitude"];
                        [aFriend setObject:waypoint.tst forKey:@"timestamp"];
                        [aFriend setObject:friend.topic forKey:@"topic"];
                        [sharedFriends setObject:aFriend forKey:name];
                    } else {
                        DDLogError(@"friend or location incomplete");
                    }
                }
            }
        }
        DDLogVerbose(@"sharedFriends %@", [sharedFriends allKeys]);
        [shared setValue:sharedFriends forKey:@"sharedFriends"];
    }
}

- (Waypoint *)addWaypointFor:(Friend *)friend
                    location:(CLLocation *)location
                     trigger:(NSString *)trigger
                     context:(NSManagedObjectContext *)context {
    Waypoint *waypoint = [NSEntityDescription insertNewObjectForEntityForName:@"Waypoint"
                                                       inManagedObjectContext:context];
    waypoint.belongsTo = friend;
    waypoint.trigger = trigger;
    waypoint.acc = [NSNumber numberWithDouble:location.horizontalAccuracy];
    waypoint.alt = [NSNumber numberWithDouble:location.altitude];
    waypoint.lat = [NSNumber numberWithDouble:location.coordinate.latitude];
    waypoint.lon = [NSNumber numberWithDouble:location.coordinate.longitude];
    waypoint.vac = [NSNumber numberWithDouble:location.verticalAccuracy];
    waypoint.tst = location.timestamp;
    waypoint.vel = [NSNumber numberWithDouble:location.speed];
    waypoint.cog = [NSNumber numberWithDouble:location.course];
    waypoint.placemark = nil;
    
    [self limitWaypointsFor:friend toMaximum:[Settings intForKey:@"positions_preference"] inManagedObjectContext:context];
    return waypoint;
}

- (Region *)addRegionFor:(Friend *)friend
                    name:(NSString *)name
                    uuid:(NSString *)uuid
                   major:(unsigned int)major
                   minor:(unsigned int)minor
                   share:(BOOL)share
                  radius:(double)radius
                     lat:(double)lat
                     lon:(double)lon
                 context:(NSManagedObjectContext *)context {
    Region *region = [NSEntityDescription insertNewObjectForEntityForName:@"Region"
                                                   inManagedObjectContext:context];
    region.belongsTo = friend;
    region.name = name;
    region.uuid = uuid;
    region.major = [NSNumber numberWithUnsignedInt:major];
    region.minor = [NSNumber numberWithUnsignedInt:minor];
    region.share = [NSNumber numberWithBool:share];
    region.radius = [NSNumber numberWithDouble:radius];
    region.lat = [NSNumber numberWithDouble:lat];
    region.lon = [NSNumber numberWithDouble:lon];
    [[LocationManager sharedInstance] startRegion:region.CLregion];
    return region;
}

- (void)removeRegion:(Region *)region context:(NSManagedObjectContext *)context {
    [[LocationManager sharedInstance] startRegion:region.CLregion];
    [context deleteObject:region];
}


- (NSDictionary *)waypointAsJSON:(Waypoint *)waypoint {
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    [json setValue:@"location" forKey:@"_type"];
    if (waypoint.trigger) {
        [json setValue:waypoint.trigger forKey:@"t"];
    }
    
    [json setValue:waypoint.lat forKey:@"lat"];
    [json setValue:waypoint.lon forKey:@"lon"];
    [json setValue:@((int)[waypoint.tst timeIntervalSince1970]) forKey:@"tst"];
    
    if ([waypoint.acc doubleValue] > 0) {
        [json setValue:waypoint.acc forKey:@"acc"];
    }
    
    if ([Settings boolForKey:@"extendeddata_preference"]) {
        int alt = [waypoint.alt intValue];
        [json setValue:@(alt) forKey:@"alt"];
        
        int vac = [waypoint.vac intValue];
        [json setValue:@(vac) forKey:@"vac"];
        
        int vel = [waypoint.vel intValue];
        [json setValue:@(vel) forKey:@"vel"];
        
        int cog = [waypoint.cog intValue];
        [json setValue:@(cog) forKey:@"cog"];
        
        CMAltitudeData *altitude = [LocationManager sharedInstance].altitude;
        if (altitude) {
            [json setValue:altitude.pressure forKey:@"p"];
        }
    }
    
    [json setValue:[waypoint.belongsTo getEffectiveTid] forKeyPath:@"tid"];
    
    int batteryLevel = [UIDevice currentDevice].batteryLevel != -1 ? [UIDevice currentDevice].batteryLevel * 100 : -1;
    [json setValue:@(batteryLevel) forKey:@"batt"];
    
    return json;
}

- (NSDictionary *)regionAsJSON:(Region *)region {
    NSDictionary *json = @{@"_type": @"waypoint",
                           @"lat": region.lat,
                           @"lon": region.lon,
                           @"tst": [NSNumber numberWithLong:(long)([[NSDate date] timeIntervalSince1970])],
                           @"rad": region.radius,
                           @"desc": [NSString stringWithFormat:@"%@%@%@%@",
                                     region.name,
                                     region.uuid ? [NSString stringWithFormat: @":%@", region.uuid] : @"",
                                     [region.major unsignedIntValue] ? [NSString stringWithFormat: @":%@", region.major] : @"",
                                     [region.minor unsignedIntValue]? [NSString stringWithFormat: @":%@", region.minor] : @""]
                           };
    return json;
}
@end
