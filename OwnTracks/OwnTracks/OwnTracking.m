//
//  OwnTracking.m
//  OwnTracks
//
//  Created by Christoph Krey on 28.06.15.
//  Copyright © 2015-2025  OwnTracks. All rights reserved.
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

            NSDictionary *dictionary = nil;
            id json = [[Validation sharedInstance] validateMessageData:data];
            if (json && [json isKindOfClass:[NSDictionary class]]) {
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
                if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
                    NSString *type = dictionary[@"_type"];
                    if (type && [type isKindOfClass:[NSString class]]) {
                        if ([type isEqualToString:@"card"]) {
                            [context performBlock:^{
                                Friend *friend = [Friend friendWithTopic:device
                                                  inManagedObjectContext:context];
                                [self processFace:friend dictionary:dictionary];
                                DDLogInfo(@"[OwnTracking] processed card for own device");
                            }];
                        } else {
                            DDLogInfo(@"[OwnTracking] unhandled record type for own device _type:%@", dictionary[@"_type"]);
                        }
                    } else {
                        DDLogError(@"[OwnTracking] JSON object without _type as String received for own device");
                    }
                } else {
                    DDLogError(@"[OwnTracking] no JSON dictionary received for own device");
                }
            } else /* not own device */ {
                if (data && data.length == 0) { // data.length == 0 -> delete friend
                    Friend *friend = [Friend existsFriendWithTopic:device inManagedObjectContext:context];
                    if (friend) {
                        [context deleteObject:friend];
                    }
                    DDLogInfo(@"[OwnTracking] deleted friend %@",
                              device);
                } else {
                    if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
                        NSString *type = dictionary[@"_type"];
                        if (type && [type isKindOfClass:[NSString class]]) {
                            if ([type isEqualToString:@"location"]) {
                                Friend *friend = [Friend friendWithTopic:device inManagedObjectContext:context];
                                [self processLocation:friend dictionary:dictionary];
                                
                            } else if ([type isEqualToString:@"transition"]) {
                                [self performSelectorOnMainThread:@selector(processTransitionMessage:)
                                                       withObject:dictionary
                                                    waitUntilDone:NO];
                                
                            } else if ([type isEqualToString:@"card"]) {
                                Friend *friend = [Friend friendWithTopic:device
                                                  inManagedObjectContext:context];
                                [self processFace:friend dictionary:dictionary];
                                
                            } else if ([type isEqualToString:@"lwt"]) {
                                DDLogInfo(@"[OwnTracking] received lwt for friend %@",
                                          device);
                                // ignore
                                
                            } else {
                                DDLogVerbose(@"[OwnTracking] unhandled record type for other device _type:%@", type);
                            }
                        } else {
                            DDLogError(@"[OwnTracking] JSON object without _type as String received for other device");
                        }
                    } else {
                        DDLogError(@"[OwnTracking] no JSON dictionary received for other device");
                    }
                }
            }
            
            @synchronized (self.inQueue) {
                self.inQueue = @((self.inQueue).unsignedLongValue - 1);
            }
            if ((self.inQueue).intValue == 0) {
                [context save:nil];
            }
        }];

        return TRUE;
    } else {
        return FALSE;
    }
}

