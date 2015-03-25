//
//  OwnTracksAppDelegate.m
//  OwnTracks
//
//  Created by Christoph Krey on 03.02.14.
//  Copyright (c) 2014-2015 OwnTracks. All rights reserved.
//

#import "OwnTracksAppDelegate.h"
#import "CoreData.h"
#import "Friend+Create.h"
#import "Location+Create.h"
#import "AlertView.h"
#import <NotificationCenter/NotificationCenter.h>
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

//#define OLD 1

#ifdef DEBUG
#define DEBUGAPP FALSE
#else
#define DEBUGAPP FALSE
#endif

@interface OwnTracksAppDelegate()
@property (strong, nonatomic) NSTimer *disconnectTimer;
@property (strong, nonatomic) NSTimer *activityTimer;
@property (strong, nonatomic) UIAlertView *alertView;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@property (strong, nonatomic) void (^completionHandler)(UIBackgroundFetchResult);
@property (strong, nonatomic) CoreData *coreData;
@property (strong, nonatomic) NSString *processingMessage;
@property (strong, nonatomic) CMStepCounter *stepCounter;
@property (strong, nonatomic) CMPedometer *pedometer;
@end

#define BACKGROUND_DISCONNECT_AFTER 8.0
#define REMINDER_AFTER 300.0

#define MAX_OTHER_LOCATIONS 1

@implementation OwnTracksAppDelegate

#pragma ApplicationDelegate

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if (DEBUGAPP)  {
        NSLog(@"willFinishLaunchingWithOptions");
        NSEnumerator *enumerator = [launchOptions keyEnumerator];
        NSString *key;
        while ((key = [enumerator nextObject])) {
            NSLog(@"%@:%@", key, [[launchOptions objectForKey:key] description]);
        }
    }
    
    self.backgroundTask = UIBackgroundTaskInvalid;
    self.completionHandler = nil;
    
    
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0"] != NSOrderedAscending) {
        if (DEBUGAPP) NSLog(@"setMinimumBackgroundFetchInterval %f", UIApplicationBackgroundFetchIntervalMinimum);
        [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    }
    
    if ([[[UIDevice currentDevice] systemVersion] compare:@"8.0"] != NSOrderedAscending) {
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes: UIUserNotificationTypeAlert |
                                                UIUserNotificationTypeBadge |
                                                UIUserNotificationTypeSound
                                                                                 categories:[NSSet setWithObjects:nil]];
        if (DEBUGAPP) NSLog(@"registerUserNotificationSettings %@", settings);
        [application registerUserNotificationSettings:settings];
    }
    
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if (DEBUGAPP) {
        NSLog(@"didFinishLaunchingWithOptions");
        NSEnumerator *enumerator = [launchOptions keyEnumerator];
        NSString *key;
        while ((key = [enumerator nextObject])) {
            NSLog(@"%@:%@", key, [[launchOptions objectForKey:key] description]);
        }
    }
    [Fabric with:@[CrashlyticsKit]];
    
    self.coreData = [[CoreData alloc] init];
    UIDocumentState state;
    
    do {
        state = self.coreData.documentState;
        if (state & UIDocumentStateClosed || ![CoreData theManagedObjectContext]) {
            if (DEBUGAPP) NSLog(@"documentState 0x%02lx theManagedObjectContext %@",
                                (long)self.coreData.documentState,
                                [CoreData theManagedObjectContext]);
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
    } while (state & UIDocumentStateClosed || ![CoreData theManagedObjectContext]);
    
    self.settings = [[Settings alloc] init];
    
    self.connection = [[Connection alloc] init];
    self.connection.delegate = self;
    [self connect];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(batteryLevelChanged:)
                                                 name:UIDeviceBatteryLevelDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(batteryStateChanged:)
                                                 name:UIDeviceBatteryStateDidChangeNotification object:nil];
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:TRUE];
    
    LocationManager *locationManager = [LocationManager sharedInstance];
    locationManager.delegate = self;
    locationManager.monitoring = [self.settings intForKey:@"monitoring_preference"];
    locationManager.ranging = [self.settings boolForKey:@"ranging_preference"];
    locationManager.minDist = [self.settings doubleForKey:@"mindist_preference"];
    locationManager.minTime = [self.settings doubleForKey:@"mintime_preference"];
    [locationManager start];
    
    return YES;
}

