//
//  OwnTracksAppDelegate.m
//  OwnTracks
//
//  Created by Christoph Krey on 03.02.14.
//  Copyright © 2014-2016 OwnTracks. All rights reserved.
//

#import "OwnTracksAppDelegate.h"
#import "CoreData.h"
#import "Setting+Create.h"
#import "AlertView.h"
#import "Settings.h"
#import "Location.h"
#import "OwnTracking.h"
#import <NotificationCenter/NotificationCenter.h>

#import <CocoaLumberjack/CocoaLumberjack.h>
static const DDLogLevel ddLogLevel = DDLogLevelError;

@interface OwnTracksAppDelegate()
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@property (strong, nonatomic) void (^completionHandler)(UIBackgroundFetchResult);
@property (strong, nonatomic) CoreData *coreData;
@property (strong, nonatomic) CMStepCounter *stepCounter;
@property (strong, nonatomic) CMPedometer *pedometer;

@property (strong, nonatomic) NSManagedObjectContext *queueManagedObjectContext;
@end

#define BUY_OPTION 0 // modify to 1 if you want to enable auto renewing subscription buying

@implementation OwnTracksAppDelegate

#pragma ApplicationDelegate

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.backgroundTask = UIBackgroundTaskInvalid;
    self.completionHandler = nil;
    
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0"] != NSOrderedAscending) {
        [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    }
    
    if ([[[UIDevice currentDevice] systemVersion] compare:@"8.0"] != NSOrderedAscending) {
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:
                                                UIUserNotificationTypeAlert |UIUserNotificationTypeBadge
                                                                                 categories:nil];
        [application registerUserNotificationSettings:settings];
    }
    
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
#ifdef DEBUG
    [DDLog addLogger:[DDTTYLogger sharedInstance] withLevel:DDLogLevelVerbose];
#endif
    [DDLog addLogger:[DDASLLogger sharedInstance] withLevel:DDLogLevelWarning];
    
    DDLogVerbose(@"didFinishLaunchingWithOptions");
    
#if BUY_OPTION == 1
    if ([[Subscriptions sharedInstance].recording boolValue]) {
        // Start Subscriptions in mode 1 only
    }
#endif
    
    self.coreData = [[CoreData alloc] init];
    
    UIDocumentState state;
    
    do {
        state = self.coreData.documentState;
        if (state & UIDocumentStateClosed || ![CoreData theManagedObjectContext]) {
            DDLogVerbose(@"documentState 0x%02lx theManagedObjectContext %@",
                         (long)self.coreData.documentState,
                         [CoreData theManagedObjectContext]);
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        }
    } while (state & UIDocumentStateClosed || ![CoreData theManagedObjectContext]);
    
    //
    // Migrate Waypoints from 8.0.32 to 8.2.0
    //
    Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopic]
                            inManagedObjectContext:[CoreData theManagedObjectContext]];
    if (myself) {
        for (Location *location in myself.hasLocations) {
            if (![location.automatic boolValue]) {
                if (location.remark && location.remark.length) {
                    NSArray *components = [location.remark componentsSeparatedByString:@":"];
                    NSString *name = components.count >= 1 ? components[0] : nil;
                    NSString *uuid = components.count >= 2 ? components[1] : nil;
                    unsigned int major = components.count >= 3 ? [components[2] unsignedIntValue]: 0;
                    unsigned int minor = components.count >= 4 ? [components[3] unsignedIntValue]: 0;
                    
                    [[OwnTracking sharedInstance] addRegionFor:myself
                                                          name:name
                                                          uuid:uuid
                                                         major:major
                                                         minor:minor
                                                         share:[location.share boolValue]
                                                        radius:[location.regionradius doubleValue]
                                                           lat:[location.latitude doubleValue]
                                                           lon:[location.longitude doubleValue]
                                                       context:[CoreData theManagedObjectContext]];
                }
            }
            [[CoreData theManagedObjectContext] deleteObject:location];
        }
        [CoreData saveContext];
    }

    
    if (![Setting existsSettingWithKey:@"mode"
                inManagedObjectContext:[CoreData theManagedObjectContext]]) {
        if (![Setting existsSettingWithKey:@"host_preference"
                    inManagedObjectContext:[CoreData theManagedObjectContext]]) {
            [Settings setInt:2 forKey:@"mode"];
        } else {
            [Settings setInt:0 forKey:@"mode"];
        }
    }
    
    self.connection = [[Connection alloc] init];
    self.connection.delegate = self;
    [self.connection start];

    [self connect];
    
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:TRUE];
    
    LocationManager *locationManager = [LocationManager sharedInstance];
    locationManager.delegate = self;
    locationManager.monitoring = [Settings intForKey:@"monitoring_preference"];
    locationManager.ranging = [Settings boolForKey:@"ranging_preference"];
    locationManager.minDist = [Settings doubleForKey:@"mindist_preference"];
    locationManager.minTime = [Settings doubleForKey:@"mintime_preference"];
    [locationManager start];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    //
}

