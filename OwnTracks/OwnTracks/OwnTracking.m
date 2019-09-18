//
//  OwnTracking.m
//  OwnTracks
//
//  Created by Christoph Krey on 28.06.15.
//  Copyright © 2015 -2019 OwnTracks. All rights reserved.
//

#import "OwnTracking.h"
#import "Settings.h"
#import "OwnTracksAppDelegate.h"
#import "Waypoint+CoreDataClass.h"
#import "History+CoreDataClass.h"
#import "CoreData.h"
#import "ConnType.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <UserNotifications/UserNotifications.h>
#import <UserNotifications/UNUserNotificationCenter.h>

#define MAXQUEUE 999

@implementation OwnTracking
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
static OwnTracking *theInstance = nil;

+ (OwnTracking *)sharedInstance {
    if (theInstance == nil) {
        theInstance = [[OwnTracking alloc] init];
    }
    return theInstance;
}

- (instancetype)init {
    self = [super init];
    self.inQueue = @(0);

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil queue:nil usingBlock:^(NSNotification *note){
                                                          [self performSelectorOnMainThread:@selector(share) withObject:nil waitUntilDone:NO];
                                                      }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                      object:nil queue:nil usingBlock:^(NSNotification *note){
                                                          [self performSelectorOnMainThread:@selector(share) withObject:nil waitUntilDone:NO];
                                                      }];
    return self;
}

- (void)syncProcessing {
    while ((self.inQueue).unsignedLongValue > 0) {
        DDLogVerbose(@"syncProcessing %lu", [self.inQueue unsignedLongValue]);
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    };
}

- (BOOL)processMessage:(NSString *)topic
                  data:(NSData *)data
              retained:(BOOL)retained
               context:(NSManagedObjectContext *)context {

    if ((self.inQueue).unsignedLongValue < MAXQUEUE) {
        @synchronized (self.inQueue) {
            self.inQueue = @((self.inQueue).unsignedLongValue + 1);
        }
        [context performBlock:^{
            NSError *error;
            DDLogVerbose(@"performBlock %@ %@", topic, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);

            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (json && [json isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dictionary = json;
                NSArray *topicComponents = [topic componentsSeparatedByString:@"/"];
                NSArray *baseComponents = [[Settings theGeneralTopicInMOC:context]
                                           componentsSeparatedByString:@"/"];

                NSString *device = @"";
                BOOL ownDevice = true;

                for (int i = 0; i < baseComponents.count; i++) {
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
                            CLLocationCoordinate2D coordinate =
                            CLLocationCoordinate2DMake(
                                                       [dictionary[@"lat"] doubleValue],
                                                       [dictionary[@"lon"] doubleValue]
                                                       );

                            int speed = [dictionary[@"vel"] intValue];
                            if (speed != -1) {
                                speed = speed * 1000 / 3600;
                            }
                            CLLocation *location = [[CLLocation alloc]
                                                    initWithCoordinate:coordinate
                                                    altitude:[dictionary[@"alt"] intValue]
                                                    horizontalAccuracy:[dictionary[@"acc"] doubleValue]
                                                    verticalAccuracy:[dictionary[@"vac"] intValue]
                                                    course:[dictionary[@"cog"] intValue]
                                                    speed:speed
                                                    timestamp:[NSDate dateWithTimeIntervalSince1970:[dictionary[@"tst"] doubleValue]]];
                            Friend *friend = [Friend friendWithTopic:device inManagedObjectContext:context];
                            friend.tid = dictionary[@"tid"];
                            [self addWaypointFor:friend location:location
                                         trigger:dictionary[@"t"]
                                         context:context];
                            [self limitWaypointsFor:friend
                                          toMaximum:[Settings intForKey:@"positions_preference" inMOC:context]];
                        } else if ([dictionary[@"_type"] isEqualToString:@"transition"]) {
                            [self performSelectorOnMainThread:@selector(processTransitionMessage:)
                                                   withObject:dictionary
                                                waitUntilDone:NO];

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
                self.inQueue = @((self.inQueue).unsignedLongValue - 1);
            }
            if ((self.inQueue).intValue == 0) {
                [context save:nil];
                [self performSelectorOnMainThread:@selector(share) withObject:nil waitUntilDone:NO];
            }
        }];

        return TRUE;
    } else {
        return FALSE;
    }
}

- (void)processTransitionMessage:(NSDictionary *)dictionary {
    NSString *type = dictionary[@"t"];
    if (!type || ![type isEqualToString:@"b"]) {
        NSString *tid = dictionary[@"tid"];
        NSDate *tst = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"tst"] doubleValue]];
        NSString *event = dictionary[@"event"];
        NSString *desc = dictionary[@"desc"];
        if (!desc) {
            desc = NSLocalizedString(@"a region",
                                     @"name of an unknown or hidden region");
        }

        NSString *shortTime = [NSDateFormatter
                               localizedStringFromDate:tst
                               dateStyle:NSDateFormatterShortStyle
                               timeStyle:NSDateFormatterShortStyle];

        NSString *notificationMessage = [NSString stringWithFormat:@"%@ %@s %@ @ %@",
                                         tid,
                                         event,
                                         desc,
                                         shortTime];

        NSString *notificationIdentifier = [NSString stringWithFormat:@"transition%@%f",
                                            tid,
                                            tst.timeIntervalSince1970];

        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.body = notificationMessage;
        content.userInfo = @{@"notify": @"friend"};
        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger
                                                      triggerWithTimeInterval:1.0
                                                      repeats:NO];
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:notificationIdentifier
                                                                              content:content
                                                                              trigger:trigger];
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center addNotificationRequest:request withCompletionHandler:nil];

        NSString *shortNotificationMessage = [NSString stringWithFormat:@"%@ %@s %@",
                                         tid,
                                         event,
                                         desc];

        [History historyInGroup:@"Friend"
                       withText:shortNotificationMessage
                             at:tst
                          inMOC:[CoreData sharedInstance].mainMOC
                        maximum:[Settings theMaximumHistoryInMOC:[CoreData sharedInstance].mainMOC]];
        [CoreData.sharedInstance sync:CoreData.sharedInstance.queuedMOC];

        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [delegate.navigationController alert:NSLocalizedString(@"Friend",
                                                               @"Alert message header for friend's messages")
                                     message:notificationMessage
                                dismissAfter:2.0
         ];
    }
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