- (void)saveContext {
    NSManagedObjectContext *managedObjectContext = [CoreData theManagedObjectContext];    
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges]) {
            NSError *error = nil;
            if (DEBUGAPP) NSLog(@"managedObjectContext save");
            if (![managedObjectContext save:&error]) {
                NSString *message = [NSString stringWithFormat:@"%@", error.localizedDescription];
                if (DEBUGAPP) NSLog(@"managedObjectContext save error: %@", message);
                [AlertView alert:@"save" message:[message substringToIndex:128]];
            }
        }
    }
}

- (void)batteryLevelChanged:(NSNotification *)notification {
    if (DEBUGAPP) NSLog(@"batteryLevelChanged %.0f", [UIDevice currentDevice].batteryLevel);
    // No, we do not want to switch off location monitoring when battery gets low
}

- (void)batteryStateChanged:(NSNotification *)notification {
    if (DEBUGAPP) {
        const NSDictionary *states = @{
                                       @(UIDeviceBatteryStateUnknown): @"unknown",
                                       @(UIDeviceBatteryStateUnplugged): @"unplugged",
                                       @(UIDeviceBatteryStateCharging): @"charging",
                                       @(UIDeviceBatteryStateFull): @"full"
                                       };
        
        NSLog(@"batteryStateChanged %@ (%ld)",
              states[@([UIDevice currentDevice].batteryState)],
              (long)[UIDevice currentDevice].batteryState);
    }
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    if (DEBUGAPP) NSLog(@"openURL %@ from %@ annotation %@", url, sourceApplication, annotation);
    if (DEBUGAPP) NSLog(@"URL scheme %@ extension %@", url.scheme, url.pathExtension);
    
    if (url) {
        if (![url.scheme isEqualToString:@"owntracks"]) {
            NSInputStream *input = [NSInputStream inputStreamWithURL:url];
            if ([input streamError]) {
                self.processingMessage = [NSString stringWithFormat:@"inputStreamWithURL %@ %@", [input streamError], url];
                return FALSE;
            }
            [input open];
            if ([input streamError]) {
                self.processingMessage = [NSString stringWithFormat:@"open %@ %@", [input streamError], url];
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
                                          error.localizedDescription];
                return FALSE;
            }
            self.processingMessage = [NSString stringWithFormat:@"File %@ successfully processed)",
                                      [url lastPathComponent]];
        }
    }
    return TRUE;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    if (DEBUGAPP) NSLog(@"applicationWillResignActive");
    [self saveContext];
    [[LocationManager sharedInstance] sleep];
    [self.connection disconnect];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    if (DEBUGAPP) NSLog(@"applicationDidEnterBackground");
    self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                               if (DEBUGAPP) NSLog(@"BackgroundTaskExpirationHandler");
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


- (void)applicationWillEnterForeground:(UIApplication *)application {
    if (DEBUGAPP) NSLog(@"applicationWillEnterForeground");
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if (DEBUGAPP) NSLog(@"applicationDidBecomeActive");
    
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
    [self.connection connectToLast];
    [[LocationManager sharedInstance] wakeup];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    if (DEBUGAPP) NSLog(@"applicationWillTerminate");
    [[LocationManager sharedInstance] stop];
    [self saveContext];
}