-(BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options {
    return [self application:app openURL:url sourceApplication:nil annotation:options];
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    DDLogVerbose(@"openURL %@ from %@ annotation %@", url, sourceApplication, annotation);
    
    if (url) {
        DDLogVerbose(@"URL scheme %@", url.scheme);
        
        if ([url.scheme isEqualToString:@"owntracks"]) {
            DDLogVerbose(@"URL path %@ query %@", url.path, url.query);
            
            NSMutableDictionary *queryStrings = [[NSMutableDictionary alloc] init];
            for (NSString *parameter in [url.query componentsSeparatedByString:@"&"]) {
                NSArray *pair = [parameter componentsSeparatedByString:@"="];
                if (pair.count == 2) {
                    NSString *key = pair[0];
                    NSString *value = pair[1];
                    value = [value stringByReplacingOccurrencesOfString:@"+" withString:@" "];
                    value = [value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                    queryStrings[key] = value;
                }
            }
            if ([url.path isEqualToString:@"/beacon"]) {
                NSString *name = queryStrings[@"name"];
                NSString *uuid = queryStrings[@"uuid"];
                int major = [queryStrings[@"major"] intValue];
                int minor = [queryStrings[@"minor"] intValue];
                
                NSString *desc = [NSString stringWithFormat:@"%@:%@%@%@",
                                  name,
                                  uuid,
                                  major ? [NSString stringWithFormat:@":%d", major] : @"",
                                  minor ? [NSString stringWithFormat:@":%d", minor] : @""
                                  ];
                
                [Settings waypointsFromDictionary:@{@"_type":@"waypoints",
                                                    @"waypoints":@[@{@"_type":@"waypoint",
                                                                     @"desc":desc,
                                                                     @"tst":@((int)([[NSDate date] timeIntervalSince1970])),
                                                                     @"lat":@([LocationManager sharedInstance].location.coordinate.latitude),
                                                                     @"lon":@([LocationManager sharedInstance].location.coordinate.longitude),
                                                                     @"rad":@(-1)
                                                                     }]
                                                    }];
                [CoreData saveContext];
                self.processingMessage = NSLocalizedString(@"Beacon QR successfully processed",
                                                           @"Display after processing beacon QR code");
                return TRUE;
            } else {
                self.processingMessage = NSLocalizedString(@"Hosted QR successfully processed",
                                                           @"Display after processing hosted QR code");

                self.processingMessage = [NSString stringWithFormat:@"%@ %@",
                                          NSLocalizedString(@"unknown path in url",
                                                            @"Display after entering an unknown path in url"),
                                          url.path];
                return FALSE;
            }
        } else if ([url.scheme isEqualToString:@"file"]) {
            return [self processFile:url];
        } else {
            self.processingMessage = [NSString stringWithFormat:@"%@ %@",
                                      NSLocalizedString(@"unknown path in url",
                                                        @"Display after entering an unknown scheme in url"),
                                      url.scheme];
            return FALSE;
        }
    }
    self.processingMessage = NSLocalizedString(@"no url specified",
                                               @"Display after trying to process a file");
    return FALSE;
}

- (BOOL)processFile:(NSURL *)url {
    
    NSInputStream *input = [NSInputStream inputStreamWithURL:url];
    if ([input streamError]) {
        self.processingMessage = [NSString stringWithFormat:@"inputStreamWithURL %@ %@",
                                  [input streamError],
                                  url];
        return FALSE;
    }
    [input open];
    if ([input streamError]) {
        self.processingMessage = [NSString stringWithFormat:@"%@ %@ %@",
                                  NSLocalizedString(@"file open error",
                                                    @"Display after trying to open a file"),
                                  [input streamError],
                                  url];
        return FALSE;
    }
    
    DDLogVerbose(@"URL pathExtension %@", url.pathExtension);
    
    NSError *error;
    NSString *extension = [url pathExtension];
    if ([extension isEqualToString:@"otrc"] || [extension isEqualToString:@"mqtc"]) {
        [self terminateSession];
        error = [Settings fromStream:input];
        [CoreData saveContext];
        self.configLoad = [NSDate date];
    } else if ([extension isEqualToString:@"otrw"] || [extension isEqualToString:@"mqtw"]) {
        error = [Settings waypointsFromStream:input];
        [CoreData saveContext];
    } else if ([extension isEqualToString:@"otrp"] || [extension isEqualToString:@"otre"]) {
        NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                     inDomain:NSUserDomainMask
                                                            appropriateForURL:nil
                                                                       create:YES
                                                                        error:&error];
        NSString *fileName = [url lastPathComponent];
        NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];
        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
        [[NSFileManager defaultManager] copyItemAtURL:url toURL:fileURL error:nil];
    } else {
        error = [NSError errorWithDomain:@"OwnTracks"
                                    code:2
                                userInfo:@{@"extension":extension ? extension : @"(null)"}];
    }
    
    [input close];
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    if (error) {
        self.processingMessage = [NSString stringWithFormat:@"%@ %@: %@ %@",
                                  NSLocalizedString(@"Error processing file",
                                                    @"Display when file processing fails"),
                                  [url lastPathComponent],
                                  error.localizedDescription,
                                  error.userInfo];
        return FALSE;
    }
    self.processingMessage = [NSString stringWithFormat:@"%@ %@ %@",
                              NSLocalizedString(@"File",
                                                @"Display when file processing succeeds (filename follows)"),
                              [url lastPathComponent],
                              NSLocalizedString(@"successfully processed",
                                                @"Display when file processing succeeds")
];
    return TRUE;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    DDLogVerbose(@"applicationDidEnterBackground");
    self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        DDLogVerbose(@"BackgroundTaskExpirationHandler");
        /*
         * we might end up here if the connection could not be closed within the given
         * background time
         */
        if (self.backgroundTask) {
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
            self.backgroundTask = UIBackgroundTaskInvalid;
        }
    }];
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    DDLogVerbose(@"applicationDidBecomeActive");
    
    if (self.processingMessage) {
        [AlertView alert:@"openURL" message:self.processingMessage];
        self.processingMessage = nil;
        [self reconnect];
    }
    
    if (self.coreData.documentState) {
        NSString *message = [NSString stringWithFormat:@"documentState 0x%02lx %@",
                             (long)self.coreData.documentState,
                             self.coreData.fileURL];
        [AlertView alert:@"CoreData" message:message];
    }
    
    if (![Settings validIds]) {
        NSString *message = NSLocalizedString(@"To publish your location userID and deviceID must be set",
                                              @"Warning displayed if necessary settings are missing");

        [AlertView alert:@"Settings" message:message];
    }
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    DDLogVerbose(@"performFetchWithCompletionHandler");
    self.completionHandler = completionHandler;
    [[LocationManager sharedInstance] wakeup];
    [self.connection connectToLast];
    
    if ([LocationManager sharedInstance].monitoring == LocationMonitoringSignificant ||
        [LocationManager sharedInstance].monitoring == LocationMonitoringMove) {
        CLLocation *lastLocation = [LocationManager sharedInstance].location;
        CLLocation *location = [[CLLocation alloc] initWithLatitude:lastLocation.coordinate.latitude
                                                          longitude:lastLocation.coordinate.longitude];
        [self publishLocation:location trigger:@"p"];
    }
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    DDLogVerbose(@"didRegisterUserNotificationSettings %@", notificationSettings);
}