- (void)limitWaypointsFor:(Friend *)friend
                toMaximum:(NSInteger)max {
    while (friend.hasWaypoints.count > max) {
        DDLogVerbose(@"%@ hasWaypoints.count %lu", friend.topic, (unsigned long)friend.hasWaypoints.count);
        Waypoint *oldestWaypoint = nil;
        for (Waypoint *waypoint in friend.hasWaypoints) {
            if (!oldestWaypoint || (!waypoint.isDeleted && [oldestWaypoint.tst compare:waypoint.tst] == NSOrderedDescending)) {
                oldestWaypoint = waypoint;
            }
        }
        if (oldestWaypoint) {
            [friend.managedObjectContext deleteObject:oldestWaypoint];
            [CoreData.sharedInstance sync:friend.managedObjectContext];
        }
    }
    Waypoint *newestWaypoint = nil;
    for (Waypoint *waypoint in friend.hasWaypoints) {
        if (!newestWaypoint || (!waypoint.isDeleted && [newestWaypoint.tst compare:waypoint.tst] == NSOrderedAscending)) {
            newestWaypoint = waypoint;
        }
    }
    if (newestWaypoint && ![newestWaypoint.tst isEqualToDate:friend.lastLocation]) {
        friend.lastLocation = newestWaypoint.tst;
        [CoreData.sharedInstance sync:friend.managedObjectContext];
    }
}

- (void)share {
    NSArray *friends = [Friend allNonStaleFriendsInManagedObjectContext:CoreData.sharedInstance.mainMOC];
    NSMutableDictionary *sharedFriends = [[NSMutableDictionary alloc] init];
    CLLocation *myCLLocation = [LocationManager sharedInstance].location;
    
    for (Friend *friend in friends) {
        NSString *name = friend.name;
        NSData *image = friend.image;
        
        if (!image) {
            image = UIImageJPEGRepresentation([UIImage imageNamed:@"Friend"], 0.5);
        }
        
        Waypoint *waypoint = friend.newestWaypoint;
        if (waypoint) {
            CLLocation *location = [[CLLocation alloc]
                                    initWithLatitude:(waypoint.lat).doubleValue
                                    longitude:(waypoint.lon).doubleValue];
            NSNumber *distance = @([myCLLocation distanceFromLocation:location]);
            if (name) {
                if (waypoint.tst &&
                    waypoint.lat &&
                    waypoint.lon &&
                    friend.topic &&
                    image) {
                    NSMutableDictionary *aFriend = [[NSMutableDictionary alloc] init];
                    aFriend[@"image"] = image;
                    aFriend[@"distance"] = distance;
                    aFriend[@"longitude"] = waypoint.lon;
                    aFriend[@"latitude"] = waypoint.lat;
                    aFriend[@"timestamp"] = waypoint.tst;
                    aFriend[@"topic"] = friend.topic;
                    sharedFriends[name] = aFriend;
                } else {
                    DDLogError(@"friend or location incomplete");
                }
            }
        }
    }
    DDLogVerbose(@"sharedFriends %@", [sharedFriends allKeys]);
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:@"group.org.owntracks.Owntracks"];
    [shared setValue:sharedFriends forKey:@"sharedFriends"];
}

- (Waypoint *)addWaypointFor:(Friend *)friend
                    location:(CLLocation *)location
                     trigger:(NSString *)trigger
                     context:(NSManagedObjectContext *)context {
    Waypoint *waypoint = [NSEntityDescription insertNewObjectForEntityForName:@"Waypoint"
                                                       inManagedObjectContext:context];
    waypoint.belongsTo = friend;
    waypoint.trigger = trigger;
    waypoint.acc = @(location.horizontalAccuracy);
    waypoint.alt = @(location.altitude);
    waypoint.lat = @(location.coordinate.latitude);
    waypoint.lon = @(location.coordinate.longitude);
    waypoint.vac = @(location.verticalAccuracy);
    waypoint.tst = location.timestamp;
    double speed = location.speed;
    if (speed != -1) {
        speed = speed * 3600 / 1000;
    }
    waypoint.vel = @(speed);
    waypoint.cog = @(location.course);
    waypoint.placemark = nil;

    return waypoint;
}