- (void)application:(UIApplication *)app didReceiveLocalNotification:(UILocalNotification *)notification {
    if (DEBUGAPP) NSLog(@"didReceiveLocalNotification %@", notification.alertBody);
    if (notification.userInfo) {
        if ([notification.userInfo[@"notify"] isEqualToString:@"friend"]) {
            [AlertView alert:@"Friend Notification" message:notification.alertBody dismissAfter:2.0];
        }
    }
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    if (DEBUGAPP) NSLog(@"performFetchWithCompletionHandler");

    self.completionHandler = completionHandler;
    if ([LocationManager sharedInstance].monitoring) {
        [self publishLocation:[LocationManager sharedInstance].location automatic:TRUE addon:@{@"t":@"p"}];
    } else {
        [self.connection connectToLast];
        [self startBackgroundTimer];
    }
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    if (DEBUGAPP) NSLog(@"didRegisterUserNotificationSettings %@", notificationSettings);
}

/*
 *
 * LocationManagerDelegate
 *
 */

- (void)newLocation:(CLLocation *)location {
    [self publishLocation:location automatic:YES addon:nil];
}

- (void)timerLocation:(CLLocation *)location {
    [self publishLocation:location automatic:YES addon:@{@"t": @"t"}];
}

- (void)regionEvent:(CLRegion *)region enter:(BOOL)enter {
    NSString *message = [NSString stringWithFormat:@"%@ %@", (enter ? @"Entering" : @"Leaving"), region.identifier];
    [self notification:message userInfo:nil];
    NSMutableDictionary *addon = [[NSMutableDictionary alloc] init];
    [addon setObject:enter ? @"enter" : @"leave" forKey:@"event" ];
    if ([region isKindOfClass:[CLCircularRegion class]]) {
        [addon setObject:@"c" forKey:@"t" ];
    } else {
        [addon setObject:@"b" forKey:@"t" ];
    }
    
    for (Location *location in [Location allWaypointsOfTopic:[self.settings theGeneralTopic]
                                      inManagedObjectContext:[CoreData theManagedObjectContext]]) {
        if ([region.identifier isEqualToString:location.region.identifier]) {
            location.remark = location.remark; // this touches the location and updates the overlay
            if ([location.share boolValue]) {
                [addon setValue:region.identifier forKey:@"desc"];
            }
        }
    }
    
    [self publishLocation:[LocationManager sharedInstance].location automatic:TRUE addon:addon];
}

- (void)regionState:(CLRegion *)region inside:(BOOL)inside {
    [self.delegate regionState:region inside:inside];
}

- (void)beaconInRange:(CLBeacon *)beacon {
    NSDictionary *jsonObject = @{
                                 @"_type": @"beacon",
                                 @"tst": @(floor([[LocationManager sharedInstance].location.timestamp timeIntervalSince1970])),
                                 @"uuid": [beacon.proximityUUID UUIDString],
                                 @"major": beacon.major,
                                 @"minor": beacon.minor,
                                 @"prox": @(beacon.proximity),
                                 @"acc": @(round(beacon.accuracy)),
                                 @"rssi": @(beacon.rssi)
                                 };
    [self.connection sendData:[self jsonToData:jsonObject]
                        topic:[[self.settings theGeneralTopic] stringByAppendingString:@"/beacons"]
                          qos:[self.settings intForKey:@"qos_preference"]
                       retain:NO];
    
    [self.delegate beaconInRange:beacon];
}

- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error {
    if (DEBUGAPP) NSLog(@"App rangingBeaconsDidFailForRegion %@ %@", region, error.localizedDescription);
}

#pragma ConnectionDelegate

- (void)showState:(NSInteger)state {
    self.connectionState = @(state);
    
    /**
     ** This is a hack to ensure the connection gets gracefully closed at the server
     **
     ** If the background task is ended, occasionally the disconnect message is not received well before the server senses the tcp disconnect
     **/
    
    if (state == state_closed) {
        if (self.backgroundTask) {
            if (DEBUGAPP) NSLog(@"endBackGroundTask");
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
            self.backgroundTask = UIBackgroundTaskInvalid;
        }
        if (self.completionHandler) {
            if (DEBUGAPP) NSLog(@"completionHandler");
            self.completionHandler(UIBackgroundFetchResultNewData);
            self.completionHandler = nil;
        }
    }
}