- (void)processLocation:(Friend *)friend dictionary:(NSDictionary *)dictionary {
    if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
        NSNumber *tst = dictionary[@"tst"];
        if (!tst || ![tst isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid tst: not processed");
            return;
        }
        NSDate *timestamp = [NSDate dateWithTimeIntervalSince1970:tst.doubleValue];

        NSNumber *lat = dictionary[@"lat"];
        if (!lat || ![lat isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid lat: not processed");
            return;
        }
        CLLocationDegrees latDegrees = lat.doubleValue;

        NSNumber *lon = dictionary[@"lon"];
        if (!lon || ![lon isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid lon: not processed");
            return;
        }
        CLLocationDegrees lonDegrees = lon.doubleValue;
        
        if (lat.doubleValue == 0.0 && lon.doubleValue == 0.0) {
            DDLogError(@"[OwnTracking processLocation] coord is 0.0,0.0: not processed");
            return;
        }

        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(latDegrees, lonDegrees);
        if (!CLLocationCoordinate2DIsValid(coord)) {
            DDLogError(@"[OwnTracking processLocation] coord is no valid: not processed");
            return;
        }
        
        NSNumber *vel = dictionary[@"vel"];
        if (vel && ![vel isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[OwnTracking processLocation] json does contain invalid vel: not processed");
            return;
        }
        CLLocationSpeed speed = -1;
        if (vel) {
            speed = vel.intValue;
            if (speed >= 0.0) {
                speed = speed * 1000 / 3600;
            }
        }
        
        NSNumber *batt = dictionary[@"batt"];
        if (batt && ![batt isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[OwnTracking processLocation] json does contain invalid batt: not processed");
            return;
        }
        NSNumber *batteryLevel = [NSNumber numberWithFloat:-1.0];
        if (batt) {
            int iBatt = batt.intValue;
            if (iBatt >= 0) {
                batteryLevel = [NSNumber numberWithFloat:iBatt / 100.0];
            }
        }
        
        NSNumber *alt = dictionary[@"alt"];
        if (alt && ![alt isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[OwnTracking processLocation] json does contain invalid alt: not processed");
            return;
        }
        CLLocationDistance altDistance = 0;
        if (alt) {
            altDistance = alt.intValue;
        }

        NSNumber *acc = dictionary[@"acc"];
        if (acc && ![acc isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[OwnTracking processLocation] json does contain invalid acc: not processed");
            return;
        }
        CLLocationAccuracy accAccuracy = 0;
        if (acc) {
            accAccuracy = acc.doubleValue;
        }

        NSNumber *vac = dictionary[@"vac"];
        if (vac && ![vac isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[OwnTracking processLocation] json does contain invalid vac: not processed");
            return;
        }
        CLLocationAccuracy vacAccuracy = 0;
        if (vac) {
            vacAccuracy = vac.intValue;
        }

        NSNumber *cog = dictionary[@"cog"];
        if (cog && ![cog isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[OwnTracking processLocation] json does contain invalid cog: not processed");
            return;
        }
        CLLocationDirection cogDirection = 0;
        if (cog) {
            cogDirection = cog.doubleValue;
        }

        
        CLLocation *location = [[CLLocation alloc]
                                initWithCoordinate:coord
                                altitude:altDistance
                                horizontalAccuracy:accAccuracy
                                verticalAccuracy:vacAccuracy
                                course:cogDirection
                                speed:speed
                                timestamp:timestamp];
        
        NSDate *createdAt = timestamp;
        NSNumber *created_at = dictionary[@"created_at"];
        if (created_at && ![created_at isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid created_at: not processed");
            return;
        }
        if (created_at) {
            createdAt = [NSDate dateWithTimeIntervalSince1970:created_at.doubleValue];
        }
        
        NSString *tid = dictionary[@"tid"];
        if (tid && ![tid isKindOfClass:[NSString class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid tid: not processed");
            return;
        }
        friend.tid = tid;
        
        NSString *t = dictionary[@"t"];
        if (t && ![t isKindOfClass:[NSString class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid t: not processed");
            return;
        }

        NSString *poi = dictionary[@"poi"];
        if (poi && ![poi isKindOfClass:[NSString class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid poi: not processed");
            return;
        }

        NSString *tag = dictionary[@"tag"];
        if (tag && ![tag isKindOfClass:[NSString class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid tag: not processed");
            return;
        }

        NSData *image = nil;
        NSString *imageBase64 = dictionary[@"image"];
        if (imageBase64 && ![imageBase64 isKindOfClass:[NSString class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid imageBase64: not processed");
            return;
        }
        
        if (imageBase64) {
            image = [[NSData alloc] initWithBase64EncodedString:imageBase64 options:0];
        }

        NSString *imageName = dictionary[@"imagename"];
        if (imageName && ![imageName isKindOfClass:[NSString class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid imageName: not processed");
            return;
        }
        
        NSArray <NSString *> *inRegions = dictionary[@"inregions"];
        if (inRegions && ![inRegions isKindOfClass:[NSArray class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid inRegions: not processed");
            return;
        }

        NSArray <NSString *> *inRids = dictionary[@"inrids"];
        if (inRegions && ![inRegions isKindOfClass:[NSArray class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid inRegions: not processed");
            return;
        }

        NSString *ssid = dictionary[@"ssid"];
        if (ssid && ![ssid isKindOfClass:[NSString class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid ssid: not processed");
            return;
        }
        
        NSString *bssid = dictionary[@"bssid"];
        if (bssid && ![bssid isKindOfClass:[NSString class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid bssid: not processed");
            return;
        }
        
        NSString *conn = dictionary[@"conn"];
        if (conn && ![conn isKindOfClass:[NSString class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid conn: not processed");
            return;
        }
        
        NSNumber *m = dictionary[@"m"];
        if (m && ![m isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[OwnTracking processLocation] json does contain invalid m: not processed");
            return;
        }

        NSNumber *bs = dictionary[@"bs"];
        if (bs && ![bs isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[OwnTracking processLocation] json does contain invalid bs: not processed");
            return;
        }

        Waypoint *waypoint = [self addWaypointFor:friend
                                         location:location
                                        createdAt:createdAt
                                          trigger:t
                                              poi:poi
                                              tag:tag
                                          battery:batteryLevel
                                            image:image
                                        imageName:imageName
                                        inRegions:inRegions
                                           inRids:inRids
                                            bssid:bssid
                                             ssid:ssid
                                                m:m
                                             conn:conn
                                               bs:bs];
        [self limitWaypointsFor:friend
                      toMaximum:[Settings intForKey:@"positions_preference"
                                              inMOC:friend.managedObjectContext]];
        DDLogInfo(@"[OwnTracking] processed location for friend %@ @%@",
                  friend.topic, waypoint.effectiveTimestamp);
    } else {
        DDLogError(@"[OwnTracking processLocation] json is no dictionary");
    }
}

// MUST run in main thread
- (void)processTransitionMessage:(NSDictionary *)dictionary {
    if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
        NSNumber *tst = dictionary[@"tst"];
        if (!tst || ![tst isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[OwnTracking processTransitionMessage] json does not contain valid tst: not processed");
            return;
        }
        NSDate *timestamp = [NSDate dateWithTimeIntervalSince1970:tst.doubleValue];
        
        NSString *t = dictionary[@"t"];
        if (t && ![t isKindOfClass:[NSString class]]) {
            DDLogError(@"[OwnTracking processTransitionMessage] json does not contain valid t: not processed");
            return;
        }

        NSString *tid = dictionary[@"tid"];
        if (tid && ![tid isKindOfClass:[NSString class]]) {
            DDLogError(@"[OwnTracking processTransitionMessage] json does not contain valid tid: not processed");
            return;
        }

        NSString *event = dictionary[@"event"];
        if (!event || ![event isKindOfClass:[NSString class]]) {
            DDLogError(@"[OwnTracking processTransitionMessage] json does not contain valid event: not processed");
            return;
        }

        NSString *desc = dictionary[@"desc"];
        if (desc && ![desc isKindOfClass:[NSString class]]) {
            DDLogError(@"[OwnTracking processTransitionMessage] json does not contain valid desc: not processed");
            return;
        }

        if (!t || ![t isEqualToString:@"b"]) {
            NSString *eventVerb = [event stringByAppendingString:@"s"];
            if ([event isEqualToString:@"enter"]) {
                eventVerb = NSLocalizedString(@"enters",
                                              @"friend enters region verb");
            } else if ([event isEqualToString:@"leave"]) {
                eventVerb = NSLocalizedString(@"leaves",
                                              @"friend leaves region verb");
            }
            
            if (!desc) {
                desc = NSLocalizedString(@"a region",
                                         @"name of an unknown or hidden region");
            }
            
            NSString *shortTime = [NSDateFormatter
                                   localizedStringFromDate:timestamp
                                   dateStyle:NSDateFormatterShortStyle
                                   timeStyle:NSDateFormatterShortStyle];
            
            NSString *notificationMessage = [NSString stringWithFormat:@"%@ %@ %@ @ %@",
                                             tid,
                                             eventVerb,
                                             desc,
                                             shortTime];
            
            NSString *notificationIdentifier = [NSString stringWithFormat:@"transition%@%f",
                                                tid,
                                                timestamp.timeIntervalSince1970];
            
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
                                 at:timestamp
                              inMOC:[CoreData sharedInstance].mainMOC
                            maximum:[Settings theMaximumHistoryInMOC:[CoreData sharedInstance].mainMOC]];
            [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
            
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
    } else {
        DDLogError(@"[OwnTracking processTransitionMessage] json is no dictionary");
    }
}

- (void)processFace:(Friend *)friend dictionary:(NSDictionary *)dictionary {
    if (friend) {
        if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
            NSString *name = dictionary[@"name"];
            if (name && ![name isKindOfClass:[NSString class]]) {
                DDLogError(@"[OwnTracking processFace] json does not contain valid name: not processed");
                return;
            }
            friend.cardName = name;

            NSString *face = dictionary[@"face"];
            if (face && ![face isKindOfClass:[NSString class]]) {
                DDLogError(@"[OwnTracking processFace] json does not contain valid face: not processed");
                return;
            }

            if (face) {
                NSData *imageData = [[NSData alloc] initWithBase64EncodedString:face options:0];
                friend.cardImage = imageData;
                if (!imageData) {
                    DDLogError(@"[OwnTracking processFace] face could not be base64 decoded");
                }
            } else {
                friend.cardImage = nil;
            }
            DDLogInfo(@"[OwnTracking] processed card for friend friend %@",
                      friend.topic);
        } else {
            DDLogError(@"[OwnTracking processFace] json is no dictionary");
        }
    } else {
        DDLogError(@"[OwnTracking processFace] no friend");
    }
}

- (void)limitWaypointsFor:(Friend *)friend
                toMaximum:(NSInteger)max {
    
    DDLogVerbose(@"[OwnTracking] limitWaypointsFor %@ hasWaypoints.count %lu / %ld",
                 friend.topic, (unsigned long)friend.hasWaypoints.count, max);

    if (max < 1) {
        DDLogWarn(@"[OwnTracking] limitWaypointsFor max adjusted %ld -> 1", max);
        max = 1;
    }

    for (NSInteger i = friend.hasWaypoints.count; i > max; i--) {
        Waypoint *oldestWaypoint = nil;
        for (Waypoint *waypoint in friend.hasWaypoints) {
            if (!oldestWaypoint || (!waypoint.isDeleted && [oldestWaypoint.tst compare:waypoint.tst] == NSOrderedDescending)) {
                oldestWaypoint = waypoint;
            }
        }
        if (oldestWaypoint) {
            [friend.managedObjectContext deleteObject:oldestWaypoint];
        }
    }
    [CoreData.sharedInstance sync:friend.managedObjectContext];

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

- (Waypoint *)addWaypointFor:(Friend *)friend
                    location:(CLLocation *)location
                   createdAt:(NSDate *)createdAt
                     trigger:(NSString *)trigger
                     poi:(NSString *)poi
                     tag:(NSString *)tag
                     battery:(NSNumber *)battery
                       image:(NSData *)image
                   imageName:(NSString *)imageName
                   inRegions:(NSArray<NSString *> *)inRegions
                      inRids:(NSArray<NSString *> *)inRids
                       bssid:(NSString *)bssid
                        ssid:(NSString *)ssid
                           m:(NSNumber *)m
                        conn:(NSString *)conn
                          bs:(NSNumber *)bs {
    Waypoint *waypoint = [NSEntityDescription insertNewObjectForEntityForName:@"Waypoint"
                                                       inManagedObjectContext:friend.managedObjectContext];
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
    waypoint.image = image;
    waypoint.imageName = imageName;
    if (inRegions && [NSJSONSerialization isValidJSONObject:inRegions]) {
        waypoint.inRegions = [NSJSONSerialization dataWithJSONObject:inRegions
                                                             options:0
                                                               error:nil];
    } else {
        waypoint.inRegions = nil;
    }
    if (inRids && [NSJSONSerialization isValidJSONObject:inRids]) {
        waypoint.inRids = [NSJSONSerialization dataWithJSONObject:inRids
                                                          options:0
                                                            error:nil];
    } else {
        waypoint.inRids = nil;
    }
    waypoint.ssid = ssid;
    waypoint.bssid = bssid;
    waypoint.bs = bs;
    waypoint.m = m;
    waypoint.conn = conn;

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
                     lon:(double)lon  {
    Region *region = [NSEntityDescription insertNewObjectForEntityForName:@"Region"
                                                   inManagedObjectContext:friend.managedObjectContext];
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

        if (waypoint.conn && waypoint.conn.length > 0) {
            json[@"conn"] = waypoint.conn;
        }

        if (waypoint.ssid && waypoint.ssid.length > 0) {
            json[@"ssid"] = waypoint.ssid;
        }

        if (waypoint.bssid && waypoint.bssid.length > 0) {
            json[@"bssid"] = waypoint.bssid;
        }

        if (waypoint.m) {
            json[@"m"] = waypoint.m;
        }
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

    if (waypoint.bs.doubleValue != UIDeviceBatteryStateUnknown) {
        json[@"bs"] = waypoint.bs;
    }

    if (waypoint.inRegions) {
        json[@"inregions"] = [NSJSONSerialization JSONObjectWithData:waypoint.inRegions
                                                             options:0
                                                               error:nil];
    }

    if (waypoint.inRids) {
        json[@"inrids"] = [NSJSONSerialization JSONObjectWithData:waypoint.inRids
                                                          options:0
                                                            error:nil];
    }
    
    if (waypoint.poi && waypoint.poi.length > 0) {
        json[@"poi"] = waypoint.poi;
    }
    
    if (waypoint.tag && waypoint.tag.length > 0) {
        json[@"tag"] = waypoint.tag;
    }
    
    if (waypoint.image) {
        json[@"image"] = [waypoint.image base64EncodedStringWithOptions:0];
    }
    
    if (waypoint.imageName) {
        json[@"imagename"] = waypoint.imageName;
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