/*
 *
 * LocationManagerDelegate
 *
 */

- (void)newLocation:(CLLocation *)location {
    [self publishLocation:location trigger:nil];
}

- (void)timerLocation:(CLLocation *)location {
    [self publishLocation:location trigger:@"t"];
}

- (void)regionEvent:(CLRegion *)region enter:(BOOL)enter {
    CLLocation *location = [LocationManager sharedInstance].location;
    NSString *message = [NSString stringWithFormat:@"%@ %@",
                         (enter ?
                          NSLocalizedString(@"Entering",
                                            @"Display when entering region (region name follows)"):
                          NSLocalizedString(@"Leaving",
                                            @"Display when leaving region (region name follows)")
                          ),
                         region.identifier];
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = message;
    notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:1.0];
    [[UIApplication sharedApplication] scheduleLocalNotification:notification];

    Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopic]
                            inManagedObjectContext:[CoreData theManagedObjectContext]];

    if ([LocationManager sharedInstance].monitoring != LocationMonitoringQuiet && [Settings validIds]) {
        NSMutableDictionary *json = [@{
                                       @"_type": @"transition",
                                       @"lat": @(location.coordinate.latitude),
                                       @"lon": @(location.coordinate.longitude),
                                       @"tst": @(floor([location.timestamp timeIntervalSince1970])),
                                       @"acc": @(location.horizontalAccuracy),
                                       @"tid": [myself getEffectiveTid],
                                       @"event": enter ? @"enter" : @"leave",
                                       @"t": [region isKindOfClass:[CLBeaconRegion class]] ? @"b" : @"c"
                                       } mutableCopy];
        
        for (Region *anyRegion in myself.hasRegions) {
            if ([region.identifier isEqualToString:anyRegion.CLregion.identifier]) {
                anyRegion.name = anyRegion.name;
                if ([anyRegion.share boolValue]) {
                    [json setValue:region.identifier forKey:@"desc"];
                    [json setValue:@(floor([[anyRegion getAndFillTst] timeIntervalSince1970])) forKey:@"wtst"];
                    [self.connection sendData:[self jsonToData:json]
                                        topic:[[Settings theGeneralTopic] stringByAppendingString:@"/event"]
                                          qos:[Settings intForKey:@"qos_preference"]
                                       retain:NO];
                }
                if ([region isKindOfClass:[CLBeaconRegion class]]) {
                    if ([anyRegion.radius doubleValue] < 0) {
                        anyRegion.lat = [NSNumber numberWithDouble:location.coordinate.latitude];
                        anyRegion.lon = [NSNumber numberWithDouble:location.coordinate.longitude];
                        [self sendRegion:anyRegion];
                    }
                }

            }
        }
        
        if ([region isKindOfClass:[CLBeaconRegion class]]) {
            [self publishLocation:[LocationManager sharedInstance].location trigger:@"b"];
        } else {
            [self publishLocation:[LocationManager sharedInstance].location trigger:@"c"];
        }
    }
}