- (void)handleMessage:(NSData *)data onTopic:(NSString *)topic retained:(BOOL)retained {
    NSArray *topicComponents = [topic componentsSeparatedByCharactersInSet:
                                [NSCharacterSet characterSetWithCharactersInString:@"/"]];
    NSArray *baseComponents = [[self.settings theGeneralTopic] componentsSeparatedByCharactersInSet:
                               [NSCharacterSet characterSetWithCharactersInString:@"/"]];
    
    NSString *device = @"";
    BOOL ownDevice = true;
    
    for (int i = 0; i < [baseComponents count]; i++) {
        if (device.length) {
            device = [device stringByAppendingString:@"/"];
        }
        device = [device stringByAppendingString:topicComponents[i]];
        if (![baseComponents[i] isEqualToString:topicComponents [i]]) {
            ownDevice = false;
        }
    }
    
    if (ownDevice) {
        
        NSError *error;
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (dictionary) {
            if ([dictionary[@"_type"] isEqualToString:@"cmd"]) {
                if (DEBUGAPP) NSLog(@"App msg received cmd:%@", dictionary[@"action"]);
                if ([self.settings boolForKey:@"cmd_preference"]) {
                    if ([dictionary[@"action"] isEqualToString:@"dump"]) {
                        [self dumpTo:topic];
                    } else if ([dictionary[@"action"] isEqualToString:@"reportLocation"]) {
                        if ([LocationManager sharedInstance].monitoring || [self.settings boolForKey:@"allowremotelocation_preference"]) {
                            [self publishLocation:[LocationManager sharedInstance].location automatic:YES addon:@{@"t":@"r"}];
                        }
                    } else if ([dictionary[@"action"] isEqualToString:@"reportSteps"]) {
                        [self stepsFrom:dictionary[@"from"] to:dictionary[@"to"]];
                    } else {
                        if (DEBUGAPP) NSLog(@"unknown action %@", dictionary[@"action"]);
                    }
                }
            } else if ([dictionary[@"_type"] isEqualToString:@"waypoint"]) {
                // received own waypoint
            } else if ([dictionary[@"_type"] isEqualToString:@"beacon"]) {
                // received own beacon
            } else if ([dictionary[@"_type"] isEqualToString:@"location"]) {
                // received own beacon
            } else {
                if (DEBUGAPP) NSLog(@"unknown record type %@", dictionary[@"_type"]);
            }
        } else {
            if (DEBUGAPP) NSLog(@"illegal json %@", error.localizedDescription);
        }
        
    } else /* not ownDevice */ {
        
        if (data.length) {
            
            NSError *error;
            NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (dictionary) {
                if ([dictionary[@"_type"] isEqualToString:@"location"] ||
                    [dictionary[@"_type"] isEqualToString:@"waypoint"]) {
                    if (DEBUGAPP) NSLog(@"App json received lat:%@ lon:%@ acc:%@ tst:%@ alt:%@ vac:%@ cog:%@ vel:%@ tid:%@ rad:%@ event:%@ desc:%@",
                                        dictionary[@"lat"],
                                        dictionary[@"lon"],
                                        dictionary[@"acc"],
                                        dictionary[@"tst"],
                                        dictionary[@"alt"],
                                        dictionary[@"vac"],
                                        dictionary[@"cog"],
                                        dictionary[@"vel"],
                                        dictionary[@"tid"],
                                        dictionary[@"rad"],
                                        dictionary[@"event"],
                                        dictionary[@"desc"]
                                        );
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
                    
                    Location *newLocation = [Location locationWithTopic:device
                                                                    tid:dictionary[@"tid"]
                                                              timestamp:location.timestamp
                                                             coordinate:location.coordinate
                                                               accuracy:location.horizontalAccuracy
                                                               altitude:location.altitude
                                                       verticalaccuracy:location.verticalAccuracy
                                                                  speed:location.speed
                                                                 course:location.course                                                               automatic:[dictionary[@"_type"] isEqualToString:@"location"] ? TRUE : FALSE
                                                                 remark:dictionary[@"desc"]
                                                                 radius:[dictionary[@"rad"] doubleValue]
                                                                  share:NO
                                                 inManagedObjectContext:[CoreData theManagedObjectContext]];
                    
                    if (retained) {
                        if (DEBUGAPP) NSLog(@"App ignoring retained event");
                    } else {
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
                    }
                    
                    [self limitLocationsWith:newLocation.belongsTo toMaximum:MAX_OTHER_LOCATIONS];
                    
                } else {
                    if (DEBUGAPP) NSLog(@"unknown record type %@)", dictionary[@"_type"]);
                    // data other than json _type location/waypoint is silently ignored
                }
            } else {
                if (DEBUGAPP) NSLog(@"illegal json %@)", error.localizedDescription);
                // data other than json is silently ignored
            }
        } else /* data.length == 0 -> delete friend */ {
            Friend *friend = [Friend existsFriendWithTopic:device inManagedObjectContext:[CoreData theManagedObjectContext]];
            if (friend) {
                [[CoreData theManagedObjectContext] deleteObject:friend];
            }
        }
    }
    [self saveContext];
}

