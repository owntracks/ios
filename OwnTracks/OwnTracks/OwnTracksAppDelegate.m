//
//  OwnTracksAppDelegate.m
//  OwnTracks
//
//  Created by Christoph Krey on 03.02.14.
//  Copyright (c) 2014 OwnTracks. All rights reserved.
//

#import "OwnTracksAppDelegate.h"
#import "CoreData.h"
#import "Friend+Create.h"
#import "Location+Create.h"
#import "AlertView.h"

@interface OwnTracksAppDelegate()
@property (strong, nonatomic) NSTimer *disconnectTimer;
@property (strong, nonatomic) NSTimer *activityTimer;
@property (strong, nonatomic) UIAlertView *alertView;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@property (strong, nonatomic) void (^completionHandler)(UIBackgroundFetchResult);
@property (strong, nonatomic) CoreData *coreData;
@property (strong, nonatomic) NSDate *locationLastSent;
@property (strong, nonatomic) NSString *processingMessage;
@property (strong, nonatomic) CMStepCounter *stepCounter;
@end

#define BACKGROUND_DISCONNECT_AFTER 8.0
#define REMINDER_AFTER 300.0

#define MAX_OTHER_LOCATIONS 1

#undef REMOTE_NOTIFICATIONS

@implementation OwnTracksAppDelegate

#pragma ApplicationDelegate

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
#ifdef DEBUG
    NSLog(@"App willFinishLaunchingWithOptions");
    NSEnumerator *enumerator = [launchOptions keyEnumerator];
    NSString *key;
    while ((key = [enumerator nextObject])) {
        NSLog(@"App options %@:%@", key, [[launchOptions objectForKey:key] description]);
    }
#endif
    
    self.backgroundTask = UIBackgroundTaskInvalid;
    self.completionHandler = nil;
    
#ifdef DEBUG
    NSLog(@"App setMinimumBackgroundFetchInterval %f", UIApplicationBackgroundFetchIntervalMinimum);
#endif
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
#ifdef DEBUG
    NSLog(@"App didFinishLaunchingWithOptions");
    NSEnumerator *enumerator = [launchOptions keyEnumerator];
    NSString *key;
    while ((key = [enumerator nextObject])) {
        NSLog(@"App options %@:%@", key, [[launchOptions objectForKey:key] description]);
    }
#endif
    
    /*
     * Core Data using UIManagedDocument
     */
    
    self.coreData = [[CoreData alloc] init];
    UIDocumentState state;
    
    do {
        state = self.coreData.documentState;
        if (state & UIDocumentStateClosed || ![CoreData theManagedObjectContext]) {
            NSLog(@"APP Waiting for document to open documentState = 0x%02lx theManagedObjectContext = %@",
                  (long)self.coreData.documentState,
                  [CoreData theManagedObjectContext]);
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
    } while (state & UIDocumentStateClosed || ![CoreData theManagedObjectContext]);
    
    /*
     * Settings
     */
    
    self.settings = [[Settings alloc] init];
    
    /*
     * CLLocationManager
     */
    
    if ([CLLocationManager locationServicesEnabled]) {
        self.manager = [[CLLocationManager alloc] init];
        self.locationLastSent = [NSDate date]; // Do not sent old locations
        self.manager.delegate = self;
        
        for (CLRegion *region in self.manager.monitoredRegions) {
#ifdef DEBUG
            NSLog(@"stopMonitoringForRegion %@", region.identifier);
            for (CLRegion *region in self.manager.monitoredRegions) {
                NSLog(@"region %@", region.identifier);
            }
#endif
            [self.manager stopMonitoringForRegion:region];
        }

        self.monitoring = [self.settings intForKey:@"monitoring_preference"];
        self.ranging = [self.settings boolForKey:@"ranging_preference"];

    }

    /*
     * MQTT connection
     */
    
    self.connection = [[Connection alloc] init];
    self.connection.delegate = self;
    
    [self connect];
    
#ifdef REMOTE_NOTIFICATIONS
    /*
     * Remote Notifications
     */
    
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert];
#endif // REMOTE_NOTIFICATIONS
    
    // Register for battery level and state change notifications.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(batteryLevelChanged:)
                                                 name:UIDeviceBatteryLevelDidChangeNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(batteryStateChanged:)
                                                 name:UIDeviceBatteryStateDidChangeNotification object:nil];
    
    
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:TRUE];
    
    return YES;
}