- (void)regionState:(CLRegion *)region inside:(BOOL)inside {
    DDLogVerbose(@"regionState %@ i:%d", region.identifier, inside);
    Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopic]
                            inManagedObjectContext:[CoreData theManagedObjectContext]];

    for (Region *anyRegion in myself.hasRegions) {
        if ([region.identifier isEqualToString:anyRegion.CLregion.identifier]) {
            anyRegion.name = anyRegion.name;
        }
    }
}

- (void)beaconInRange:(CLBeacon *)beacon region:(CLBeaconRegion *)region{
    if ([Settings validIds]) {
        Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopic]
                                inManagedObjectContext:[CoreData theManagedObjectContext]];

        NSMutableDictionary *json = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                    @"_type": @"beacon",
                                                                                    @"tid": [myself getEffectiveTid],
                                                                                    @"tst": @(floor([[LocationManager sharedInstance].location.timestamp timeIntervalSince1970])),
                                                                                    @"uuid": [beacon.proximityUUID UUIDString],
                                                                                    @"major": beacon.major,
                                                                                    @"minor": beacon.minor,
                                                                                    @"prox": @(beacon.proximity),
                                                                                    @"acc": @(beacon.accuracy),
                                                                                    @"rssi": @(beacon.rssi)
                                                                                    }];
        [self.connection sendData:[self jsonToData:json]
                            topic:[[Settings theGeneralTopic] stringByAppendingString:@"/beacon"]
                              qos:[Settings intForKey:@"qos_preference"]
                           retain:NO];
    }
}

#pragma ConnectionDelegate

- (void)showState:(Connection *)connection state:(NSInteger)state {
    self.connectionState = @(state);
    /**
     ** This is a hack to ensure the connection gets gracefully closed at the server
     **
     ** If the background task is ended, occasionally the disconnect message is not received well before the server senses the tcp disconnect
     **/
    
    if ([self.connectionState intValue] == state_closed) {
        if (self.backgroundTask) {
            DDLogVerbose(@"endBackGroundTask");
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
            self.backgroundTask = UIBackgroundTaskInvalid;
        }
        if (self.completionHandler) {
            DDLogVerbose(@"completionHandler");
            self.completionHandler(UIBackgroundFetchResultNewData);
            self.completionHandler = nil;
        }
    }
}

- (NSManagedObjectContext *)queueManagedObjectContext
{
    if (!_queueManagedObjectContext) {
        _queueManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [_queueManagedObjectContext setParentContext:[CoreData theManagedObjectContext]];
    }
    return _queueManagedObjectContext;
}

