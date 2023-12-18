//
//  OwnTracking.m
//  OwnTracks
//
//  Created by Christoph Krey on 28.06.15.
//  Copyright © 2015-2022  OwnTracks. All rights reserved.
//

#import "OwnTracking.h"
#import "Settings.h"
#import "OwnTracksAppDelegate.h"
#import "Waypoint+CoreDataClass.h"
#import "History+CoreDataClass.h"
#import "CoreData.h"
#import "ConnType.h"
#import "NSNumber+decimals.h"
#import "Validation.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <UserNotifications/UserNotifications.h>
#import <UserNotifications/UNUserNotificationCenter.h>

#define MAXQUEUE 999

@implementation OwnTracking
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
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
                                                      object:nil 
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note){
        [self performSelectorOnMainThread:@selector(share) withObject:nil waitUntilDone:NO];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note){
        [self performSelectorOnMainThread:@selector(share) withObject:nil waitUntilDone:NO];
    }];
    return self;
}

- (void)syncProcessing {
    while ((self.inQueue).unsignedLongValue > 0) {
        DDLogVerbose(@"[OwnTracking] syncProcessing %lu", [self.inQueue unsignedLongValue]);
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
            DDLogVerbose(@"[OwnTracking] performBlock %@ %@",
                         topic,
                         [[NSString alloc] initWithData:data
                                               encoding:NSUTF8StringEncoding]);

            NSDictionary *dictionary = [[NSDictionary alloc] init];
            id json = [[Validation sharedInstance] validateMessageData:data]; 
            if (json &&
                [json isKindOfClass:[NSDictionary class]]) {
                dictionary = json;
            }
            
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
                        DDLogInfo(@"[OwnTracking] processed card for own device");
                    }];
                } else {
                    DDLogVerbose(@"[OwnTracking] unhandled record type for own device _type:%@", dictionary[@"_type"]);
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

                        NSNumber *batteryLevel = [NSNumber numberWithFloat:-1.0];
                        if ([dictionary valueForKey:@"batt"] != nil) {
                            int batt = [dictionary[@"batt"] intValue];
                            if (batt >= 0) {
                                batteryLevel = [NSNumber numberWithFloat:batt / 100.0];
                            }
                        }

                        CLLocation *location = [[CLLocation alloc]
                                                initWithCoordinate:coordinate
                                                altitude:[dictionary[@"alt"] intValue]
                                                horizontalAccuracy:[dictionary[@"acc"] doubleValue]
                                                verticalAccuracy:[dictionary[@"vac"] intValue]
                                                course:[dictionary[@"cog"] intValue]
                                                speed:speed
                                                timestamp:[NSDate dateWithTimeIntervalSince1970:[dictionary[@"tst"] doubleValue]]];
                        NSDate *createdAt = location.timestamp;
                        if ([dictionary valueForKey:@"created_at"] != nil) {
                            createdAt = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"tst"] doubleValue]];
                        }
                        Friend *friend = [Friend friendWithTopic:device inManagedObjectContext:context];
                        friend.tid = dictionary[@"tid"];
                        [self addWaypointFor:friend
                                    location:location
                                   createdAt:createdAt
                                     trigger:dictionary[@"t"]
                                         poi:dictionary[@"poi"]
                                         tag:dictionary[@"tag"]
                                     battery:batteryLevel
                                     context:context];
                        [self limitWaypointsFor:friend
                                      toMaximum:[Settings intForKey:@"positions_preference" inMOC:context]];
                        DDLogInfo(@"[OwnTracking] processed location for friend %@",
                                  friend.topic);


                    } else if ([dictionary[@"_type"] isEqualToString:@"transition"]) {
                        [self performSelectorOnMainThread:@selector(processTransitionMessage:)
                                               withObject:dictionary
                                            waitUntilDone:NO];
                        
                    } else if ([dictionary[@"_type"] isEqualToString:@"card"]) {
                        Friend *friend = [Friend friendWithTopic:device
                                          inManagedObjectContext:context];
                        [self processFace:friend dictionary:dictionary];
                        DDLogInfo(@"[OwnTracking] processed card for friend friend %@",
                                  friend.topic);
                    } else if ([dictionary[@"_type"] isEqualToString:@"lwt"]) {
                        DDLogInfo(@"[OwnTracking] received lwt for friend %@",
                                  device);
                        // ignore
                        
                    } else {
                        DDLogVerbose(@"[OwnTracking] unknown record type %@", dictionary[@"_type"]);
                    }
                } else /* data.length == 0 -> delete friend */ {
                    Friend *friend = [Friend existsFriendWithTopic:device inManagedObjectContext:context];
                    if (friend) {
                        [context deleteObject:friend];
                    }
                    DDLogInfo(@"[OwnTracking] deleted friend %@",
                              device);
                }
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
        NSString *eventVerb = [event stringByAppendingString:@"s"];
        if ([event isEqualToString:@"enter"]) {
            eventVerb = NSLocalizedString(@"enters",
                                          @"friend enters region verb");
        } else if ([event isEqualToString:@"leave"]) {
            eventVerb = NSLocalizedString(@"leaves",
                                          @"friend leaves region verb");
        }
        
        NSString *desc = dictionary[@"desc"];
        if (!desc) {
            desc = NSLocalizedString(@"a region",
                                     @"name of an unknown or hidden region");
        }

        NSString *shortTime = [NSDateFormatter
                               localizedStringFromDate:tst
                               dateStyle:NSDateFormatterShortStyle
                               timeStyle:NSDateFormatterShortStyle];

        NSString *notificationMessage = [NSString stringWithFormat:@"%@ %@ %@ @ %@",
                                         tid,
                                         eventVerb,
                                         desc,
                                         shortTime];

        NSString *notificationIdentifier = [NSString stringWithFormat:@"transition%@%f",
                                            tid,
                                            tst.timeIntervalSince1970];

        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.body = notificationMessage;
        content.sound = [UNNotificationSound defaultSound];
        content.userInfo = @{@"notify": @"friend"};
        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger
                                                      triggerWithTimeInterval:1.0
                                                      repeats:NO];
        UNNotificationRequest *request = 
        [UNNotificationRequest requestWithIdentifier:notificationIdentifier
                                             content:content
                                             trigger:trigger];
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center addNotificationRequest:request withCompletionHandler:nil];

        NSString *shortNotificationMessage = [NSString stringWithFormat:@"%@ %@ %@",
                                         tid,
                                         eventVerb,
                                         desc];

        [History historyInGroup:NSLocalizedString(@"Friend",
                                                  @"Alert message header for friend's messages")
                       withText:shortNotificationMessage
                             at:tst
                          inMOC:[CoreData sharedInstance].mainMOC
                        maximum:[Settings theMaximumHistoryInMOC:[CoreData sharedInstance].mainMOC]];
        [CoreData.sharedInstance sync:CoreData.sharedInstance.queuedMOC];

        OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [ad.navigationController alert:
             NSLocalizedString(@"Friend",
                               @"Alert message header for friend's messages")
                               message:notificationMessage
                          dismissAfter:2.0
        ];
        DDLogInfo(@"[OwnTracking] processed transition for friend %@",
                  notificationMessage);
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
        DDLogVerbose(@"[OwnTracking] %@ hasWaypoints.count %lu", friend.topic, (unsigned long)friend.hasWaypoints.count);
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
                    DDLogError(@"[OwnTracking] friend or location incomplete");
                }
            }
        }
    }
    DDLogVerbose(@"[OwnTracking] sharedFriends %@", [sharedFriends allKeys]);
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:@"group.org.owntracks.Owntracks"];
    [shared setValue:sharedFriends forKey:@"sharedFriends"];
}