- (void)saveContext
{
    NSManagedObjectContext *managedObjectContext = [CoreData theManagedObjectContext];
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges]) {
            NSError *error = nil;
#ifdef DEBUG
            NSLog(@"App save context");
#endif
            if (![managedObjectContext save:&error]) {
                NSString *message = [NSString stringWithFormat:@"CoreData unresolved error %@, %@", error, [error userInfo]];
#ifdef DEBUG
                NSLog(@"%@", message);
#endif
                [AlertView alert:@"App Failure" message:[message substringToIndex:128]];
            }
        }
    }
}

- (void)batteryLevelChanged:(NSNotification *)notification
{
#ifdef DEBUG
    NSLog(@"App batteryLevelChanged %.0f", [UIDevice currentDevice].batteryLevel);
#endif
    
    // No, we do not want to switch off location monitoring when battery gets low
}

- (void)batteryStateChanged:(NSNotification *)notification
{
#ifdef DEBUG
    const NSDictionary *states = @{
                                   @(UIDeviceBatteryStateUnknown): @"unknown",
                                   @(UIDeviceBatteryStateUnplugged): @"unplugged",
                                   @(UIDeviceBatteryStateCharging): @"charging",
                                   @(UIDeviceBatteryStateFull): @"full"
                                   };
    
    NSLog(@"App batteryLevelChanged %@ (%ld)",
          states[@([UIDevice currentDevice].batteryState)],
          (long)[UIDevice currentDevice].batteryState);
#endif
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
#ifdef DEBUG
    NSLog(@"App openURL %@ from %@ annotation %@", url, sourceApplication, annotation);
#endif
    
    if (url) {
        NSInputStream *input = [NSInputStream inputStreamWithURL:url];
        if ([input streamError]) {
            self.processingMessage = [NSString stringWithFormat:@"Error nputStreamWithURL %@ %@", [input streamError], url];
            return FALSE;
        }
        [input open];
        if ([input streamError]) {
            self.processingMessage = [NSString stringWithFormat:@"Error open %@ %@", [input streamError], url];
            return FALSE;
        }
        
        NSError *error;
        NSString *extension = [url pathExtension];
        if ([extension isEqualToString:@"otrc"] || [extension isEqualToString:@"mqtc"]) {
            error = [self.settings fromStream:input];
        } else if ([extension isEqualToString:@"otrw"] || [extension isEqualToString:@"mqtw"]) {
            error = [self.settings waypointsFromStream:input];
        } else {
            error = [NSError errorWithDomain:@"OwnTracks" code:2 userInfo:@{@"extension":extension}];
        }
        
        if (error) {
            self.processingMessage = [NSString stringWithFormat:@"Error processing file %@: %@",
                                      [url lastPathComponent],
                                      error];
            return FALSE;
        }
        self.processingMessage = [NSString stringWithFormat:@"File %@ successfully processed)",
                                  [url lastPathComponent]];
    }
    return TRUE;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
#ifdef DEBUG
    NSLog(@"App applicationWillResignActive");
#endif
    [self saveContext];
    
    // stop ranging when going background as connection will be cut
    for (CLBeaconRegion *beaconRegion in self.manager.rangedRegions) {
        [self.manager stopRangingBeaconsInRegion:beaconRegion];
    }
    
    [self.connection disconnect];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
#ifdef DEBUG
    NSLog(@"App applicationDidEnterBackground");
#endif
    self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
#ifdef DEBUG
                               NSLog(@"BackgroundTaskExpirationHandler");
#endif
                               
                               /*
                                * we might end up here if the connection could not be closed within the given
                                * background time
                                */
                               if (self.backgroundTask) {
                                   [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
                                   self.backgroundTask = UIBackgroundTaskInvalid;
                               }
                           }];
    if ([UIApplication sharedApplication].applicationIconBadgeNumber) {
        [self notification:@"OwnTracks has undelivered messages. Tap to restart"
                     after:REMINDER_AFTER
                  userInfo:@{@"notify": @"undelivered"}];
    }
}


- (void)applicationWillEnterForeground:(UIApplication *)application
{
#ifdef DEBUG
    NSLog(@"App applicationWillEnterForeground");
#endif
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
#ifdef DEBUG
    NSLog(@"App applicationDidBecomeActive");
#endif
    
    if (self.processingMessage) {
        [AlertView alert:@"App File Processing" message:self.processingMessage];
        self.processingMessage = nil;
        [self reconnect];
    }
    
    if (self.coreData.documentState) {
        NSString *message = [NSString stringWithFormat:@"Open CoreData %@ 0x%02lx",
                             self.coreData.fileURL,
                             (long)self.coreData.documentState];
        [AlertView alert:@"App Failure" message:message];
    }
    if (![CLLocationManager significantLocationChangeMonitoringAvailable]) {
        NSString *message = @"No significant location change monitoring available";
        [AlertView alert:@"App Failure" message:message];
    }
    if (![CLLocationManager locationServicesEnabled]) {
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        NSString *message = [NSString stringWithFormat:@"%@ %d",
                             @"Not authorized for CoreLocation",
                             status];
        [AlertView alert:@"App Failure" message:message];
    }
    [self.connection connectToLast];
    self.ranging = self.ranging;
    
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
#ifdef DEBUG
    NSLog(@"App applicationWillTerminate");
#endif
    [self saveContext];
    [self notification:@"OwnTracks terminated. Tap to restart" after:REMINDER_AFTER userInfo:nil];
}