- (BOOL)handleMessage:(Connection *)connection data:(NSData *)data onTopic:(NSString *)topic retained:(BOOL)retained {
    DDLogVerbose(@"handleMessage");
    
    if (![[OwnTracking sharedInstance] processMessage:topic data:data retained:retained context:self.queueManagedObjectContext]) {
        return false;
    }
    
    NSArray *baseComponents = [[Settings theGeneralTopic] componentsSeparatedByString:@"/"];
    NSArray *topicComponents = [[Settings theGeneralTopic] componentsSeparatedByString:@"/"];
    
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
    
    DDLogVerbose(@"device %@", device);
    
    if (ownDevice) {
        
        NSError *error;
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (json && [json isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dictionary = json;
            if ([dictionary[@"_type"] isEqualToString:@"cmd"]) {
                DDLogVerbose(@"msg received cmd:%@", dictionary[@"action"]);
#ifdef DEBUG
                if (true /* dirty work around not being able to set simulator .otrc */) {
#else
                if ([Settings boolForKey:@"cmd_preference"]) {
#endif
                    if ([dictionary[@"action"] isEqualToString:@"dump"]) {
                        [self dump];
                    } else if ([dictionary[@"action"] isEqualToString:@"reportLocation"]) {
                        if ([LocationManager sharedInstance].monitoring == LocationMonitoringSignificant ||
                            [LocationManager sharedInstance].monitoring == LocationMonitoringMove ||
                            [Settings boolForKey:@"allowremotelocation_preference"]) {
                            [self publishLocation:[LocationManager sharedInstance].location trigger:@"r"];
                        }
                    } else if ([dictionary[@"action"] isEqualToString:@"reportSteps"]) {
                        [self stepsFrom:dictionary[@"from"] to:dictionary[@"to"]];
                    } else if ([dictionary[@"action"] isEqualToString:@"waypoints"]) {
                        [self waypoints];
                    } else if ([dictionary[@"action"] isEqualToString:@"action"]) {
                        NSString *content = [dictionary objectForKey:@"content"];
                        NSString *url = [dictionary objectForKey:@"url"];
                        NSString *notificationMessage = [dictionary objectForKey:@"notification"];
                        NSNumber *external = [dictionary objectForKey:@"extern"];

                        [Settings setString:content forKey:SETTINGS_ACTION];
                        [Settings setString:url forKey:SETTINGS_ACTIONURL];
                        [Settings setBool:[external boolValue] forKey:SETTINGS_ACTIONEXTERN];
                        
                        if (notificationMessage) {
                            UILocalNotification *notification = [[UILocalNotification alloc] init];
                            notification.alertBody = notificationMessage;
                            notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:1.0];
                            [[UIApplication sharedApplication] scheduleLocalNotification:notification];
                        }

                        if (content || url) {
                            if (url && ![url isEqualToString:self.action]) {
                                self.action = url;
                            } else {
                                if (content && ![content isEqualToString:self.action]) {
                                    self.action = content;
                                }
                            }
                        } else {
                            self.action = nil;
                        }
                    } else if ([dictionary[@"action"] isEqualToString:@"setWaypoints"]) {
                        NSDictionary *payload = dictionary[@"payload"];
                        [Settings waypointsFromDictionary:payload];
                    } else {
                        DDLogVerbose(@"unknown action %@", dictionary[@"action"]);
                    }
                }
            } else {
                DDLogVerbose(@"unhandled record type %@", dictionary[@"_type"]);
            }
        } else {
            DDLogVerbose(@"illegal json %@ %@ %@", error.localizedDescription, error.userInfo, data.description);
        }
    }
    return true;
}

- (void)messageDelivered:(Connection *)connection msgID:(UInt16)msgID {
    DDLogVerbose(@"Message delivered id=%u", msgID);
}

- (void)totalBuffered:(Connection *)connection count:(NSUInteger)count {
    self.connectionBuffered = @(count);
    [UIApplication sharedApplication].applicationIconBadgeNumber = count;
}

- (void)dump {
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                @"_type":@"dump",
                                                                                @"configuration":[Settings toDictionary],
                                                                                }];
    [self.connection sendData:[self jsonToData:json]
                        topic:[[Settings theGeneralTopic] stringByAppendingString:@"/dump"]
                          qos:[Settings intForKey:@"qos_preference"]
                       retain:NO];
}

- (void)waypoints {
    NSMutableDictionary *json = [[Settings waypointsToDictionary] mutableCopy];
    [self.connection sendData:[self jsonToData:json]
                        topic:[[Settings theGeneralTopic] stringByAppendingString:@"/waypoints"]
                          qos:[Settings intForKey:@"qos_preference"]
                       retain:NO];
}