- (Region *)addRegionFor:(Friend *)friend
                    name:(NSString *)name
                    uuid:(NSString *)uuid
                   major:(unsigned int)major
                   minor:(unsigned int)minor
                  radius:(double)radius
                     lat:(double)lat
                     lon:(double)lon
                 context:(NSManagedObjectContext *)context {
    Region *region = [NSEntityDescription insertNewObjectForEntityForName:@"Region"
                                                   inManagedObjectContext:context];
    region.belongsTo = friend;
    region.tst = [NSDate date];
    region.name = name;
    region.uuid = uuid;
    region.major = @(major);
    region.minor = @(minor);
    region.radius = @(radius);
    region.lat = @(lat);
    region.lon = @(lon);
    [[LocationManager sharedInstance] startRegion:region.CLregion];
    return region;
}

- (void)removeRegion:(Region *)region context:(NSManagedObjectContext *)context {
    [[LocationManager sharedInstance] stopRegion:region.CLregion];
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
    [json setValue:@((int)(waypoint.tst).timeIntervalSince1970) forKey:@"tst"];

    int acc = (waypoint.acc).intValue;
    if (acc >= 0) {
        [json setValue:@(acc) forKey:@"acc"];
    }

    if ([Settings boolForKey:@"extendeddata_preference" inMOC:waypoint.managedObjectContext]) {
        int alt = (waypoint.alt).intValue;
        [json setValue:@(alt) forKey:@"alt"];

        int vac = (waypoint.vac).intValue;
        if (vac >= 0) {
            [json setValue:@(vac) forKey:@"vac"];
        }

        int vel = (waypoint.vel).intValue;
        if (vel >= 0) {
            [json setValue:@(vel) forKey:@"vel"];
        }

        int cog = (waypoint.cog).intValue;
        if (cog >= 0) {
            [json setValue:@(cog) forKey:@"cog"];
        }

        CMAltitudeData *altitude = [LocationManager sharedInstance].altitude;
        if (altitude) {
            [json setValue:altitude.pressure forKey:@"p"];
        }

        switch ([ConnType connectionType:[Settings theHostInMOC:waypoint.managedObjectContext]]) {
            case ConnectionTypeNone:
                json[@"conn"] = @"o";
                break;

            case ConnectionTypeWIFI:
                json[@"conn"] = @"w";
                break;

            case ConnectionTypeWWAN:
                json[@"conn"] = @"m";
                break;

            case ConnectionTypeUnknown:
            default:
                break;
        }
    }

    NSString *tid = [Settings stringForKey:@"trackerid_preference" inMOC:waypoint.managedObjectContext];
    if (tid && tid.length > 0) {
        [json setValue:tid forKeyPath:@"tid"];
    } else {
        [json setValue:(waypoint.belongsTo).effectiveTid forKeyPath:@"tid"];
    }

    float batteryLevel = [UIDevice currentDevice].batteryLevel;
    if (batteryLevel != -1) {
        int batteryLevelInt = batteryLevel * 100;
        [json setValue:@(batteryLevelInt) forKey:@"batt"];
    }

    UIDeviceBatteryState batteryState = [UIDevice currentDevice].batteryState;
    if (batteryState != UIDeviceBatteryStateUnknown) {
        [json setValue:@(batteryState) forKey:@"bs"];
    }

    NSMutableArray <NSString *> *inRegions = [[NSMutableArray alloc] init];
    for (Region *region in waypoint.belongsTo.hasRegions) {
        if (![region.name hasPrefix:@"+"]) {
            if ([LocationManager sharedInstance].insideCircularRegions[region.name] ||
                [LocationManager sharedInstance].insideBeaconRegions[region.name]) {
                [inRegions addObject:region.name];
            }
        }
    }

    if (inRegions.count > 0) {
        json[@"inregions"] = inRegions;
    }

    return json;
}

- (NSDictionary *)regionAsJSON:(Region *)region {
    NSDictionary *json = @{@"_type": @"waypoint",
                           @"lat": region.lat,
                           @"lon": region.lon,
                           @"rad": region.radius,
                           @"tst": @(floor(region.andFillTst.timeIntervalSince1970)),
                           @"desc": [NSString stringWithFormat:@"%@%@%@%@",
                                     region.name,
                                     (region.uuid && region.uuid.length > 0) ?
                                     [NSString stringWithFormat: @":%@", region.uuid] : @"",
                                     (region.major).unsignedIntValue ? [NSString stringWithFormat: @":%@", region.major] : @"",
                                     (region.minor).unsignedIntValue? [NSString stringWithFormat: @":%@", region.minor] : @""]
                           };
    return json;
}
@end