- (void)application:(UIApplication *)app didReceiveLocalNotification:(UILocalNotification *)notification
{
#ifdef DEBUG
    NSLog(@"App didReceiveLocalNotification %@", notification.alertBody);
#endif
    if (notification.userInfo) {
        if ([notification.userInfo[@"notify"] isEqualToString:@"friend"]) {
            [AlertView alert:@"Friend Notification" message:notification.alertBody dismissAfter:2.0];
        }
    }
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
#ifdef DEBUG
    NSLog(@"App performFetchWithCompletionHandler");
#endif

    self.completionHandler = completionHandler;
    [self publishLocation:[self.manager location] automatic:TRUE addon:@{@"event": @"ping",@"desc":@""}];
}

#pragma CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
#ifdef DEBUG
    NSLog(@"App didUpdateLocations");
#endif
    
    for (CLLocation *location in locations) {
#ifdef DEBUG
        NSLog(@"App location %@", [location description]);
#endif
        if ([location.timestamp compare:self.locationLastSent] != NSOrderedAscending ) {
            [self publishLocation:location automatic:YES addon:nil];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
#ifdef DEBUG
    NSLog(@"App locationManager:didFailWithError %@", error);
#endif
    NSString *message = [NSString stringWithFormat:@"didFailWithError %@", error];
    [AlertView alert:@"App locationManager" message:message];
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
#ifdef DEBUG
    NSLog(@"App didEnterRegion %@", region);
#endif
    NSString *message = [NSString stringWithFormat:@"Entering %@", region.identifier];
    [self notification:message userInfo:nil];
    
    NSMutableDictionary *addon = [[NSMutableDictionary alloc] init];
    [addon setObject:@"enter" forKey:@"event" ];
    
    for (Location *location in [Location allWaypointsOfTopic:[self.settings theGeneralTopic]
                                      inManagedObjectContext:[CoreData theManagedObjectContext]]) {
        if ([region.identifier isEqualToString:location.region.identifier]) {
            location.remark = location.remark; // this touches the location and updates the overlay
            if ([location.share boolValue]) {
                [addon setValue:region.identifier forKey:@"desc"];
            }
        }
    }
    
    [self publishLocation:[self.manager location] automatic:TRUE addon:addon];
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
#ifdef DEBUG
    NSLog(@"App didExitRegion %@", region);
#endif
    
    NSString *message = [NSString stringWithFormat:@"Leaving %@", region.identifier];
    [self notification:message userInfo:nil];
    
    NSMutableDictionary *addon = [[NSMutableDictionary alloc] init];
    [addon setObject:@"leave" forKey:@"event" ];
    
    for (Location *location in [Location allWaypointsOfTopic:[self.settings theGeneralTopic]
                                      inManagedObjectContext:[CoreData theManagedObjectContext]]) {
        if ([region.identifier isEqualToString:location.region.identifier]) {
            location.remark = location.remark; // this touches the location and updates the overlay
            if ([location.share boolValue]) {
                [addon setValue:region.identifier forKey:@"desc"];
            }
        }
    }
    
    [self publishLocation:[self.manager location] automatic:TRUE addon:addon];
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region
{
#ifdef DEBUG
    NSLog(@"App didStartMonitoringForRegion %@", region);
#endif
    [self.manager requestStateForRegion:region];
}

-(void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
#ifdef DEBUG
    
    NSLog(@"App didDetermineState %ld %@", (long)state, region);
#endif
    if (state == CLRegionStateInside) {
        // start rainging if not in background
        if (self.ranging) {
            //if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
            if ([region isKindOfClass:[CLBeaconRegion class]]) {
                CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
                [self.manager startRangingBeaconsInRegion:beaconRegion];
            }
            //}
        }
    } else if (state == CLRegionStateOutside) {
        // stop ranging when leaving region
        if ([region isKindOfClass:[CLBeaconRegion class]]) {
            CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
            [self.manager stopRangingBeaconsInRegion:beaconRegion];
        }
    }

    if (self.delegate) {
        [self.delegate didDetermineState:state forRegion:region];
    }

}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error
{
#ifdef DEBUG
    NSLog(@"App monitoringDidFailForRegion %@ %@", region, error);
#endif
    NSString *message = [NSString stringWithFormat:@"%@ %@", region, error];
    [AlertView alert:@"App locationManager" message:message];
}
        
-(void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
#ifdef DEBUG
    NSLog(@"App didRangeBeacons %@ %@", beacons, region);
#endif
    
    for (CLBeacon *beacon in beacons) {
        
        NSDictionary *jsonObject = @{
                                     @"_type": @"beacon",
                                     @"tst": @(floor([self.manager.location.timestamp timeIntervalSince1970])),
                                     @"uuid": [beacon.proximityUUID UUIDString],
                                     @"major": beacon.major,
                                     @"minor": beacon.minor,
                                     @"prox": @(beacon.proximity),
                                     @"acc": @(round(beacon.accuracy)),
                                     @"rssi": @(beacon.rssi)
                                     };
        
        long msgID = [self.connection sendData:[self jsonToData:jsonObject]
                                         topic:[[self.settings theGeneralTopic] stringByAppendingString:@"/beacons"]
                                           qos:[self.settings intForKey:@"qos_preference"]
                                        retain:NO];
        
        if (msgID <= 0) {
#ifdef DEBUG
            NSString *message = [NSString stringWithFormat:@"Beacon %@",
                                 (msgID == -1) ? @"queued" : @"sent"];
            [self notification:message userInfo:nil];
#endif
        }
    }
    
    if (self.delegate) {
        [self.delegate didRangeBeacons:beacons inRegion:region];
    }
}

- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error
{
#ifdef DEBUG
    NSLog(@"App rangingBeaconsDidFailForRegion %@ %@", region, error);
#endif
}

#pragma ConnectionDelegate

- (void)showState:(NSInteger)state
{
    self.connectionState = @(state);
    
    /**
     ** This is a hack to ensure the connection gets gracefully closed at the server
     **
     ** If the background task is ended, occasionally the disconnect message is not received well before the server senses the tcp disconnect
     **/
    
    if (state == state_closed) {
        if (self.backgroundTask) {
#ifdef DEBUG
            NSLog(@"App endBackGroundTask");
#endif
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
            self.backgroundTask = UIBackgroundTaskInvalid;
        }
        if (self.completionHandler) {
#ifdef DEBUG
            NSLog(@"App completionHandler");
#endif
            self.completionHandler(UIBackgroundFetchResultNewData);
            self.completionHandler = nil;
        }
    }
}

- (void)handleMessage:(NSData *)data onTopic:(NSString *)topic
{
    if ([topic isEqualToString:[self.settings theGeneralTopic]]) {
        // received own data
        
        NSError *error;
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (dictionary) {
            if ([dictionary[@"_type"] isEqualToString:@"cmd"]) {
#ifdef DEBUG
                NSLog(@"App msg received cmd:%@", dictionary[@"action"]);
#endif
                if ([self.settings boolForKey:@"cmd_preference"]) {
                    if ([dictionary[@"action"] isEqualToString:@"dump"]) {
                        NSDictionary *dumpDict = @{
                                               @"_type":@"dump",
                                               @"configuration":[self.settings toDictionary],
                                               };
                        long msgID = [self.connection sendData:[self jsonToData:dumpDict]
                                                         topic:[self.settings theGeneralTopic]
                                                           qos:[self.settings intForKey:@"qos_preference"]
                                                        retain:NO];
                        
                        if (msgID <= 0) {
#ifdef DEBUG
                            NSString *message = [NSString stringWithFormat:@"Dump %@",
                                                 (msgID == -1) ? @"queued" : @"sent"];
                            [self notification:message userInfo:nil];
#endif
                        }
                    } else if ([dictionary[@"action"] isEqualToString:@"reportLocation"]) {
                        [self publishLocation:self.manager.location automatic:NO addon:nil];
                    } else if ([dictionary[@"action"] isEqualToString:@"reportSteps"]) {
#ifdef DEBUG
                        NSLog(@"StepCounter availability %d",
                              [CMStepCounter isStepCountingAvailable]
                              );
#endif
                        //if ([CMStepCounter isStepCountingAvailable]) {
                            if (!self.stepCounter) {
                                self.stepCounter = [[CMStepCounter alloc] init];
                            }
                            [self.stepCounter queryStepCountStartingFrom:[NSDate dateWithTimeIntervalSinceNow:-24.0*3600.0]
                                                                      to:[NSDate date]
                                                                 toQueue:[[NSOperationQueue alloc] init]
                                                             withHandler:^(NSInteger steps, NSError *error)
                             {
                                 dispatch_async(dispatch_get_main_queue(),
                                                ^{
                                                    
                                                    NSDictionary *jsonObject = @{
                                                                                 @"_type": @"steps",
                                                                                 @"tst": @(floor([[NSDate date] timeIntervalSince1970])),
                                                                                 @"steps": @(steps)
                                                                                 };
                                                    
                                                    long msgID = [self.connection sendData:[self jsonToData:jsonObject]
                                                                                     topic:[[self.settings theGeneralTopic] stringByAppendingString:@"/steps"]
                                                                                       qos:[self.settings intForKey:@"qos_preference"]
                                                                                    retain:NO];
                                                    
                                                    if (msgID <= 0) {
#ifdef DEBUG
                                                        NSString *message = [NSString stringWithFormat:@"Steps %@",
                                                                             (msgID == -1) ? @"queued" : @"sent"];
                                                        [self notification:message userInfo:nil];
#endif
                                                    }
                                                });
                             }];
                        //}

                    } else {
#ifdef DEBUG
                        NSLog(@"App received unknown action %@", dictionary[@"action"]);
#endif
                    }
                }
            } else {
#ifdef DEBUG
                NSLog(@"App received unknown record type %@", dictionary[@"_type"]);
#endif
            }
        } else {
#ifdef DEBUG
            NSLog(@"App received illegal json %@", error);
#endif
        }
        
    } else if ([topic isEqualToString:[NSString stringWithFormat:@"%@/%@", [self.settings theGeneralTopic], @"waypoints"]]) {
        // received own waypoint
    } else if ([topic isEqualToString:[NSString stringWithFormat:@"%@/%@", [self.settings theGeneralTopic], @"beacons"]]) {
        // received own beacon
    } else {
        // received other data
        NSString *deviceName = topic;
        if ([[deviceName lastPathComponent] isEqualToString:@"deviceToken"]) {
            deviceName = [deviceName stringByDeletingLastPathComponent];
        }
        if ([[deviceName lastPathComponent] isEqualToString:@"waypoints"]) {
            deviceName = [deviceName stringByDeletingLastPathComponent];
        }
        NSError *error;
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (dictionary) {
            if ([dictionary[@"_type"] isEqualToString:@"location"] ||
                [dictionary[@"_type"] isEqualToString:@"waypoint"]) {
#ifdef DEBUG
                NSLog(@"App json received lat:%g lon:%g acc:%.0f tst:%.0f rad:%.0f event:%@ desc:%@",
                      [dictionary[@"lat"] doubleValue],
                      [dictionary[@"lon"] doubleValue],
                      [dictionary[@"acc"] doubleValue],
                      [dictionary[@"tst"] doubleValue],
                      [dictionary[@"rad"] doubleValue],
                      dictionary[@"event"],
                      dictionary[@"desc"]
                      );
#endif
                CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(
                                                                               [dictionary[@"lat"] doubleValue],
                                                                               [dictionary[@"lon"] doubleValue]
                                                                               );
                
                CLLocation *location = [[CLLocation alloc] initWithCoordinate:coordinate
                                                                     altitude:0
                                                           horizontalAccuracy:[dictionary[@"acc"] doubleValue]
                                                             verticalAccuracy:0
                                                                    timestamp:[NSDate dateWithTimeIntervalSince1970:[dictionary[@"tst"] doubleValue]]];
                
                Location *newLocation = [Location locationWithTopic:deviceName
                                                          timestamp:location.timestamp
                                                         coordinate:location.coordinate
                                                           accuracy:location.horizontalAccuracy
                                                          automatic:[dictionary[@"_type"] isEqualToString:@"location"] ? TRUE : FALSE
                                                             remark:dictionary[@"desc"]
                                                             radius:[dictionary[@"rad"] doubleValue]
                                                              share:NO
                                             inManagedObjectContext:[CoreData theManagedObjectContext]];
                
                NSString *event = dictionary[@"event"];

                if (event) {
                    if ([event isEqualToString:@"enter"] || [event isEqualToString:@"leave"]) {
                        NSString *name = [newLocation.belongsTo name];
                        [self notification:[NSString stringWithFormat:@"%@ %@s %@",
                                            name ? name : newLocation.belongsTo.topic,
                                            event,
                                            newLocation.remark]
                                  userInfo:@{@"notify": @"friend"}];
                    }
                }

                [self limitLocationsWith:newLocation.belongsTo toMaximum:MAX_OTHER_LOCATIONS];

            } else if ([dictionary[@"_type"] isEqualToString:@"deviceToken"]) {
                Friend *friend = [Friend friendWithTopic:deviceName inManagedObjectContext:[CoreData theManagedObjectContext]];
                friend.device = dictionary[@"deviceToken"];
                
            } else {
#ifdef DEBUG
                NSLog(@"App received unknown record type %@)", dictionary[@"_type"]);
#endif
                // data other than json _type location/waypoint is silently ignored
            }
        } else {
#ifdef DEBUG
            NSLog(@"App received illegal json %@)", error);
#endif
            // data other than json is silently ignored
        }
    }
    [self saveContext];
}

- (void)messageDelivered:(UInt16)msgID
{
#ifdef DEBUG
    NSString *message = [NSString stringWithFormat:@"Message delivered id=%u", msgID];
    [self notification:message userInfo:nil];
#endif
}

- (void)totalBuffered:(NSUInteger)count
{
    self.connectionBuffered = @(count);

    [UIApplication sharedApplication].applicationIconBadgeNumber = count;

    if (!count) {
        NSArray *notifications = [[UIApplication sharedApplication] scheduledLocalNotifications];
        for (UILocalNotification *notification in notifications) {
            if (notification.userInfo) {
                if ([notification.userInfo[@"notify"] isEqualToString:@"undelivered"])
                    [[UIApplication sharedApplication] cancelLocalNotification:notification];
            }
        }
    }
}

#pragma actions

- (void)sendNow
{
#ifdef DEBUG
    NSLog(@"App sendNow");
#endif
    
    [self publishLocation:[self.manager location] automatic:FALSE addon:nil];
}
- (void)connectionOff
{
#ifdef DEBUG
    NSLog(@"App connectionOff");
#endif
    
    [self.connection disconnect];
}

- (void)setMonitoring:(int)monitoring
{
#ifdef DEBUG
    NSLog(@"App monitoring=%ld", (long)monitoring);
#endif
    
    _monitoring = monitoring;
    [self.settings setInt:monitoring forKey:@"monitoring_preference"];
    
    switch (monitoring) {
        case 2:
            self.manager.distanceFilter = [self.settings doubleForKey:@"mindist_preference"];
            self.manager.desiredAccuracy = kCLLocationAccuracyBest;
            self.manager.pausesLocationUpdatesAutomatically = YES;
            [self.manager stopMonitoringSignificantLocationChanges];
            
            [self.manager startUpdatingLocation];
            self.activityTimer = [NSTimer timerWithTimeInterval:[self.settings doubleForKey:@"mintime_preference"] target:self selector:@selector(activityTimer:) userInfo:Nil repeats:YES];
            [[NSRunLoop currentRunLoop] addTimer:self.activityTimer forMode:NSRunLoopCommonModes];
            break;
        case 1:
            [self.activityTimer invalidate];
            [self.manager stopUpdatingLocation];
            [self.manager startMonitoringSignificantLocationChanges];
            break;
        case 0:
        default:
            [self.activityTimer invalidate];
            [self.manager stopUpdatingLocation];
            [self.manager stopMonitoringSignificantLocationChanges];
            break;
    }
}

- (void)setRanging:(BOOL)ranging
{
#ifdef DEBUG
    NSLog(@"App ranging=%d", ranging);
#endif

    _ranging = ranging;
    [self.settings setBool:ranging forKey:@"ranging_preference"];

    if (!ranging) {
        for (CLBeaconRegion *beaconRegion in self.manager.rangedRegions) {
#ifdef DEBUG
            NSLog(@"stopRangingBeaconsInRegion %@", beaconRegion.identifier);
#endif
            [self.manager stopRangingBeaconsInRegion:beaconRegion];
        }
    }
    for (CLRegion *region in self.manager.monitoredRegions) {
#ifdef DEBUG
        NSLog(@"requestStateForRegion %@", region.identifier);
#endif
        [self.manager requestStateForRegion:region];
    }
}

- (void)activityTimer:(NSTimer *)timer
{
#ifdef DEBUG
    NSLog(@"App activityTimer");
#endif
    [self publishLocation:[self.manager location] automatic:TRUE addon:nil];
}

- (void)reconnect
{
#ifdef DEBUG
    NSLog(@"App reconnect");
#endif
    
    [self.connection disconnect];
    [self connect];
}

- (void)publishLocation:(CLLocation *)location automatic:(BOOL)automatic addon:(NSDictionary *)addon
{
    self.locationLastSent = location.timestamp;
    
    Location *newLocation = [Location locationWithTopic:[self.settings theGeneralTopic]
                                              timestamp:location.timestamp
                                             coordinate:location.coordinate
                                               accuracy:location.horizontalAccuracy
                                              automatic:automatic
                                                 remark:nil
                                                 radius:0
                                                  share:NO
                                 inManagedObjectContext:[CoreData theManagedObjectContext]];
    
    NSData *data = [self encodeLocationData:newLocation type:@"location" addon:addon];
    
    long msgID = [self.connection sendData:data
                                     topic:[self.settings theGeneralTopic]
                                       qos:[self.settings intForKey:@"qos_preference"]
                                    retain:[self.settings boolForKey:@"retain_preference"]];
    
    if (msgID <= 0) {
#ifdef DEBUG

        NSString *message = [NSString stringWithFormat:@"Location %@",
                             (msgID == -1) ? @"queued" : @"sent"];
        [self notification:message userInfo:nil];
#endif
    }
    
    [self limitLocationsWith:newLocation.belongsTo toMaximum:[self.settings intForKey:@"positions_preference"]];
    [self startBackgroundTimer];
    [self saveContext];
}

- (void)startBackgroundTimer
{
    /**
     *   In background, set timer to disconnect after BACKGROUND_DISCONNECT_AFTER sec. IOS will suspend app after 10 sec.
     **/
    
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        if (self.disconnectTimer && self.disconnectTimer.isValid) {
#ifdef DEBUG
            NSLog(@"App timer still running %@", self.disconnectTimer.fireDate);
#endif
        } else {
            self.disconnectTimer = [NSTimer timerWithTimeInterval:BACKGROUND_DISCONNECT_AFTER
                                                           target:self
                                                         selector:@selector(disconnectInBackground)
                                                         userInfo:Nil repeats:FALSE];
            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            [runLoop addTimer:self.disconnectTimer
                      forMode:NSDefaultRunLoopMode];
#ifdef DEBUG
            NSLog(@"App timerWithTimeInterval %@", self.disconnectTimer.fireDate);
#endif
        }
    }
}

- (void)sendEmpty:(Friend *)friend
{
    long msgID = [self.connection sendData:nil
                                     topic:friend.topic
                                       qos:[self.settings intForKey:@"qos_preference"]
                                    retain:YES];
    
    if (msgID <= 0) {
#ifdef DEBUG
        NSString *message = [NSString stringWithFormat:@"Delete send for %@ %@",
                             friend.topic,
                             (msgID == -1) ? @"queued" : @"sent"];
        [self notification:message userInfo:nil];
#endif
    }
}

- (void)sendWayPoint:(Location *)location
{
    NSMutableDictionary *addon = [[NSMutableDictionary alloc]init];
    
    if (location.remark) {
        [addon setValue:location.remark forKey:@"desc"];
    }
    
    NSData *data = [self encodeLocationData:location
                                       type:@"waypoint" addon:addon];
    
    long msgID = [self.connection sendData:data
                                     topic:[[self.settings theGeneralTopic] stringByAppendingString:@"/waypoints"]
                                       qos:[self.settings intForKey:@"qos_preference"]
                                    retain:NO];
    
    if (msgID <= 0) {
#ifdef DEBUG
        NSString *message = [NSString stringWithFormat:@"Waypoint %@",
                             (msgID == -1) ? @"queued" : @"sent"];
        [self notification:message userInfo:nil];
#endif
    }
    [self saveContext];
}

- (void)limitLocationsWith:(Friend *)friend toMaximum:(NSInteger)max
{
    NSArray *allLocations = [Location allAutomaticLocationsWithFriend:friend inManagedObjectContext:[CoreData theManagedObjectContext]];
    
    for (NSInteger i = [allLocations count]; i > max; i--) {
        Location *location = allLocations[i - 1];
        [[CoreData theManagedObjectContext] deleteObject:location];
    }
}

#pragma internal helpers

- (void)notification:(NSString *)message userInfo:(NSDictionary *)userInfo
{
    [self notification:message after:0 userInfo:userInfo];
}

- (void)notification:(NSString *)message after:(NSTimeInterval)after userInfo:(NSDictionary *)userInfo
{
#ifdef DEBUG
    NSLog(@"App notification %@", message);
#endif
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = message;
    notification.alertLaunchImage = @"itunesArtwork.png";
    notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:after];
    notification.userInfo = userInfo;
    [[UIApplication sharedApplication] scheduleLocalNotification:notification];
}