- (void)stepsFrom:(NSNumber *)from to:(NSNumber *)to {
    NSDate *toDate;
    NSDate *fromDate;
    if (to && [to isKindOfClass:[NSNumber class]]) {
        toDate = [NSDate dateWithTimeIntervalSince1970:[to doubleValue]];
    } else {
        toDate = [NSDate date];
    }
    if (from && [from isKindOfClass:[NSNumber class]]) {
        fromDate = [NSDate dateWithTimeIntervalSince1970:[from doubleValue]];
    } else {
        NSDateComponents *components = [[NSCalendar currentCalendar]
                                        components: NSCalendarUnitDay |
                                        NSCalendarUnitHour |
                                        NSCalendarUnitMinute |
                                        NSCalendarUnitSecond |
                                        NSCalendarUnitMonth |
                                        NSCalendarUnitYear
                                        fromDate:toDate];
        components.hour = 0;
        components.minute = 0;
        components.second = 0;
        
        fromDate = [[NSCalendar currentCalendar] dateFromComponents:components];
    }
    
    if ([[[UIDevice currentDevice] systemVersion] compare:@"8.0"] != NSOrderedAscending) {
        DDLogVerbose(@"isStepCountingAvailable %d", [CMPedometer isStepCountingAvailable]);
        DDLogVerbose(@"isFloorCountingAvailable %d", [CMPedometer isFloorCountingAvailable]);
        DDLogVerbose(@"isDistanceAvailable %d", [CMPedometer isDistanceAvailable]);
        if (!self.pedometer) {
            self.pedometer = [[CMPedometer alloc] init];
        }
        [self.pedometer queryPedometerDataFromDate:fromDate
                                            toDate:toDate
                                       withHandler:^(CMPedometerData *pedometerData, NSError *error) {
                                           DDLogVerbose(@"StepCounter queryPedometerDataFromDate handler %ld %ld %ld %ld %@",
                                                        [pedometerData.numberOfSteps longValue],
                                                        [pedometerData.floorsAscended longValue],
                                                        [pedometerData.floorsDescended longValue],
                                                        [pedometerData.distance longValue],
                                                        error.localizedDescription);
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               
                                               NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
                                               [json addEntriesFromDictionary:@{
                                                                                @"_type": @"steps",
                                                                                @"tst": @(floor([[NSDate date] timeIntervalSince1970])),
                                                                                @"from": @(floor([fromDate timeIntervalSince1970])),
                                                                                @"to": @(floor([toDate timeIntervalSince1970])),
                                                                                }];
                                               if (pedometerData) {
                                                   [json setObject:pedometerData.numberOfSteps forKey:@"steps"];
                                                   if (pedometerData.floorsAscended) {
                                                       [json setObject:pedometerData.floorsAscended forKey:@"floorsup"];
                                                   }
                                                   if (pedometerData.floorsDescended) {
                                                       [json setObject:pedometerData.floorsDescended forKey:@"floorsdown"];
                                                   }
                                                   if (pedometerData.distance) {
                                                       [json setObject:pedometerData.distance forKey:@"distance"];
                                                   }
                                               } else {
                                                   [json setObject:@(-1) forKey:@"steps"];
                                               }
                                               
                                               [self.connection sendData:[self jsonToData:json]
                                                                   topic:[[Settings theGeneralTopic] stringByAppendingString:@"/step"]
                                                                     qos:[Settings intForKey:@"qos_preference"]
                                                                  retain:NO];
                                           });
                                       }];
        
    } else if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0"] != NSOrderedAscending) {
        DDLogVerbose(@"isStepCountingAvailable %d", [CMStepCounter isStepCountingAvailable]);
        if (!self.stepCounter) {
            self.stepCounter = [[CMStepCounter alloc] init];
        }
        [self.stepCounter queryStepCountStartingFrom:fromDate
                                                  to:toDate
                                             toQueue:[[NSOperationQueue alloc] init]
                                         withHandler:^(NSInteger steps, NSError *error)
         {
             DDLogVerbose(@"StepCounter queryStepCountStartingFrom handler %ld %@ %@", (long)steps,
                          error.localizedDescription,
                          error.userInfo);
             dispatch_async(dispatch_get_main_queue(), ^{
                 
                 NSMutableDictionary *json = [@{
                                        @"_type": @"steps",
                                        @"tst": @(floor([[NSDate date] timeIntervalSince1970])),
                                        @"from": @(floor([fromDate timeIntervalSince1970])),
                                        @"to": @(floor([toDate timeIntervalSince1970])),
                                        @"steps": error ? @(-1) : @(steps)
                                        } mutableCopy];
                 [self.connection sendData:[self jsonToData:json]
                                     topic:[[Settings theGeneralTopic] stringByAppendingString:@"/step"]
                                       qos:[Settings intForKey:@"qos_preference"]
                                    retain:NO];
             });
         }];
    } else {
        NSMutableDictionary *json = [@{
                               @"_type": @"steps",
                               @"tst": @(floor([[NSDate date] timeIntervalSince1970])),
                               @"from": @(floor([fromDate timeIntervalSince1970])),
                               @"to": @(floor([toDate timeIntervalSince1970])),
                               @"steps": @(-1)
                               } mutableCopy];
        [self.connection sendData:[self jsonToData:json]
                            topic:[[Settings theGeneralTopic] stringByAppendingString:@"/step"]
                              qos:[Settings intForKey:@"qos_preference"]
                           retain:NO];
    }
}