- (void)messageDelivered:(UInt16)msgID {
    if (DEBUGAPP) {
        NSString *message = [NSString stringWithFormat:@"Message delivered id=%u", msgID];
        [self notification:message userInfo:nil];
    }
}

- (void)totalBuffered:(NSUInteger)count {
    if (DEBUGAPP) NSLog(@"totalBuffered %lu", (unsigned long)count);
    self.connectionBuffered = @(count);

    [UIApplication sharedApplication].applicationIconBadgeNumber = count;
}

- (void)dumpTo:(NSString *)topic {
    NSDictionary *dumpDict = @{
                               @"_type":@"dump",
                               @"configuration":[self.settings toDictionary],
                               };
    
    [self.connection sendData:[self jsonToData:dumpDict]
                        topic:topic
                          qos:[self.settings intForKey:@"qos_preference"]
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
        if (DEBUGAPP)  {
            NSLog(@"isStepCountingAvailable %d", [CMPedometer isStepCountingAvailable]);
            NSLog(@"isFloorCountingAvailable %d", [CMPedometer isFloorCountingAvailable]);
            NSLog(@"isDistanceAvailable %d", [CMPedometer isDistanceAvailable]);
        }
        if (!self.pedometer) {
            self.pedometer = [[CMPedometer alloc] init];
        }
        [self.pedometer queryPedometerDataFromDate:fromDate
                                            toDate:toDate
                                       withHandler:^(CMPedometerData *pedometerData, NSError *error) {
                                           if (DEBUGAPP) NSLog(@"StepCounter queryPedometerDataFromDate handler %ld %ld %ld %ld %@",
                                                               [pedometerData.numberOfSteps longValue],
                                                               [pedometerData.floorsAscended longValue],
                                                               [pedometerData.floorsDescended longValue],
                                                               [pedometerData.distance longValue],
                                                               error.localizedDescription);
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               
                                               NSMutableDictionary *jsonObject = [[NSMutableDictionary alloc] init];
                                               [jsonObject addEntriesFromDictionary:@{
                                                                                      @"_type": @"steps",
                                                                                      @"tst": @(floor([[NSDate date] timeIntervalSince1970])),
                                                                                      @"from": @(floor([fromDate timeIntervalSince1970])),
                                                                                      @"to": @(floor([toDate timeIntervalSince1970])),
                                                                                      }];
                                               if (pedometerData) {
                                                   [jsonObject setObject:pedometerData.numberOfSteps forKey:@"steps"];
                                                   if (pedometerData.floorsAscended) {
                                                       [jsonObject setObject:pedometerData.floorsAscended forKey:@"floorsup"];
                                                   }
                                                   if (pedometerData.floorsDescended) {
                                                       [jsonObject setObject:pedometerData.floorsDescended forKey:@"floorsdown"];
                                                   }
                                                   if (pedometerData.distance) {
                                                       [jsonObject setObject:pedometerData.distance forKey:@"distance"];
                                                   }
                                               } else {
                                                   [jsonObject setObject:@(-1) forKey:@"steps"];
                                               }
                                               
                                               [self.connection sendData:[self jsonToData:jsonObject]
                                                                   topic:[[self.settings theGeneralTopic] stringByAppendingString:@"/steps"]
                                                                     qos:[self.settings intForKey:@"qos_preference"]
                                                                  retain:NO];
                                           });
                                       }];
        
    } else if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0"] != NSOrderedAscending) {
        if (DEBUGAPP) NSLog(@"isStepCountingAvailable %d", [CMStepCounter isStepCountingAvailable]);
        if (!self.stepCounter) {
            self.stepCounter = [[CMStepCounter alloc] init];
        }
        [self.stepCounter queryStepCountStartingFrom:fromDate
                                                  to:toDate
                                             toQueue:[[NSOperationQueue alloc] init]
                                         withHandler:^(NSInteger steps, NSError *error)
         {
             if (DEBUGAPP) NSLog(@"StepCounter queryStepCountStartingFrom handler %ld %@", (long)steps, error.localizedDescription);
             dispatch_async(dispatch_get_main_queue(), ^{
                 
                 NSDictionary *jsonObject = @{
                                              @"_type": @"steps",
                                              @"tst": @(floor([[NSDate date] timeIntervalSince1970])),
                                              @"from": @(floor([fromDate timeIntervalSince1970])),
                                              @"to": @(floor([toDate timeIntervalSince1970])),
                                              @"steps": error ? @(-1) : @(steps)
                                              };
                 
                 [self.connection sendData:[self jsonToData:jsonObject]
                                     topic:[[self.settings theGeneralTopic] stringByAppendingString:@"/steps"]
                                       qos:[self.settings intForKey:@"qos_preference"]
                                    retain:NO];
             });
         }];
    } else {
        NSDictionary *jsonObject = @{
                                     @"_type": @"steps",
                                     @"tst": @(floor([[NSDate date] timeIntervalSince1970])),
                                     @"from": @(floor([fromDate timeIntervalSince1970])),
                                     @"to": @(floor([toDate timeIntervalSince1970])),
                                     @"steps": @(-1)
                                     };
        
        [self.connection sendData:[self jsonToData:jsonObject]
                            topic:[[self.settings theGeneralTopic] stringByAppendingString:@"/steps"]
                              qos:[self.settings intForKey:@"qos_preference"]
                           retain:NO];
    }
}