- (void)connect
{
    [self.connection connectTo:[self.settings stringForKey:@"host_preference"]
                          port:[self.settings intForKey:@"port_preference"]
                           tls:[self.settings boolForKey:@"tls_preference"]
                     keepalive:[self.settings intForKey:@"keepalive_preference"]
                         clean:[self.settings intForKey:@"clean_preference"]
                          auth:[self.settings boolForKey:@"auth_preference"]
                          user:[self.settings stringForKey:@"user_preference"]
                          pass:[self.settings stringForKey:@"pass_preference"]
                     willTopic:[self.settings theWillTopic]
                          will:[self jsonToData:@{
                                                  @"tst": [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]],
                                                  @"_type": @"lwt"}]
                       willQos:[self.settings intForKey:@"willqos_preference"]
                willRetainFlag:[self.settings boolForKey:@"willretain_preference"]
                  withClientId:[self.settings theClientId]];
}

- (void)disconnectInBackground
{
#ifdef DEBUG
    NSLog(@"App disconnectInBackground");
#endif
    
    self.disconnectTimer = nil;
    
    // stop ranging when disconnecting in background
    for (CLBeaconRegion *beaconRegion in self.manager.rangedRegions) {
        [self.manager stopRangingBeaconsInRegion:beaconRegion];
    }
    
    [self.connection disconnect];
    
    NSInteger number = [UIApplication sharedApplication].applicationIconBadgeNumber;
    if (number) {
        [self notification:[NSString stringWithFormat:@"OwnTracks has %ld undelivered messages", (long)number]
                     after:0
                  userInfo:@{@"notify": @"undelivered"}];
    }
}