- (Waypoint *)addWaypointFor:(Friend *)friend
                    location:(CLLocation *)location
                   createdAt:(NSDate *)createdAt
                     trigger:(NSString *)trigger
                     poi:(NSString *)poi
                     tag:(NSString *)tag
                     battery:(NSNumber *)battery
                     context:(NSManagedObjectContext *)context {
    Waypoint *waypoint = [NSEntityDescription insertNewObjectForEntityForName:@"Waypoint"
                                                       inManagedObjectContext:context];
    waypoint.belongsTo = friend;
    waypoint.trigger = trigger;
    waypoint.poi = poi;
    waypoint.tag = tag;
    waypoint.acc = @(location.horizontalAccuracy);
    waypoint.alt = @(location.altitude);
    waypoint.lat = @(location.coordinate.latitude);
    waypoint.lon = @(location.coordinate.longitude);
    waypoint.vac = @(location.verticalAccuracy);
    waypoint.tst = location.timestamp;
    waypoint.createdAt = createdAt;
    waypoint.batt = battery;
    double speed = location.speed;
    if (speed != -1) {
        speed = speed * 3600 / 1000;
    }
    waypoint.vel = @(speed);
    waypoint.cog = @(location.course);
    waypoint.placemark = nil;

    return waypoint;
}

