//
//  OwnTracking.m
//  OwnTracks
//
//  Created by Christoph Krey on 28.06.15.
//  Copyright © 2015-2017 OwnTracks. All rights reserved.
//

#import "OwnTracking.h"
#import "Settings.h"
#import "OwnTracksAppDelegate.h"
#import "AlertView.h"
#import "Waypoint.h"
#import "CoreData.h"
#import "ConnType.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

#define MAXQUEUE 999

@implementation OwnTracking
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
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

    if ([self.inQueue unsignedLongValue] < MAXQUEUE) {
        @synchronized (self.inQueue) {
            self.inQueue = @([self.inQueue unsignedLongValue] + 1);
        }
        [context performBlock:^{
            NSError *error;
            DDLogVerbose(@"performBlock %@ %@", topic, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);

            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (json && [json isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dictionary = json;
                NSArray *topicComponents = [topic componentsSeparatedByString:@"/"];
                NSArray *baseComponents = [[Settings theGeneralTopic] componentsSeparatedByString:@"/"];

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

                            int speed = [dictionary[@"vel"] intValue];
                            if (speed != -1) {
                                speed = speed * 1000 / 3600;
                            }
                            CLLocation *location = [[CLLocation alloc] initWithCoordinate:coordinate
                                                                                 altitude:[dictionary[@"alt"] intValue]
                                                                       horizontalAccuracy:[dictionary[@"acc"] doubleValue]
                                                                         verticalAccuracy:[dictionary[@"vac"] intValue]
                                                                                   course:[dictionary[@"cog"] intValue]
                                                                                    speed:speed
                                                                                timestamp:[NSDate dateWithTimeIntervalSince1970:[dictionary[@"tst"] doubleValue]]];
                            Friend *friend = [Friend friendWithTopic:device inManagedObjectContext:context];
                            friend.tid = dictionary[@"tid"];
                            [self addWaypointFor:friend location:location trigger:dictionary[@"t"] context:context];
                            [self limitWaypointsFor:friend
                                          toMaximum:[Settings intForKey:@"positions_preference"]
                             inManagedObjectContext:context];
                        } else if ([dictionary[@"_type"] isEqualToString:@"transition"]) {
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

                                NSString *shortTime = [NSDateFormatter localizedStringFromDate:tst
                                                                                     dateStyle:NSDateFormatterShortStyle
                                                                                     timeStyle:NSDateFormatterShortStyle];

                                NSString *message = [NSString stringWithFormat:@"%@ %@s %@ @ %@",
                                                     tid,
                                                     event,
                                                     desc,
                                                     shortTime];

                                UILocalNotification *notification = [[UILocalNotification alloc] init];
                                notification.alertBody = message;
                                notification.userInfo = @{@"notify": @"friend"};
                                notification.fireDate = tst;
                                [[UIApplication sharedApplication] scheduleLocalNotification:notification];
                                [AlertView alert:NSLocalizedString(@"Friend",
                                                                   @"Alert message header for friend's messages")
                                         message:notification.alertBody
                                    dismissAfter:2.0
                                 ];

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
    } else {
        return FALSE;
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
                toMaximum:(NSInteger)max
   inManagedObjectContext:(NSManagedObjectContext *)context {
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
    Waypoint *newestWaypoint = nil;
    for (Waypoint *waypoint in friend.hasWaypoints) {
        if (!newestWaypoint || (!waypoint.isDeleted && [newestWaypoint.tst compare:waypoint.tst] == NSOrderedAscending)) {
            newestWaypoint = waypoint;
        }
    }
    if (newestWaypoint && ![newestWaypoint.tst isEqualToDate:friend.lastLocation]) {
        friend.lastLocation = newestWaypoint.tst;
        [CoreData saveContext:context];
    }
}

- (void)share {

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
    double speed = location.speed;
    if (speed != -1) {
        speed = speed * 3600 / 1000;
    }
    waypoint.vel = [NSNumber numberWithDouble:speed];
    waypoint.cog = [NSNumber numberWithDouble:location.course];
    waypoint.placemark = nil;

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
    region.tst = [NSDate date];
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
    [json setValue:@((int)[waypoint.tst timeIntervalSince1970]) forKey:@"tst"];

    int acc = [waypoint.acc intValue];
    if (acc >= 0) {
        [json setValue:@(acc) forKey:@"acc"];
    }

    if ([Settings boolForKey:@"extendeddata_preference"]) {
        int alt = [waypoint.alt intValue];
        [json setValue:@(alt) forKey:@"alt"];

        int vac = [waypoint.vac intValue];
        if (vac >= 0) {
            [json setValue:@(vac) forKey:@"vac"];
        }

        int vel = [waypoint.vel intValue];
        if (vel >= 0) {
            [json setValue:@(vel) forKey:@"vel"];
        }

        int cog = [waypoint.cog intValue];
        if (cog >= 0) {
            [json setValue:@(cog) forKey:@"cog"];
        }

        CMAltitudeData *altitude = [LocationManager sharedInstance].altitude;
        if (altitude) {
            [json setValue:altitude.pressure forKey:@"p"];
        }

            switch ([ConnType connectionType:[Settings theHost]]) {
                case ConnectionTypeNone:
                    [json setObject:@"o" forKey:@"conn"];
                    break;

                case ConnectionTypeWIFI:
                    [json setObject:@"w" forKey:@"conn"];
                    break;

                case ConnectionTypeWWAN:
                    [json setObject:@"m" forKey:@"conn"];
                    break;

                case ConnectionTypeUnknown:
                default:
                    break;
            }
    }

    NSString *tid = [Settings stringForKey:@"trackerid_preference"];
    if (tid && tid.length > 0) {
        [json setValue:tid forKeyPath:@"tid"];
    } else {
        [json setValue:[waypoint.belongsTo getEffectiveTid] forKeyPath:@"tid"];
    }

    int batteryLevel = [UIDevice currentDevice].batteryLevel != -1 ? [UIDevice currentDevice].batteryLevel * 100 : -1;
    if (batteryLevel >= 0) {
        [json setValue:@(batteryLevel) forKey:@"batt"];
    }

    return json;
}

- (NSDictionary *)regionAsJSON:(Region *)region {
    NSDictionary *json = @{@"_type": @"waypoint",
                           @"lat": region.lat,
                           @"lon": region.lon,
                           @"rad": region.radius,
                           @"tst": @(floor([[region getAndFillTst] timeIntervalSince1970])),
                           @"desc": [NSString stringWithFormat:@"%@%@%@%@",
                                     region.name,
                                     (region.uuid && region.uuid.length > 0) ?
                                     [NSString stringWithFormat: @":%@", region.uuid] : @"",
                                     [region.major unsignedIntValue] ? [NSString stringWithFormat: @":%@", region.major] : @"",
                                     [region.minor unsignedIntValue]? [NSString stringWithFormat: @":%@", region.minor] : @""]
                           };
    return json;
}
@end