- (NSData *)jsonToData:(NSDictionary *)jsonObject
{
    NSData *data;
    
    if ([NSJSONSerialization isValidJSONObject:jsonObject]) {
        NSError *error;
        data = [NSJSONSerialization dataWithJSONObject:jsonObject options:0 /* not pretty printed */ error:&error];
        if (!data) {
            NSString *message = [NSString stringWithFormat:@"Error %@ serializing JSON Object: %@", [error description], [jsonObject description]];
            [AlertView alert:@"App Failure" message:message];
        }
    } else {
        NSString *message = [NSString stringWithFormat:@"No valid JSON Object: %@", [jsonObject description]];
        [AlertView alert:@"App Failure" message:message];
    }
    return data;
}


- (NSData *)encodeLocationData:(Location *)location type:(NSString *)type addon:(NSDictionary *)addon
{
    NSMutableDictionary *jsonObject = [@{
                                         @"lat": [NSString stringWithFormat:@"%g", location.coordinate.latitude],
                                         @"lon": [NSString stringWithFormat:@"%g", location.coordinate.longitude],
                                         @"tst": [NSString stringWithFormat:@"%.0f", [location.timestamp timeIntervalSince1970]],
                                         @"_type": [NSString stringWithFormat:@"%@", type]
                                         } mutableCopy];
    
    
    double acc = [location.accuracy doubleValue];
    if (acc > 0) {
        [jsonObject setValue:[NSString stringWithFormat:@"%.0f", acc] forKey:@"acc"];
    }
    
    double rad = [location.regionradius doubleValue];
    if (rad > 0) {
        [jsonObject setValue:[NSString stringWithFormat:@"%.0f", rad] forKey:@"rad"];
    }
    
    if (addon) {
        [jsonObject addEntriesFromDictionary:addon];
    }
    
    if ([type isEqualToString:@"location"]) {
        [jsonObject setValue:[NSString stringWithFormat:@"%.0f", [UIDevice currentDevice].batteryLevel != -1.0 ?
                              [UIDevice currentDevice].batteryLevel * 100.0 : -1.0] forKey:@"batt"];
    }
    
    return [self jsonToData:jsonObject];
}