- (Region *)addRegionFor:(NSString *)rid
                  friend:(Friend *)friend
                    name:(NSString *)name
                     tst:(NSDate *)tst
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
    region.tst = tst;
    region.rid = rid;
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
    json[@"_type"] = @"location";
    if (waypoint.trigger) {
        json[@"t"] = waypoint.trigger;
    }

    json[@"lat"] = waypoint.lat.sixDecimals;

    json[@"lon"] = waypoint.lon.sixDecimals;

    json[@"tst"] = [NSNumber doubleValueWithZeroDecimals:waypoint.tst.timeIntervalSince1970];

    if (fabs(waypoint.tst.timeIntervalSince1970 -
             waypoint.createdAt.timeIntervalSince1970) > 1.0) {
        json[@"created_at"] = [NSNumber doubleValueWithZeroDecimals:waypoint.createdAt.timeIntervalSince1970];
    }

    if (waypoint.acc.doubleValue >= 0.0) {
        json[@"acc"] =  waypoint.acc.zeroDecimals;
    }

    if ([Settings boolForKey:@"extendeddata_preference" inMOC:waypoint.managedObjectContext]) {
        json[@"alt"] = waypoint.alt.zeroDecimals;
        if (waypoint.vac.doubleValue >= 0.0) {
            json[@"vac"] = waypoint.vac.zeroDecimals;
        }

        if (waypoint.vel.doubleValue >= 0.0) {
            json[@"vel"] = waypoint.vel.zeroDecimals;
        }

        if (waypoint.cog.doubleValue >= 0.0) {
            json[@"cog"] = waypoint.cog.zeroDecimals;
        }

        CMAltitudeData *altitude = [LocationManager sharedInstance].altitude;
        if (altitude) {
            json[@"p"] = altitude.pressure.threeDecimals;
        }

        switch ([ConnType connectionType:[Settings theHostInMOC:waypoint.managedObjectContext]]) {
            case ConnectionTypeNone:
                json[@"conn"] = @"o";
                break;

            case ConnectionTypeWIFI:
            {
                json[@"conn"] = @"w";
                NSString *ssid = [ConnType SSID];
                if (ssid) {
                    json[@"SSID"] = ssid;
                }
                NSString *bssid = [ConnType BSSID];
                if (bssid) {
                    json[@"BSSID"] = bssid;
                }
                break;
            }
                
            case ConnectionTypeWWAN:
                json[@"conn"] = @"m";
                break;

            case ConnectionTypeUnknown:
            default:
                break;
        }

        json[@"m"] = [NSNumber numberWithInt:(int)[LocationManager sharedInstance].monitoring];
    }

    NSString *tid = [Settings stringForKey:@"trackerid_preference" inMOC:waypoint.managedObjectContext];
    if (tid && tid.length > 0) {
        [json setValue:tid forKeyPath:@"tid"];
    } else {
        [json setValue:(waypoint.belongsTo).effectiveTid forKeyPath:@"tid"];
    }

    if (waypoint.batt.doubleValue >= 0.0) {
        int batteryLevelInt = waypoint.batt.doubleValue * 100;
        json[@"batt"] = @(batteryLevelInt);
    }

    UIDeviceBatteryState batteryState = [UIDevice currentDevice].batteryState;
    if (batteryState != UIDeviceBatteryStateUnknown) {
        [json setValue:@(batteryState) forKey:@"bs"];
    }

    NSMutableArray <NSString *> *inRegions = [[NSMutableArray alloc] init];
    NSMutableArray <NSString *> *inRids = [[NSMutableArray alloc] init];
    for (Region *region in waypoint.belongsTo.hasRegions) {
        if (![region.name hasPrefix:@"+"]) {
            if ([LocationManager sharedInstance].insideCircularRegions[region.name] ||
                [LocationManager sharedInstance].insideBeaconRegions[region.name]) {
                [inRegions addObject:region.name];
                [inRids addObject:region.getAndFillRid];
            }
        }
    }

    if (inRegions.count > 0) {
        json[@"inregions"] = inRegions;
    }

    if (inRids.count > 0) {
        json[@"inrids"] = inRids;
    }
    
    if (waypoint.poi) {
        json[@"poi"] = waypoint.poi;
    }
    
    if (waypoint.tag) {
        json[@"tag"] = waypoint.tag;
    }

    return json;
}

- (NSDictionary *)regionAsJSON:(Region *)region {
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    json[@"_type"] = @"waypoint";

    json[@"lat"] = region.lat.sixDecimals;
    json[@"lon"] = region.lon.sixDecimals;
    json[@"rad"] = region.radius.zeroDecimals;

    json[@"tst"] = [NSNumber doubleValueWithZeroDecimals:region.andFillTst.timeIntervalSince1970];
    json[@"rid"] = region.andFillRid;
    json[@"desc"] = [NSString stringWithFormat:@"%@%@%@%@",
                     region.name,
                     (region.uuid && region.uuid.length > 0) ?
                     [NSString stringWithFormat: @":%@", region.uuid] : @"",
                     (region.major).unsignedIntValue ? [NSString stringWithFormat: @":%@", region.major] : @"",
                     (region.minor).unsignedIntValue? [NSString stringWithFormat: @":%@", region.minor] : @""];
    return json;
}
@end