#pragma actions

- (void)sendNow {
    DDLogVerbose(@"sendNow");
    CLLocation *location = [LocationManager sharedInstance].location;
    [self publishLocation:location trigger:@"u"];
}

- (void)connectionOff {
    DDLogVerbose(@"connectionOff");
    [self.connection disconnect];
}

- (void)terminateSession {
    DDLogVerbose(@"terminateSession");

    [self connectionOff];
    [[OwnTracking sharedInstance] syncProcessing];
    [[LocationManager sharedInstance] resetRegions];
    [self.connection reset];
    NSArray *friends = [Friend allFriendsInManagedObjectContext:[CoreData theManagedObjectContext]];
    for (Friend *friend in friends) {
        [[CoreData theManagedObjectContext] deleteObject:friend];
    }
    [CoreData saveContext];
}

- (void)reconnect {
    DDLogVerbose(@"reconnect");
    [self.connection disconnect];
    [self connect];
    [self sendNow];
}

- (void)publishLocation:(CLLocation *)location trigger:(NSString *)trigger {
    if (location &&
        CLLocationCoordinate2DIsValid(location.coordinate) &&
        location.coordinate.latitude != 0.0 &&
        location.coordinate.longitude != 0.0 &&
        [Settings validIds]) {
        Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopic]
                          inManagedObjectContext:[CoreData theManagedObjectContext]];
        if (friend) {
            friend.tid = [Settings stringForKey:@"trackerid_preference"];
            
            Waypoint *waypoint = [[OwnTracking sharedInstance] addWaypointFor:friend
                                                                     location:location
                                                                      trigger:trigger
                                                                      context:[CoreData theManagedObjectContext]];
            if (waypoint) {
                [CoreData saveContext];
                
                NSMutableDictionary *json = [[[OwnTracking sharedInstance] waypointAsJSON:waypoint] mutableCopy];
                if (json) {
                    NSData *data = [self jsonToData:json];
                    [self.connection sendData:data
                                        topic:[Settings theGeneralTopic]
                                          qos:[Settings intForKey:@"qos_preference"]
                                       retain:[Settings boolForKey:@"retain_preference"]];
                } else {
                    DDLogError(@"no JSON created from waypoint %@", waypoint);
                }
                [[OwnTracking sharedInstance] limitWaypointsFor:friend
                                                      toMaximum:[Settings intForKey:@"positions_preference"]
                                         inManagedObjectContext:[CoreData theManagedObjectContext]];
            } else {
                DDLogError(@"waypoint creation failed from friend %@, location %@", friend, location);
            }
        } else {
            DDLogError(@"no friend found");
        }
    } else {
        DDLogError(@"invalid location");
    }
}

- (void)sendEmpty:(NSString *)topic {
    [self.connection sendData:nil
                        topic:topic
                          qos:[Settings intForKey:@"qos_preference"]
                       retain:YES];
}

- (void)requestLocationFromFriend:(Friend *)friend {
    NSMutableDictionary *json = [@{
                           @"_type": @"cmd",
                           @"action": @"reportLocation"
                           } mutableCopy];
    [self.connection sendData:[self jsonToData:json]
                        topic:[friend.topic stringByAppendingString:@"/cmd"]
                          qos:[Settings intForKey:@"qos_preference"]
                       retain:NO];
}

- (void)sendRegion:(Region *)region {
    if ([Settings validIds]) {
        NSMutableDictionary *json = [[[OwnTracking sharedInstance] regionAsJSON:region] mutableCopy];
        NSData *data = [self jsonToData:json];
        [self.connection sendData:data
                            topic:[[Settings theGeneralTopic] stringByAppendingString:@"/waypoint"]
                              qos:[Settings intForKey:@"qos_preference"]
                           retain:NO];
    }
}

#pragma internal helpers