#pragma actions

- (void)sendNow {
    if (DEBUGAPP) NSLog(@"App sendNow");
    [self publishLocation:[LocationManager sharedInstance].location automatic:FALSE addon:@{@"t":@"u"}];

}

- (void)connectionOff {
    NSLog(@"App connectionOff");
    [self.connection disconnect];
}

- (void)reconnect {
    if (DEBUGAPP) NSLog(@"App reconnect");
    [self.connection disconnect];
    [self connect];
}

- (void)publishLocation:(CLLocation *)location automatic:(BOOL)automatic addon:(NSDictionary *)addon {
    Location *newLocation = [Location locationWithTopic:[self.settings theGeneralTopic]
                                                    tid:[self.settings stringForKey:@"trackerid_preference"]
                                              timestamp:location.timestamp
                                             coordinate:location.coordinate
                                               accuracy:location.horizontalAccuracy
                                               altitude:location.altitude
                                       verticalaccuracy:location.verticalAccuracy
                                                  speed:(location.speed == -1) ? -1 : location.speed * 3600.0 / 1000.0
                                                 course:location.course
                                              automatic:automatic
                                                 remark:nil
                                                 radius:0
                                                  share:NO
                                 inManagedObjectContext:[CoreData theManagedObjectContext]];
    
    NSData *data = [self encodeLocationData:newLocation type:@"location" addon:addon];
    
    [self.connection sendData:data
                        topic:[self.settings theGeneralTopic]
                          qos:[self.settings intForKey:@"qos_preference"]
                       retain:[self.settings boolForKey:@"retain_preference"]];
    
    [self limitLocationsWith:newLocation.belongsTo toMaximum:[self.settings intForKey:@"positions_preference"]];
    [self startBackgroundTimer];
    [self saveContext];
}

