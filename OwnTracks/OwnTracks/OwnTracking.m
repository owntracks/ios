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


@interface OwnTracking ()
- (void)actuallyProcessLocation:(Friend *)aFriend dictionary:(NSDictionary *)dictionary;
- (void)publishStatus:(BOOL)isActive;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSTimer *> *debounceTimers;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSDictionary *> *debouncePayloads;
@end


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
    if (self) {
        self.debouncePayloads = [NSMutableDictionary dictionary];
        self.debounceTimers = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)publishStatus:(BOOL)isActive {
    // Only publish user_status when app is in foreground
    UIApplicationState appState = [UIApplication sharedApplication].applicationState;
    if (appState != UIApplicationStateActive) {
        DDLogInfo(@"[OwnTracking] Skipping publishStatus: app not in foreground (state: %ld)", (long)appState);
        return;
    }
    
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    NSString *tid = [Settings stringForKey:@"trackerid_preference" inMOC:moc];
    
    NSString *topic = [Settings theGeneralTopicInMOC:moc];
    
    
    OwnTracksAppDelegate *appDelegate = (OwnTracksAppDelegate *)[[UIApplication sharedApplication] delegate];
    if (!tid || !topic || !appDelegate.connection) {
        DDLogWarn(@"[OwnTracking] Skipping publishStatus: missing tid, topic, or connection");
        return;
    }
    
    
    // Append a suffix so we don't interfere with location stream
    NSString *statusTopic = [topic stringByAppendingString:@"/status"];
    
    NSDictionary *payload = @{
        @"_type": @"user_status",
        @"tid": tid,
        @"active": @(isActive),
        @"tst": @((NSInteger)[[NSDate date] timeIntervalSince1970])
    };
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    if (!jsonData || error) {
        DDLogError(@"[OwnTracking] Failed to serialize user_status: %@", error);
        return;
    }
    
    MQTTQosLevel qos = [Settings intForKey:@"qos_preference" inMOC:moc];
    
    [appDelegate.connection sendData:jsonData
     
                               topic:statusTopic
                          topicAlias:nil
                                 qos:qos
                              retain:YES];
    
    DDLogInfo(@"[OwnTracking] Published user_status (%@) to %@ (app state: %ld)", isActive ? @"active" : @"inactive", statusTopic, (long)appState);
}


- (BOOL)processMessage:(NSString *)topic
                  data:(NSData *)data
              retained:(BOOL)retained
               context:(NSManagedObjectContext *)context {
    
    DDLogVerbose(@"[OwnTracking] processMessage %@ %@",
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
                    }];
                } else {
                    DDLogVerbose(@"[OwnTracking] unhandled record type for own device _type:%@", dictionary[@"_type"]);
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
            [CoreData.sharedInstance sync:context];
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
                        [self processTransitionMessage:dictionary inManagedObjectContext:context];
                        
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
    
    return TRUE;
}
- (NSData *)statusPayloadDataForActive:(BOOL)isActive {
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    
    NSString *tid = [Settings stringForKey:@"trackerid_preference" inMOC:moc];
    if (!tid) {
        DDLogWarn(@"[OwnTracking] Missing tracker ID");
        return nil;
    }
    
    NSDictionary *payload = @{
        @"_type": @"user_status",
        @"tid": tid,
        @"active": @(isActive),
        @"tst": @((NSInteger)[[NSDate date] timeIntervalSince1970])
    };
    
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    if (!jsonData || error) {
        DDLogError(@"[OwnTracking] Failed to serialize user_status: %@", error);
        return nil;
    }
    
    return jsonData;
}

- (void)debounceLocationForFriend:(Friend *)friend dictionary:(NSDictionary *)dictionary {
    NSString *key = friend.topic;
    if (!key) return;
    
    
    // Store latest payload
    self.debouncePayloads[key] = dictionary;
    
    // Cancel existing timer
    NSTimer *existing = self.debounceTimers[key];
    if (existing) {
        [existing invalidate];
    }
    
    // Start a new timer
    __weak typeof(self) weakSelf = self;

    NSTimer *timer = [NSTimer timerWithTimeInterval:2.0
                                              target:weakSelf
                                            selector:@selector(debounceTimerFired:)
                                            userInfo:@{ @"key": key }
                                             repeats:NO];

    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];

    self.debounceTimers[key] = timer;

}
- (void)debounceTimerFired:(NSTimer *)timer {
    NSString *key = timer.userInfo[@"key"];
    if (!key) return;

    NSDictionary *latest = self.debouncePayloads[key];
    if (latest) {
        DDLogInfo(@"[Debounce] Timer fired for key: %@", key);
        Friend *friend = [Friend friendWithTopic:key
                        inManagedObjectContext:CoreData.sharedInstance.queuedMOC];
        if (friend) {
            [self actuallyProcessLocation:friend dictionary:latest];
        }
    }

    [self.debounceTimers removeObjectForKey:key];
    [self.debouncePayloads removeObjectForKey:key];
}