#ifdef REMOTE_NOTIFICATIONS

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
#ifdef DEBUG
    NSLog(@"App didFailToRegisterForRemoteNotificationsWithError %@", error);
#endif
    NSString *message = [NSString stringWithFormat:@"App didFailToRegisterForRemoteNotificationsWithError %@", error];
    [AlertView alert:@"App Failure" message:message];
    
}
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
#ifdef DEBUG
    NSLog(@"App didReceiveRemoteNotification %@", userInfo);
#endif
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
#ifdef DEBUG
    NSLog(@"App didReceiveRemoteNotification fetchCompletionHandler %@", userInfo);
#endif
    completionHandler(UIBackgroundFetchResultNewData);
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
#ifdef DEBUG
    NSLog(@"App didRegisterForRemoteNotificationsWithDeviceToken %@", deviceToken);
#endif
    
    NSDictionary *jsonObject = @{
                                 @"tst": [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]],
                                 @"dev": [NSString stringWithFormat:@"%@", [deviceToken description]],
                                 @"_type": [NSString stringWithFormat:@"%@", @"deviceToken"]
                                 };
    
    [self.connection sendData:[self jsonToData:jsonObject]
                        topic:[NSString stringWithFormat:@"%@/deviceToken", self.theGeneralTopic]
                          qos:1
                       retain:YES];
}
#endif // REMOTE_NOTIFICATIONS


@end