- (void)startBackgroundTimer {
    /**
     *   In background, set timer to disconnect after BACKGROUND_DISCONNECT_AFTER sec. IOS will suspend app after 10 sec.
     **/
    
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        if (self.disconnectTimer && self.disconnectTimer.isValid) {
            if (DEBUGAPP) NSLog(@"App timer still running %@", self.disconnectTimer.fireDate);
        } else {
            self.disconnectTimer = [NSTimer timerWithTimeInterval:BACKGROUND_DISCONNECT_AFTER
                                                           target:self
                                                         selector:@selector(disconnectInBackground)
                                                         userInfo:Nil repeats:FALSE];
            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            [runLoop addTimer:self.disconnectTimer
                      forMode:NSDefaultRunLoopMode];
            if (DEBUGAPP) NSLog(@"App timerWithTimeInterval %@", self.disconnectTimer.fireDate);
        }
    }
}

- (void)sendEmpty:(Friend *)friend {
    [self.connection sendData:nil
                        topic:friend.topic
                          qos:[self.settings intForKey:@"qos_preference"]
                       retain:YES];
}

- (void)requestLocationFromFriend:(Friend *)friend {
    NSDictionary *jsonObject = @{
                                 @"_type": @"cmd",
                                 @"action": @"reportLocation"
                                 };
    
    [self.connection sendData:[self jsonToData:jsonObject]
                        topic:[friend.topic stringByAppendingString:@"/steps"]
                          qos:[self.settings intForKey:@"qos_preference"]
                       retain:NO];
}

- (void)sendWayPoint:(Location *)location {
    NSMutableDictionary *addon = [[NSMutableDictionary alloc]init];
    
    if (location.remark) {
        [addon setValue:location.remark forKey:@"desc"];
    }
    
    NSData *data = [self encodeLocationData:location
                                       type:@"waypoint" addon:addon];
    
    [self.connection sendData:data
                        topic:[[self.settings theGeneralTopic] stringByAppendingString:@"/waypoints"]
                          qos:[self.settings intForKey:@"qos_preference"]
                       retain:NO];
    
    [self saveContext];
}

- (void)limitLocationsWith:(Friend *)friend toMaximum:(NSInteger)max {
    NSArray *allLocations = [Location allAutomaticLocationsWithFriend:friend
                                               inManagedObjectContext:[CoreData theManagedObjectContext]];
    
    for (NSInteger i = [allLocations count]; i > max; i--) {
        Location *location = allLocations[i - 1];
        [[CoreData theManagedObjectContext] deleteObject:location];
    }
}

#pragma internal helpers

- (void)notification:(NSString *)message userInfo:(NSDictionary *)userInfo {
   if (DEBUGAPP)  NSLog(@"App notification %@ userinfo %@", message, userInfo);
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = message;
    notification.alertLaunchImage = @"itunesArtwork.png";
    notification.userInfo = userInfo;
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];

}

- (void)notification:(NSString *)message after:(NSTimeInterval)after userInfo:(NSDictionary *)userInfo {
    if (DEBUGAPP) NSLog(@"App notification %@ userinfo %@ after %f", message, userInfo, after);
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = message;
    notification.alertLaunchImage = @"itunesArtwork.png";
    notification.userInfo = userInfo;
    notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:after];
    [[UIApplication sharedApplication] scheduleLocalNotification:notification];
}