- (void)processLocation:(Friend *)friend dictionary:(NSDictionary *)dictionary {
    if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
        //NSNumber *tst = dictionary[@"tst"];
        
        NSNumber *tst = dictionary[@"tst"];

        if (!tst || ![tst isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid tst: not processed");
            return;
        }
        // 🆕 Add max age check
        NSTimeInterval nowTS = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval timestampTS = tst.doubleValue;
        NSTimeInterval age = nowTS - timestampTS;
   
        
        // if (friend.lastLocation == nil && age > 120.0) {
        //      DDLogInfo(@"[OwnTracking] Stale message (%.1f sec old) for new friend friend %@ Dont Discard.", age, friend.topic);
        
        // }
        //43200){//12 hours
        if ( (age) < 60*30){//12 hours
            //DDLogInfo(@"[OwnTracking] NEW! Looks Realtime, skip debounce (%.1f sec old) for friend %@", age, friend.topic);
            [self actuallyProcessLocation:friend dictionary:dictionary];
        }
        else if ( (age) >  600000) // 1 week 
        {
            //DDLogInfo(@"[OwnTracking] NEW! Really Old, throw away, and skip debounce (%.1f sec old) for friend %@", age, friend.topic);
            return;
        }
        else{
            [self debounceLocationForFriend:friend dictionary:dictionary];
        }

        
      
    }
    return;
}
        
- (void)actuallyProcessLocation:(Friend *)friend dictionary:(NSDictionary *)dictionary {
    if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
        NSNumber *tst = dictionary[@"tst"];

        if (!tst || ![tst isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid tst: not processed");
            return;
        }

       
        NSDate *timestamp = [NSDate dateWithTimeIntervalSince1970:tst.doubleValue];

        // 🆕 Add max age check
        NSTimeInterval age = [[NSDate date] timeIntervalSince1970] - tst.doubleValue;
        NSTimeInterval nowTS = [[NSDate date] timeIntervalSince1970];

        // 🧠 Existing duplicate check
        if (friend.lastLocation && [friend.lastLocation compare:timestamp] != NSOrderedAscending) {
            DDLogInfo(@"[OwnTracking] ORIG! skipped location for friend %@ @%@", friend.topic, timestamp);
            return;
        }

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
        
        NSNumber *p = dictionary[@"p"];
        if (p && ![p isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[OwnTracking processLocation] json does contain invalid p: not processed");
            return;
        }

        NSArray <NSString *> *motionActivities = dictionary[@"motionactivities"];
        if (inRegions && ![inRegions isKindOfClass:[NSArray class]]) {
            DDLogError(@"[OwnTracking processLocation] json does not contain valid motionactivities: not processed");
            return;
        }

        (void)[friend addWaypoint:location
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
                               bs:bs
                         pressure:p
                 motionActivities:motionActivities];
        int positions = [Settings intForKey:@"positions_preference" inMOC:friend.managedObjectContext];
        NSInteger remainingPositions = [friend limitWaypointsToMaximum:positions];
        DDLogInfo(@"[OwnTracking] processed location for friend %@ @%@ (%ld)",
                  friend.topic, timestamp, remainingPositions);
    } else {
        DDLogError(@"[OwnTracking processLocation] json is no dictionary");
    }
}

- (void)processTransitionMessage:(NSDictionary *)dictionary inManagedObjectContext:(NSManagedObjectContext *)context {
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
                              inMOC:context
                            maximum:[Settings theMaximumHistoryInMOC:context]];
            
            [NavigationController alert:NSLocalizedString(@"Friend",
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

            DDLogInfo(@"[OwnTracking] processed card for friend %@",
                      friend.topic);
            [CoreData.sharedInstance sync:friend.managedObjectContext];

        } else {
            DDLogError(@"[OwnTracking processFace] json is no dictionary");
        }
    } else {
        DDLogError(@"[OwnTracking processFace] no friend");
    }
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
    [[CoreData sharedInstance] sync:region.managedObjectContext];
    [[LocationManager sharedInstance] startRegion:region.CLregion];
    return region;
}

- (void)removeRegion:(Region *)region context:(NSManagedObjectContext *)context {
    DDLogInfo(@"[OwnTracking] removeRegion %@", region.name);
    [[LocationManager sharedInstance] stopRegion:region.CLregion];
    [context deleteObject:region];
    [[CoreData sharedInstance] sync:context];
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

    // Add version number
    json[@"ver"] = [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"];

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

        if (waypoint.pressure) {
            json[@"p"] = waypoint.pressure.threeDecimals;
        }

        if (waypoint.motionActivities) {
            json[@"motionactivities"] = [NSJSONSerialization JSONObjectWithData:waypoint.motionActivities
                                                                        options:0
                                                                          error:nil];
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