- (void)connect {
    if ([Settings intForKey:@"mode"] == 3) {
        self.connection.key = [Settings stringForKey:@"secret_preference"];
        [self.connection connectHTTP:[Settings stringForKey:@"url_preference"]];
    } else {
    NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                 inDomain:NSUserDomainMask
                                                        appropriateForURL:nil
                                                                   create:YES
                                                                    error:nil];
    NSArray *certificates = nil;
    NSString *fileName = [Settings stringForKey:@"clientpkcs"];
    if (fileName && fileName.length) {
        DDLogVerbose(@"getting p12 filename:%@ passphrase:%@", fileName, [Settings stringForKey:@"passphrase"]);
        NSString *clientPKCSPath = [directoryURL.path stringByAppendingPathComponent:fileName];
        certificates = [MQTTCFSocketTransport clientCertsFromP12:clientPKCSPath
                                                 passphrase:[Settings stringForKey:@"passphrase"]];
        if (!certificates) {
            [AlertView alert:NSLocalizedString(@"TLS Client Certificate",
                                               @"Heading for certificate error message")
                     message:NSLocalizedString(@"incorrect file or passphrase",
                                               @"certificate error message")
             ];
        }
    }
    
    MQTTSSLSecurityPolicy *securityPolicy = nil;
    if ([Settings boolForKey:@"usepolicy"]) {
       securityPolicy = [MQTTSSLSecurityPolicy policyWithPinningMode:[Settings intForKey:@"policymode"]];
        if (!securityPolicy) {
            [AlertView alert:@"TLS Security Policy" message:@"invalide mode"];
        }

        NSString *fileNames = [Settings stringForKey:@"servercer"];
        NSMutableArray *certs = nil;
        NSArray *components = [fileNames componentsSeparatedByString:@" "];
        for (NSString *fileName in components) {
            if (fileName && fileName.length) {
                NSString *serverCERpath = [directoryURL.path stringByAppendingPathComponent:fileName];;
                NSData *certificateData = [NSData dataWithContentsOfFile:serverCERpath];
                if (certificateData) {
                    if (!certs) {
                        certs = [[NSMutableArray alloc] init];
                    }
                    [certs addObject:certificateData];
                } else {
                    [AlertView alert:NSLocalizedString(@"TLS Security Policy",
                                                       @"Heading for security policy error message")
                             message:NSLocalizedString(@"invalid certificate file",
                                                       @"certificate file error message")
                     ];
                }
            }
        }
        securityPolicy.pinnedCertificates = certs;
        securityPolicy.allowInvalidCertificates = [Settings boolForKey:@"allowinvalidcerts"];
        securityPolicy.validatesCertificateChain = [Settings boolForKey:@"validatecertificatechain"];
        securityPolicy.validatesDomainName = [Settings boolForKey:@"validatedomainname"];
    }

    MQTTQosLevel subscriptionQos =[Settings intForKey:@"subscriptionqos_preference"];
    NSArray *subscriptions = [[Settings theSubscriptions] componentsSeparatedByCharactersInSet:
                              [NSCharacterSet whitespaceCharacterSet]];
    
    self.connection.subscriptions = subscriptions;
    self.connection.subscriptionQos = subscriptionQos;
    
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                @"tst": [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]],
                                                                                @"_type": @"lwt"}];
    self.connection.key = [Settings stringForKey:@"secret_preference"];
    
    [self.connection connectTo:[Settings stringForKey:@"host_preference"]
                          port:[Settings intForKey:@"port_preference"]
                           tls:[Settings boolForKey:@"tls_preference"]
                     keepalive:[Settings intForKey:@"keepalive_preference"]
                         clean:[Settings intForKey:@"clean_preference"]
                          auth:[Settings theMqttAuth]
                          user:[Settings theMqttUser]
                          pass:[Settings theMqttPass]
                     willTopic:[Settings theWillTopic]
                          will:[self jsonToData:json]
                       willQos:[Settings intForKey:@"willqos_preference"]
                willRetainFlag:[Settings boolForKey:@"willretain_preference"]
                  withClientId:[Settings theClientId]
                securityPolicy:securityPolicy
                  certificates:certificates];
    }
 }

- (NSData *)jsonToData:(NSDictionary *)jsonObject {
    NSData *data;
    
    if ([NSJSONSerialization isValidJSONObject:jsonObject]) {
        NSError *error;
        data = [NSJSONSerialization dataWithJSONObject:jsonObject options:0 /* not pretty printed */ error:&error];
        if (!data) {
            DDLogError(@"dataWithJSONObject failed: %@ %@ %@",
                                 error.localizedDescription,
                                 error.userInfo,
                                 [jsonObject description]);
        }
    } else {
        DDLogError(@"isValidJSONObject failed %@", [jsonObject description]);
    }
    return data;
}

@end