- (void)connect {
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

- (void)disconnectInBackground {
    if (DEBUGAPP) NSLog(@"App disconnectInBackground %ld",
                        (long)[UIApplication sharedApplication].applicationIconBadgeNumber);
    [[LocationManager sharedInstance] sleep];
    self.disconnectTimer = nil;
    [self.connection disconnect];
}

- (NSData *)jsonToData:(NSDictionary *)jsonObject {
    NSData *data;
    
    if ([NSJSONSerialization isValidJSONObject:jsonObject]) {
        NSError *error;
        data = [NSJSONSerialization dataWithJSONObject:jsonObject options:0 /* not pretty printed */ error:&error];
        if (!data) {
            NSString *message = [NSString stringWithFormat:@"%@ %@", error.localizedDescription, [jsonObject description]];
            [AlertView alert:@"dataWithJSONObject" message:message];
        }
    } else {
        NSString *message = [NSString stringWithFormat:@"%@", [jsonObject description]];
        [AlertView alert:@"isValidJSONObject" message:message];
    }
    return data;
}


- (NSData *)encodeLocationData:(Location *)location type:(NSString *)type addon:(NSDictionary *)addon {
    NSMutableDictionary *jsonObject = [[NSMutableDictionary alloc] init];
    [jsonObject setValue:[NSString stringWithFormat:@"%@", type] forKey:@"_type"];
    
#ifdef OLD
    [jsonObject setValue:[NSString stringWithFormat:@"%g", location.coordinate.latitude] forKey:@"lat"];
    [jsonObject setValue:[NSString stringWithFormat:@"%g", location.coordinate.longitude] forKey:@"lon"];
    [jsonObject setValue:[NSString stringWithFormat:@"%.0f", [location.timestamp timeIntervalSince1970]] forKey:@"tst"];
#else
    [jsonObject setValue:@(location.coordinate.latitude) forKey:@"lat"];
    [jsonObject setValue:@(location.coordinate.longitude) forKey:@"lon"];
    [jsonObject setValue:@((int)[location.timestamp timeIntervalSince1970]) forKey:@"tst"];
#endif
    
    double acc = [location.accuracy doubleValue];
    if (acc > 0) {
#ifdef OLD
        [jsonObject setValue:[NSString stringWithFormat:@"%.0f", acc] forKey:@"acc"];
#else
        [jsonObject setValue:@(acc) forKey:@"acc"];
#endif
    }
    
    if ([self.settings boolForKey:@"extendeddata_preference"]) {
        int alt = [location.altitude intValue];
        [jsonObject setValue:@(alt) forKey:@"alt"];
        
        int vac = [location.verticalaccuracy intValue];
        [jsonObject setValue:@(vac) forKey:@"vac"];
        
        int vel = [location.speed intValue];
        [jsonObject setValue:@(vel) forKey:@"vel"];
        
        int cog = [location.course intValue];
        [jsonObject setValue:@(cog) forKey:@"cog"];
    }
    
    [jsonObject setValue:[location.belongsTo getEffectiveTid] forKeyPath:@"tid"];
    
    double rad = [location.regionradius doubleValue];
    if (rad > 0) {
#ifdef OLD
        [jsonObject setValue:[NSString stringWithFormat:@"%.0f", rad] forKey:@"rad"];
#else
        [jsonObject setValue:@((int)rad) forKey:@"rad"];
#endif
    }
    
    if (addon) {
        [jsonObject addEntriesFromDictionary:addon];
    }
    
    if ([type isEqualToString:@"location"]) {
        int batteryLevel = [UIDevice currentDevice].batteryLevel != -1 ? [UIDevice currentDevice].batteryLevel * 100 : -1;
#ifdef OLD
        [jsonObject setValue:[NSString stringWithFormat:@"%d", batteryLevel] forKey:@"batt"];
#else
        [jsonObject setValue:@(batteryLevel) forKey:@"batt"];
#endif
    }
    
    return [self jsonToData:jsonObject];
}

@end
