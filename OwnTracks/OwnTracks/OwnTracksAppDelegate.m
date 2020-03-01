//
//  OwnTracksAppDelegate.m
//  OwnTracks
//
//  Created by Christoph Krey on 03.02.14.
//  Copyright © 2014 -2019 OwnTracks. All rights reserved.
//

#import "OwnTracksAppDelegate.h"
#import "CoreData.h"
#import "Setting+CoreDataClass.h"
#import "History+CoreDataClass.h"
#import "Settings.h"
#import "OwnTracking.h"
#import "ConnType.h"
#import <UserNotifications/UserNotifications.h>
#import <BackgroundTasks/BackgroundTasks.h>

#import <CocoaLumberjack/CocoaLumberjack.h>
static const DDLogLevel ddLogLevel = DDLogLevelInfo;

@interface NSString (safe)
- (BOOL)saveEqual:(NSString *)aString;
+ (NSString *)saveCopy:(NSString *)aString;
@end

@implementation NSString (safe)

- (BOOL)saveEqual:(NSString *)aString {
    if (aString) {
        if ([aString isKindOfClass:[NSString class]]) {
            return [self isEqualToString:aString];
        }
    }
    return false;
}

+ (NSString *)saveCopy:(NSString *)aString {
    if (aString) {
        if ([aString isKindOfClass:[NSString class]]) {
            return aString;
        }
    }
    return nil;
}

@end

@interface NSNumber (safe)
+ (NSNumber *)saveCopy:(NSNumber *)aNumber;
@end

@implementation NSNumber (safe)

+ (NSNumber *)saveCopy:(NSNumber *)aNumber {
    if (aNumber) {
        if ([aNumber isKindOfClass:[NSNumber class]]) {
            return aNumber;
        }
    }
    return nil;
}

@end@interface NSDictionary (safe)
+ (NSDictionary *)saveCopy:(NSDictionary *)aDictionary;
@end

@implementation NSDictionary (safe)

+ (NSDictionary *)saveCopy:(NSDictionary *)aDictionary {
    if (aDictionary) {
        if ([aDictionary isKindOfClass:[NSDictionary class]]) {
            return aDictionary;
        }
    }
    return nil;
}

@end

@interface OwnTracksAppDelegate()

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@property (strong, nonatomic) NSString *backgroundFetchCheckMessage;

@property (strong, nonatomic) BGTaskScheduler *bgTaskScheduler;
@property (strong, nonatomic) BGTask *bgTask;

@property (strong, nonatomic) CoreData *coreData;
@property (strong, nonatomic) CMPedometer *pedometer;
@property (strong, nonatomic) NSUserActivity *userActivity;

#define BACKGROUND_DISCONNECT_AFTER 15.0
#define BACKGROUND_HOLD_FOR 3.0
@property (strong, nonatomic) NSTimer *disconnectTimer;
@property (strong, nonatomic) NSTimer *holdTimer;
@property (strong, nonatomic) NSTimer *bgTimer;

@end

@implementation OwnTracksAppDelegate

#pragma ApplicationDelegate

- (void)buildMenuWithBuilder:(id<UIMenuBuilder>)builder  API_AVAILABLE(ios(13.0)){
    [builder removeMenuForIdentifier:UIMenuHelp];
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
#ifdef DEBUG
    [DDLog addLogger:[DDTTYLogger sharedInstance] withLevel:DDLogLevelVerbose];
#endif
    [DDLog addLogger:[DDOSLogger sharedInstance] withLevel:DDLogLevelWarning];

    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];

#define TASK_IDENTIFIER @"updateSituation"
    self.bgTaskScheduler = [BGTaskScheduler sharedScheduler];
    BOOL success = [self.bgTaskScheduler
                    registerForTaskWithIdentifier:TASK_IDENTIFIER
                    usingQueue:nil
                    launchHandler:^(__kindof BGTask * _Nonnull task) {
        DDLogVerbose(@"[OwnTracksAppDelegate] launchHandler %@",
                     task.identifier);
        task.expirationHandler = ^{
            DDLogVerbose(@"[OwnTracksAppDelegate] bgTaskEspirationHandler");
            if (self.bgTask) {
                [self.bgTask setTaskCompletedWithSuccess:FALSE];
                self.bgTask = nil;
            }
            [self performSelectorOnMainThread:@selector(doRefresh)
                                   withObject:nil
                                waitUntilDone:TRUE];
        };
        self.bgTask = task;
    }];
    DDLogVerbose(@"[OwnTracksAppDelegate] registerForTaskWithIdentifier %@ %d",
                 TASK_IDENTIFIER, success);

    NSError *error;
    BGAppRefreshTaskRequest *bgAppRefreshTaskRequest =
    [[BGAppRefreshTaskRequest alloc] initWithIdentifier:TASK_IDENTIFIER];
    success = [self.bgTaskScheduler submitTaskRequest:bgAppRefreshTaskRequest error:&error];
    DDLogVerbose(@"[OwnTracksAppDelegate] submitTaskRequest %@ @ %@ %d, %@",
                 bgAppRefreshTaskRequest.identifier,
                 bgAppRefreshTaskRequest.earliestBeginDate,
                 success,
                 error);

    DDLogVerbose(@"[OwnTracksAppDelegate] getPendingTaskRequestsWithCompletionHandler:");
    [self.bgTaskScheduler getPendingTaskRequestsWithCompletionHandler:^(NSArray<BGTaskRequest *> * _Nonnull taskRequests) {
        for (BGTaskRequest *bgTaskRequest in taskRequests) {
        DDLogVerbose(@"[OwnTracksAppDelegate] getPendingTaskRequestsWithCompletionHandler %@ @ %@",
                     bgTaskRequest.identifier,
                     bgTaskRequest.earliestBeginDate);
        }
    }];

    self.backgroundTask = UIBackgroundTaskInvalid;

    UIBackgroundRefreshStatus status = [UIApplication sharedApplication].backgroundRefreshStatus;
    switch (status) {
        case UIBackgroundRefreshStatusAvailable:
            DDLogVerbose(@"[OwnTracksAppDelegate] UIBackgroundRefreshStatusAvailable");
            break;
        case UIBackgroundRefreshStatusDenied:
            DDLogWarn(@"[OwnTracksAppDelegate] UIBackgroundRefreshStatusDenied");
#if !TARGET_OS_MACCATALYST
            self.backgroundFetchCheckMessage = NSLocalizedString(@"You did disable background fetch",
                                                                 @"You did disable background fetch");
#endif
            break;
        case UIBackgroundRefreshStatusRestricted:
            DDLogWarn(@"[OwnTracksAppDelegate] UIBackgroundRefreshStatusRestricted");
            self.backgroundFetchCheckMessage = NSLocalizedString(@"You cannot use background fetch",
                                                                 @"You cannot use background fetch");
            break;
    }

    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNAuthorizationOptions options =
        UNAuthorizationOptionSound |
        UNAuthorizationOptionAlert |
        UNAuthorizationOptionBadge;
    [center requestAuthorizationWithOptions:options
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
                              DDLogVerbose(@"[OwnTracksAppDelegate] requestAuthorizationWithOptions granted:%d error:%@", granted, error);
                          }];
    center.delegate = self;
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    DDLogVerbose(@"[OwnTracksAppDelegate] didFinishLaunchingWithOptions");

    self.connection = [[Connection alloc] init];
    self.connection.delegate = self;
    [self.connection start];

    [self connect];

    [[UIDevice currentDevice] setBatteryMonitoringEnabled:TRUE];

    self.userActivity = [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
    self.userActivity.title = @"Configuration via Browser";
    self.userActivity.eligibleForHandoff = TRUE;
    self.userActivity.delegate = self;
    [self.userActivity becomeCurrent];

    LocationManager *locationManager = [LocationManager sharedInstance];
    locationManager.delegate = self;
    locationManager.monitoring = [Settings intForKey:@"monitoring_preference"
                                               inMOC:CoreData.sharedInstance.mainMOC];
    locationManager.ranging = [Settings boolForKey:@"ranging_preference"
                                             inMOC:CoreData.sharedInstance.mainMOC];
    locationManager.minDist = [Settings doubleForKey:@"mindist_preference"
                                               inMOC:CoreData.sharedInstance.mainMOC];
    locationManager.minTime = [Settings doubleForKey:@"mintime_preference"
                                               inMOC:CoreData.sharedInstance.mainMOC];
    [locationManager start];

    return YES;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    DDLogVerbose(@"[OwnTracksAppDelegate] willPresentNotification");
    completionHandler(UNNotificationPresentationOptionAlert);
}

- (void)applicationWillResignActive:(UIApplication *)application {
    DDLogVerbose(@"[OwnTracksAppDelegate] applicationWillResignActive");
//    #if !TARGET_OS_MACCATALYST
//            if ([LocationManager sharedInstance].monitoring != LocationMonitoringMove) {
//                [self.connection disconnect];
//            }
//    #else
//            [self.connection disconnect];
//    #endif
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    DDLogVerbose(@"[OwnTracksAppDelegate] applicationDidEnterBackground");
#if !TARGET_OS_MACCATALYST
    [self background];
    #if !TARGET_OS_MACCATALYST
            if ([LocationManager sharedInstance].monitoring != LocationMonitoringMove) {
                [self.connection disconnect];
            }
    #else
            [self.connection disconnect];
    #endif
#endif
}

- (void)applicationWillTerminate:(UIApplication *)application {
    DDLogVerbose(@"[OwnTracksAppDelegate] applicationWillTerminate");
    [self background];
    [self.connection disconnect];

}

-(BOOL)application:(UIApplication *)app
           openURL:(NSURL *)url
           options:(NSDictionary<NSString *,id> *)options {
    DDLogVerbose(@"[OwnTracksAppDelegate] openURL %@ options %@", url, options);

    if (url) {
        DDLogVerbose(@"[OwnTracksAppDelegate] URL scheme %@", url.scheme);

        if ([url.scheme isEqualToString:@"owntracks"]) {
            DDLogVerbose(@"[OwnTracksAppDelegate] URL path %@ query %@", url.path, url.query);

            NSMutableDictionary *queryStrings = [[NSMutableDictionary alloc] init];
            for (NSString *parameter in [url.query componentsSeparatedByString:@"&"]) {
                NSArray *pair = [parameter componentsSeparatedByString:@"="];
                if (pair.count == 2) {
                    NSString *key = pair[0];
                    NSString *value = pair[1];
                    value = [value stringByReplacingOccurrencesOfString:@"+" withString:@" "];
                    value = [value stringByRemovingPercentEncoding];
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
                                                                     @"tst":@((int)([NSDate date].timeIntervalSince1970)),
                                                                     @"lat":@([LocationManager sharedInstance].location.coordinate.latitude),
                                                                     @"lon":@([LocationManager sharedInstance].location.coordinate.longitude),
                                                                     @"rad":@(-1)
                                                                     }]
                                                    } inMOC:CoreData.sharedInstance.mainMOC];
                [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
                self.processingMessage = NSLocalizedString(@"Beacon QR successfully processed",
                                                           @"Display after processing beacon QR code");
                return TRUE;
            } else if ([url.path isEqualToString:@"/config"]) {
                NSString *urlString = queryStrings[@"url"];
                NSURL *urlFromString = [NSURL URLWithString:urlString];
                return [self processNSURL:urlFromString];
            } else {
                return FALSE;
            }
        } else if ([url.scheme isEqualToString:@"file"]) {
            return [self processFile:url];
        } else if ([url.scheme isEqualToString:@"http"] ||
                   [url.scheme isEqualToString:@"https"]) {
            return [self processNSURL:url];
        } else {
            self.processingMessage = [NSString stringWithFormat:@"%@ %@",
                                      NSLocalizedString(@"unknown scheme in url",
                                                        @"Display after entering an unknown scheme in url"),
                                      url.scheme];
            return FALSE;
        }
    }
    self.processingMessage = NSLocalizedString(@"no url specified",
                                               @"Display after trying to process a file");
    return FALSE;
}

- (BOOL)processNSURL:(NSURL *)url {
    self.processingMessage = nil;
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSessionDataTask *dataTask =
    [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:
     ^(NSData *data, NSURLResponse *response, NSError *error) {

         DDLogVerbose(@"[OwnTracksAppDelegate] dataTaskWithRequest %@ %@ %@", data, response, error);
         if (!error) {

             if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                 NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                 DDLogVerbose(@"[OwnTracksAppDelegate] NSHTTPURLResponse %@", httpResponse);
                 if (httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299) {
                     NSError *error;
                     NSString *extension = url.pathExtension;
                     if ([extension isEqualToString:@"otrc"] || [extension isEqualToString:@"mqtc"]) {
                         [self performSelectorOnMainThread:@selector(terminateSession)
                                                withObject:nil
                                             waitUntilDone:TRUE];
                         NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                                              options:0
                                                                                error:nil];
                         [self performSelectorOnMainThread:@selector(configFromDictionary:)
                                                withObject:json
                                             waitUntilDone:TRUE];
                         self.configLoad = [NSDate date];
                     } else if ([extension isEqualToString:@"otrw"] || [extension isEqualToString:@"mqtw"]) {
                         NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                                              options:0
                                                                                error:nil];


                         [self performSelectorOnMainThread:@selector(waypointsFromDictionary:)
                                                withObject:json
                                             waitUntilDone:TRUE];
                     } else if ([extension isEqualToString:@"otrp"] || [extension isEqualToString:@"otre"]) {
                         NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                                      inDomain:NSUserDomainMask
                                                                             appropriateForURL:nil
                                                                                        create:YES
                                                                                         error:&error];
                         NSString *fileName = url.lastPathComponent;
                         NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];
                         [[NSFileManager defaultManager] createFileAtPath:fileURL.path
                                                                 contents:data
                                                               attributes:nil];
                     } else {
                         [self.navigationController alert:@"processNSURL"
                                                  message:[NSString stringWithFormat:@"OOPS %@ %@",
                                                           [NSError errorWithDomain:@"OwnTracks"
                                                                               code:2
                                                                           userInfo:@{@"extension":extension ? extension : @"(null)"}],
                                                           url]];
                     }
                 } else {
                     [self.navigationController alert:@"processNSURL"
                                              message:[NSString stringWithFormat:@"httpResponse.statusCode %ld %@",
                                                       (long)httpResponse.statusCode,
                                                       url]];
                 }
             } else {
                 [self.navigationController alert:@"processNSURL"
                                          message:[NSString stringWithFormat:@"response %@ %@",
                                                   response,
                                                   url]];
             }
         } else {
             [self.navigationController alert:@"processNSURL"
                                      message:[NSString stringWithFormat:@"dataTaskWithRequest %@ %@",
                                               error,
                                               url]];
         }
     }];
    [dataTask resume];
    return TRUE;
}

- (void)configFromDictionary:(NSDictionary *)json {
    NSError *error = [Settings fromDictionary:json inMOC:CoreData.sharedInstance.mainMOC];
    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
    if (error) {
        [self.navigationController alert:@"processNSURL"
                                 message:[NSString stringWithFormat:@"configFromDictionary %@ %@",
                                          error,
                                          json]];
    }
}

- (void)waypointsFromDictionary:(NSDictionary *)json {
    NSError *error = [Settings waypointsFromDictionary:json inMOC:CoreData.sharedInstance.mainMOC];
    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
    if (error) {
        [self.navigationController alert:@"processNSURL"
                                 message:[NSString stringWithFormat:@"waypointsFromDictionary %@ %@",
                                          error,
                                          json]];
    }
}

- (BOOL)processFile:(NSURL *)url {
    NSInputStream *input = [NSInputStream inputStreamWithURL:url];
    if (input.streamError) {
        self.processingMessage = [NSString stringWithFormat:@"inputStreamWithURL %@ %@",
                                  input.streamError,
                                  url];
        return FALSE;
    }
    [input open];
    if (input.streamError) {
        self.processingMessage = [NSString stringWithFormat:@"%@ %@ %@",
                                  NSLocalizedString(@"file open error",
                                                    @"Display after trying to open a file"),
                                  input.streamError,
                                  url];
        return FALSE;
    }

    DDLogVerbose(@"[OwnTracksAppDelegate] URL pathExtension %@", url.pathExtension);

    NSError *error;
    NSString *extension = url.pathExtension;
    if ([extension isEqualToString:@"otrc"] || [extension isEqualToString:@"mqtc"]) {
        [self terminateSession];
        error = [Settings fromStream:input inMOC:CoreData.sharedInstance.mainMOC];
        [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
        self.configLoad = [NSDate date];
    } else if ([extension isEqualToString:@"otrw"] || [extension isEqualToString:@"mqtw"]) {
        error = [Settings waypointsFromStream:input inMOC:CoreData.sharedInstance.mainMOC];
        [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
    } else if ([extension isEqualToString:@"otrp"] || [extension isEqualToString:@"otre"]) {
        NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                     inDomain:NSUserDomainMask
                                                            appropriateForURL:nil
                                                                       create:YES
                                                                        error:&error];
        NSString *fileName = url.lastPathComponent;
        NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];
        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
        [[NSFileManager defaultManager] copyItemAtURL:url toURL:fileURL error:nil];
    } else {
        error = [NSError errorWithDomain:@"OwnTracks"
                                    code:2
                                userInfo:@{@"extension":extension ? extension : @"(null)"}];
    }

    [input close];

// MAC CATALYST opens files in place
#if !TARGET_OS_MACCATALYST
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
#endif

    if (error) {
        self.processingMessage = [NSString stringWithFormat:@"%@ %@: %@ %@",
                                  NSLocalizedString(@"Error processing file",
                                                    @"Display when file processing fails"),
                                  url.lastPathComponent,
                                  error.localizedDescription,
                                  error.userInfo];
        return FALSE;
    }
    self.processingMessage = [NSString stringWithFormat:@"%@ %@ %@",
                              NSLocalizedString(@"File",
                                                @"Display when file processing succeeds (filename follows)"),
                              url.lastPathComponent,
                              NSLocalizedString(@"successfully processed",
                                                @"Display when file processing succeeds")
                              ];
    return TRUE;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    DDLogVerbose(@"[OwnTracksAppDelegate] applicationDidBecomeActive");

    [self.connection connectToLast];
    
    if (self.disconnectTimer && self.disconnectTimer.isValid) {
        DDLogVerbose(@"[OwnTracksAppDelegate] disconnectTimer invalidate %@",
                     self.disconnectTimer.fireDate);
        [self.disconnectTimer invalidate];
    }

    if (self.backgroundFetchCheckMessage) {
        [self.navigationController alert:@"Background Fetch" message:self.backgroundFetchCheckMessage];
        self.backgroundFetchCheckMessage = nil;
    }

    if (self.processingMessage) {
        [self.navigationController alert:@"openURL" message:self.processingMessage];
        self.processingMessage = nil;
        [self reconnect];
    }

    if (![Settings validIdsInMOC:CoreData.sharedInstance.mainMOC]) {
        NSString *message = NSLocalizedString(@"To publish your location userID and deviceID must be set",
                                              @"Warning displayed if necessary settings are missing");

        [self.navigationController alert:@"Settings" message:message];
    }
}

- (void)doRefresh {
    [self background];

    [[LocationManager sharedInstance] wakeup];
    [self.connection connectToLast];

    if ([LocationManager sharedInstance].monitoring == LocationMonitoringSignificant ||
        [LocationManager sharedInstance].monitoring == LocationMonitoringMove) {
        CLLocation *lastLocation = [LocationManager sharedInstance].location;
        CLLocation *location = [[CLLocation alloc] initWithCoordinate:lastLocation.coordinate
                                                             altitude:lastLocation.altitude
                                                   horizontalAccuracy:lastLocation.horizontalAccuracy
                                                     verticalAccuracy:lastLocation.verticalAccuracy
                                                               course:lastLocation.course
                                                                speed:lastLocation.speed
                                                            timestamp:[NSDate date]];
        [self publishLocation:location trigger:@"p"];
    }
}

- (void)background {
    [self startBackgroundTimer];
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground &&
        self.backgroundTask == UIBackgroundTaskInvalid) {
        self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            DDLogVerbose(@"[OwnTracksAppDelegate] BackgroundTaskExpirationHandler");
            if (self.backgroundTask) {
                [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
                self.backgroundTask = UIBackgroundTaskInvalid;
            }
        }];
        DDLogVerbose(@"[OwnTracksAppDelegate] beginBackgroundTaskWithExpirationHandler %lu",
                     (unsigned long)self.backgroundTask);
    }
}

- (void)startBackgroundTimer {
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground &&
        [LocationManager sharedInstance].monitoring != LocationMonitoringMove) {
        if (self.disconnectTimer && self.disconnectTimer.isValid) {
            DDLogVerbose(@"[OwnTracksAppDelegate] disconnectTimer.isValid %@",
                         self.disconnectTimer.fireDate);
        } else {
            self.disconnectTimer = [NSTimer timerWithTimeInterval:BACKGROUND_DISCONNECT_AFTER
                                                           target:self
                                                         selector:@selector(disconnectInBackground)
                                                         userInfo:Nil
                                                          repeats:FALSE];
            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            [runLoop addTimer:self.disconnectTimer forMode:NSDefaultRunLoopMode];
            DDLogVerbose(@"[OwnTracksAppDelegate] disconnectTimer %@",
                         self.disconnectTimer.fireDate);

            if (self.holdTimer) {
                if (self.holdTimer.isValid) {
                    [self.holdTimer invalidate];
                }
                self.holdTimer = nil;
            }
            self.holdTimer = [NSTimer scheduledTimerWithTimeInterval:BACKGROUND_HOLD_FOR
                                                             repeats:FALSE
                                                               block:^(NSTimer * _Nonnull timer) {
                DDLogVerbose(@"[OwnTracksAppDelegate] holdTimer");
                if (self.bgTimer) {
                    if (self.bgTimer.isValid) {
                        [self.bgTimer invalidate];
                    }
                    self.bgTimer = nil;
                }
                self.bgTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                               repeats:TRUE block:^(NSTimer * _Nonnull timer) {
                    DDLogVerbose(@"[OwnTracksAppDelegate] bgTimer %@ %@",
                                 self.connectionState,
                                 self.connectionBuffered);
                    if (!self.connectionBuffered || !self.connectionBuffered.intValue) {
                        if (self.connectionState.intValue == state_connected) {
                            [self disconnectInBackground];
                        }
                    }
                }];
            }];
        }
    }
}

- (void)disconnectInBackground {
    DDLogVerbose(@"[OwnTracksAppDelegate] disconnectInBackground");
    [self.connection disconnect];
}

/*
 *
 * LocationManagerDelegate
 *
 */

- (void)newLocation:(CLLocation *)location {
    [self background];
    [self publishLocation:location trigger:nil];
}

- (void)timerLocation:(CLLocation *)location {
    [self background];
    [self publishLocation:location trigger:@"t"];
}

- (void)visitLocation:(CLLocation *)location {
    [self background];
    [self publishLocation:location trigger:@"v"];
}

- (void)regionEvent:(CLRegion *)region enter:(BOOL)enter {
    [self background];
    if ([LocationManager sharedInstance].monitoring != LocationMonitoringQuiet &&
        [Settings validIdsInMOC:CoreData.sharedInstance.mainMOC]) {

        if (![region.identifier hasPrefix:@"+"]) {
            NSString *notificationMessage = [NSString stringWithFormat:@"%@ %@",
                                             (enter ?
                                              NSLocalizedString(@"Entering",
                                                                @"Display when entering region (region name follows)"):
                                              NSLocalizedString(@"Leaving",
                                                                @"Display when leaving region (region name follows)")
                                              ),
                                             region.identifier];

            UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
            content.body = notificationMessage;
            UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger
                                                          triggerWithTimeInterval:1.0
                                                          repeats:NO];
            NSString *notificationIdentifier = [NSString stringWithFormat:@"region%f",
                                                [NSDate date].timeIntervalSince1970];

            UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:notificationIdentifier
                                                                                  content:content
                                                                                  trigger:trigger];
            UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
            [center addNotificationRequest:request withCompletionHandler:nil];

            [History historyInGroup:@"Region"
                           withText:notificationMessage
                                 at:nil
                              inMOC:[CoreData sharedInstance].mainMOC
                            maximum:[Settings theMaximumHistoryInMOC:[CoreData sharedInstance].mainMOC]];
            [CoreData.sharedInstance sync:CoreData.sharedInstance.queuedMOC];

            Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC]
                                inManagedObjectContext:CoreData.sharedInstance.mainMOC];

            CLLocation *location = [LocationManager sharedInstance].location;

            NSMutableDictionary *json = [@{
                                           @"_type": @"transition",
                                           @"lat": @(location.coordinate.latitude),
                                           @"lon": @(location.coordinate.longitude),
                                           @"tst": @(floor((location.timestamp).timeIntervalSince1970)),
                                           @"acc": @(location.horizontalAccuracy),
                                           @"tid": myself.effectiveTid,
                                           @"event": enter ? @"enter" : @"leave",
                                           @"t": [region isKindOfClass:[CLBeaconRegion class]] ? @"b" : @"c"
                                           } mutableCopy];

            for (Region *anyRegion in myself.hasRegions) {
                if ([region.identifier isEqualToString:anyRegion.CLregion.identifier]) {
                    anyRegion.name = anyRegion.name;
                    [json setValue:region.identifier forKey:@"desc"];
                    [json setValue:@(floor(anyRegion.andFillTst.timeIntervalSince1970)) forKey:@"wtst"];

                    [self.connection sendData:[self jsonToData:json]
                                        topic:[[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] stringByAppendingString:@"/event"]
                                   topicAlias:@(2)
                                          qos:[Settings intForKey:@"qos_preference"
                                                            inMOC:CoreData.sharedInstance.mainMOC]
                                       retain:NO];
                    if ([region isKindOfClass:[CLBeaconRegion class]]) {
                        if ((anyRegion.radius).doubleValue < 0) {
                            anyRegion.lat = @(location.coordinate.latitude);
                            anyRegion.lon = @(location.coordinate.longitude);
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
        } else {
            [self publishLocation:[LocationManager sharedInstance].location trigger:@"C"];
        }
    }
}

- (void)regionState:(CLRegion *)region inside:(BOOL)inside {
    DDLogVerbose(@"[OwnTracksAppDelegate] regionState %@ i:%d", region.identifier, inside);
    Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC]
                            inManagedObjectContext:CoreData.sharedInstance.mainMOC];

    for (Region *anyRegion in myself.hasRegions) {
        if ([region.identifier isEqualToString:anyRegion.CLregion.identifier]) {
            anyRegion.name = anyRegion.name;
        }
    }
}

-(void)beaconInRange:(CLBeacon *)beacon
    beaconConstraint:(CLBeaconIdentityConstraint *)beaconConstraint {
    [self background];
    if ([Settings validIdsInMOC:CoreData.sharedInstance.mainMOC]) {
        Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC]
                                inManagedObjectContext:CoreData.sharedInstance.mainMOC];

        Region *myRegion;
        for (Region *anyRegion in myself.hasRegions) {
            if ([beaconConstraint.UUID.UUIDString isEqualToString:anyRegion.uuid]) {
                if ((!anyRegion.major &&
                     !beaconConstraint.major
                     ) ||
                    (anyRegion.major &&
                     beaconConstraint.major &&
                     anyRegion.major.intValue == beaconConstraint.major.intValue &&
                     ((!anyRegion.minor &&
                       !beaconConstraint.minor
                       ) ||
                      (anyRegion.minor &&
                       beaconConstraint.minor &&
                       anyRegion.minor.intValue == beaconConstraint.minor.intValue
                       )
                      )
                     )
                    ) {
                    myRegion = anyRegion;
                    break;
                }
            }
        }

        NSMutableDictionary *json = [NSMutableDictionary dictionaryWithDictionary:
                                     @{
                                       @"_type": @"beacon",
                                       @"tid": myself.effectiveTid,
                                       @"tst": @(floor(([LocationManager sharedInstance].location.timestamp).timeIntervalSince1970)),
                                       @"uuid": (beacon.UUID).UUIDString,
                                       @"major": beacon.major,
                                       @"minor": beacon.minor,
                                       @"prox": @(beacon.proximity),
                                       @"acc": @(beacon.accuracy),
                                       @"rssi": @(beacon.rssi)
                                       }];
        if (myRegion) {
            json[@"desc"] = myRegion.name;
        }
        [self.connection sendData:[self jsonToData:json]
                            topic:[[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] stringByAppendingString:@"/beacon"]
                       topicAlias:@(3)
                              qos:[Settings intForKey:@"qos_preference"
                                                inMOC:CoreData.sharedInstance.mainMOC]
                           retain:NO];
    }
}

#pragma ConnectionDelegate

- (void)showState:(Connection *)connection
            state:(NSInteger)state {
    DDLogVerbose(@"[OwnTracksAppDelegate] showState: %ld", (long)state);

    self.connectionState = @(state);
    [self performSelectorOnMainThread:@selector(checkState:) withObject:@(state) waitUntilDone:NO];
}

- (void)checkState:(NSNumber *)state {
    /**
     ** This is a hack to ensure the connection gets gracefully closed at the server
     **
     ** If the background task is ended, occasionally the disconnect message is not received well before the server senses the tcp disconnect
     **/

    NSTimeInterval backgroundTimeRemaining = [UIApplication sharedApplication].backgroundTimeRemaining;
    DDLogVerbose(@"[OwnTracksAppDelegate] checkState: %@, backgroundTimeRemaining: %@",
              state,
              backgroundTimeRemaining > 24 * 3600 ? @"∞": @(floor(backgroundTimeRemaining)).stringValue);

    if (state.intValue == state_starting) {
        if (self.backgroundTask) {
            if (self.bgTimer) {
                if (self.bgTimer.isValid) {
                    [self.bgTimer invalidate];
                }
                self.bgTimer = nil;
            }
            if (self.holdTimer) {
                if (self.holdTimer.isValid) {
                    [self.holdTimer invalidate];
                }
                self.holdTimer = nil;
            }
            if (self.disconnectTimer) {
                if (self.disconnectTimer.isValid) {
                    [self.disconnectTimer invalidate];
                }
                self.disconnectTimer = nil;
            }

            DDLogInfo(@"[OwnTracksAppDelegate] endBackGroundTask %lu",
                         (unsigned long)self.backgroundTask);
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
            self.backgroundTask = UIBackgroundTaskInvalid;
        }
        if (self.bgTask) {
            [self.bgTask setTaskCompletedWithSuccess:TRUE];
            self.bgTask = nil;
        }
    }
}

- (BOOL)handleMessage:(Connection *)connection
                 data:(NSData *)data
              onTopic:(NSString *)topic
             retained:(BOOL)retained {
    DDLogVerbose(@"[OwnTracksAppDelegate] handleMessage");

    [CoreData.sharedInstance.queuedMOC performBlock:^{
        (void)[[OwnTracking sharedInstance] processMessage:topic
                                                      data:data
                                                  retained:retained
                                                   context:CoreData.sharedInstance.queuedMOC];
        NSArray *baseComponents = [[Settings theGeneralTopicInMOC:CoreData.sharedInstance.queuedMOC] componentsSeparatedByString:@"/"];
        NSArray *topicComponents = [topic componentsSeparatedByString:@"/"];

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

        DDLogVerbose(@"[OwnTracksAppDelegate] device %@ owndevice %d", device, ownDevice);

        if (ownDevice) {

            NSError *error;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (json && [json isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dictionary = json;
                if ([@"cmd" saveEqual:dictionary[@"_type"]]) {
                    if (
#ifdef DEBUG
                        true /* dirty work around not being able to set simulator .otrc */
#else
                        [Settings boolForKey:@"cmd_preference" inMOC:CoreData.sharedInstance.queuedMOC]
#endif
                        ) {
                        if ([@"dump" saveEqual:dictionary[@"action"]]) {
                            [self dump];

                        } else if ([@"reportLocation" saveEqual:dictionary[@"action"]]) {
                            if ([LocationManager sharedInstance].monitoring == LocationMonitoringSignificant ||
                                [LocationManager sharedInstance].monitoring == LocationMonitoringMove ||
                                [Settings boolForKey:@"allowremotelocation_preference"
                                               inMOC:CoreData.sharedInstance.queuedMOC]) {
                                    [self performSelectorOnMainThread:@selector(reportLocation)
                                                           withObject:nil
                                                        waitUntilDone:NO];
                                }

                        } else if ([@"reportSteps" saveEqual:dictionary[@"action"]]) {
                            [self stepsFrom:[NSNumber saveCopy:dictionary[@"from"]]
                                         to:[NSNumber saveCopy:dictionary[@"to"]]];

                        } else if ([@"waypoints" saveEqual:dictionary[@"action"]]) {
                            [self performSelectorOnMainThread:@selector(waypoints)
                                                   withObject:nil
                                                waitUntilDone:NO];

                        } else if ([@"action" saveEqual:dictionary[@"action"]]) {
                            [self performSelectorOnMainThread:@selector(performAction:)
                                                   withObject:dictionary
                                                waitUntilDone:NO];

                        } else if ([@"setWaypoints" saveEqual:dictionary[@"action"]]) {
                            [self performSelectorOnMainThread:@selector(performSetWaypoints:)
                                                   withObject:dictionary
                                                waitUntilDone:NO];

                        } else if ([@"setConfiguration" saveEqual:dictionary[@"action"]]) {
                            [self performSelectorOnMainThread:@selector(performSetConfiguration:)
                                                   withObject:dictionary
                                                waitUntilDone:NO];

                        } else {
                            DDLogWarn(@"[OwnTracksAppDelegate] unknown action %@", dictionary[@"action"]);
                        }
                    }
                }
            } else {
                DDLogWarn(@"[OwnTracksAppDelegate] illegal json %@ %@ %@", error.localizedDescription, error.userInfo, data.description);
            }
        }
        [CoreData.sharedInstance sync:CoreData.sharedInstance.queuedMOC];
    }];

    return true;
}

- (void)messageDelivered:(Connection *)connection msgID:(UInt16)msgID {
    DDLogVerbose(@"[OwnTracksAppDelegate] messageDelivered msgID=%u", msgID);
}

- (void)totalBuffered:(Connection *)connection count:(NSUInteger)count {
    self.connectionBuffered = @(count);
    [self performSelectorOnMainThread:@selector(updateUI) withObject:nil waitUntilDone:NO];
}

- (void)updateUI {
    [UIApplication sharedApplication].applicationIconBadgeNumber = self.connectionBuffered.intValue;
}

- (void)dump {
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithDictionary:
                                 @{
                                   @"_type":@"dump",
                                   @"configuration":[Settings toDictionaryInMOC:CoreData.sharedInstance.mainMOC],
                                   }];
    [self.connection sendData:[self jsonToData:json]
                        topic:[[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] stringByAppendingString:@"/dump"]
                   topicAlias:@(4)
                          qos:[Settings intForKey:@"qos_preference"
                                            inMOC:CoreData.sharedInstance.mainMOC]
                       retain:NO];
}

- (void)performAction:(NSDictionary *)dictionary {
    NSString *content = [NSString saveCopy:dictionary[@"content"]];
    NSString *url = [NSString saveCopy:dictionary[@"url"] ];
    NSString *notificationMessage = [NSString saveCopy:dictionary[@"notification"]];
    NSNumber *external = [NSNumber saveCopy:dictionary[@"extern"]];

    [Settings setString:content
                 forKey:SETTINGS_ACTION
                  inMOC:CoreData.sharedInstance.mainMOC];
    [Settings setString:url
                 forKey:SETTINGS_ACTIONURL
                  inMOC:CoreData.sharedInstance.mainMOC];
    [Settings setBool:external.boolValue
               forKey:SETTINGS_ACTIONEXTERN
                inMOC:CoreData.sharedInstance.mainMOC];

    if (notificationMessage) {
        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.body = notificationMessage;
        UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger
                                                      triggerWithTimeInterval:1.0
                                                      repeats:NO];
        NSString *notificationIdentifier = [NSString stringWithFormat:@"action%f",
                                            [NSDate date].timeIntervalSince1970];
        DDLogVerbose(@"[OwnTracksAppDelegate] notificationIdentifier:%@", notificationIdentifier);

        UNNotificationRequest* request = [UNNotificationRequest         requestWithIdentifier:notificationIdentifier
                                                                              content:content
                                                                              trigger:trigger];
        UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
        [center addNotificationRequest:request withCompletionHandler:nil];

        [History historyInGroup:@"Notification"
                       withText:notificationMessage
                             at:nil
                          inMOC:[CoreData sharedInstance].mainMOC
                        maximum:[Settings theMaximumHistoryInMOC:[CoreData sharedInstance].mainMOC]];
        [CoreData.sharedInstance sync:CoreData.sharedInstance.queuedMOC];

        [self.navigationController alert:NSLocalizedString(@"Notification",
                                                           @"Alert message header for notification messages")
                                 message:notificationMessage
                            dismissAfter:2.0
         ];
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
}

- (void)performSetConfiguration:(NSDictionary *)dictionary {
    NSDictionary *payload = [NSDictionary saveCopy:dictionary[@"payload"]];
    NSDictionary *configuration = [NSDictionary saveCopy:dictionary[@"configuration"]];
    if (configuration && [configuration isKindOfClass:[NSDictionary class]]) {
        [Settings fromDictionary:configuration
                           inMOC:CoreData.sharedInstance.mainMOC];
    } else if (payload && [payload isKindOfClass:[NSDictionary class]]) {
        [Settings fromDictionary:payload
                           inMOC:CoreData.sharedInstance.mainMOC];
    }
    self.configLoad = [NSDate date];
    [self reconnect];
}

- (void)performSetWaypoints:(NSDictionary *)dictionary {
    NSDictionary *payload = [NSDictionary saveCopy:dictionary[@"payload"]];
    NSDictionary *waypoints = [NSDictionary saveCopy:dictionary[@"waypoints"]];
    if (waypoints && [waypoints isKindOfClass:[NSDictionary class]]) {
        [Settings waypointsFromDictionary:waypoints
                                    inMOC:CoreData.sharedInstance.mainMOC];
    } else if (payload && [payload isKindOfClass:[NSDictionary class]]) {
        [Settings waypointsFromDictionary:payload
                                    inMOC:CoreData.sharedInstance.mainMOC];
    }
}

- (void)waypoints {
    NSMutableDictionary *json = [[Settings waypointsToDictionaryInMOC:CoreData.sharedInstance.mainMOC] mutableCopy];
    [self.connection sendData:[self jsonToData:json]
                        topic:[[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] stringByAppendingString:@"/waypoints"]
                   topicAlias:@(5)
                          qos:[Settings intForKey:@"qos_preference"
                                            inMOC:CoreData.sharedInstance.mainMOC]
                       retain:NO];
}

- (void)stepsFrom:(NSNumber *)from to:(NSNumber *)to {
    NSDate *toDate;
    NSDate *fromDate;
    if (to && [to isKindOfClass:[NSNumber class]]) {
        toDate = [NSDate dateWithTimeIntervalSince1970:to.doubleValue];
    } else {
        toDate = [NSDate date];
    }
    if (from && [from isKindOfClass:[NSNumber class]]) {
        fromDate = [NSDate dateWithTimeIntervalSince1970:from.doubleValue];
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

    DDLogInfo(@"[OwnTracksAppDelegate] isStepCountingAvailable %d",
              [CMPedometer isStepCountingAvailable]);
    DDLogInfo(@"[OwnTracksAppDelegate] isFloorCountingAvailable %d",
              [CMPedometer isFloorCountingAvailable]);
    DDLogInfo(@"[OwnTracksAppDelegate] isDistanceAvailable %d",
              [CMPedometer isDistanceAvailable]);

    if (!self.pedometer) {
        self.pedometer = [[CMPedometer alloc] init];
    }
    [self.pedometer queryPedometerDataFromDate:fromDate
                                        toDate:toDate
                                   withHandler:
     ^(CMPedometerData *pedometerData, NSError *error) {
         DDLogVerbose(@"[OwnTracksAppDelegate] StepCounter queryPedometerDataFromDate %ld %ld %ld %ld %@",
                      [pedometerData.numberOfSteps longValue],
                      [pedometerData.floorsAscended longValue],
                      [pedometerData.floorsDescended longValue],
                      [pedometerData.distance longValue],
                      error.localizedDescription);
         dispatch_async(dispatch_get_main_queue(), ^{
             
             NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
             [json addEntriesFromDictionary:@{
                                              @"_type": @"steps",
                                              @"tst": @(floor([NSDate date].timeIntervalSince1970)),
                                              @"from": @(floor(fromDate.timeIntervalSince1970)),
                                              @"to": @(floor(toDate.timeIntervalSince1970)),
                                              }];
             if (pedometerData) {
                 json[@"steps"] = pedometerData.numberOfSteps;
                 if (pedometerData.floorsAscended) {
                     json[@"floorsup"] = pedometerData.floorsAscended;
                 }
                 if (pedometerData.floorsDescended) {
                     json[@"floorsdown"] = pedometerData.floorsDescended;
                 }
                 if (pedometerData.distance) {
                     json[@"distance"] = pedometerData.distance;
                 }
             } else {
                 json[@"steps"] = @(-1);
             }
             
             [self.connection sendData:[self jsonToData:json]
                                 topic:[[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] stringByAppendingString:@"/step"]
                            topicAlias:@(6)
                                   qos:[Settings intForKey:@"qos_preference"
                                                     inMOC:CoreData.sharedInstance.mainMOC]
                                retain:NO];
         });
     }];
}

#pragma actions

- (BOOL)sendNow:(CLLocation *)location {
    DDLogVerbose(@"[OwnTracksAppDelegate] sendNow %@", location);
    return [self publishLocation:location trigger:@"u"];
}

- (void)reportLocation {
    DDLogVerbose(@"[OwnTracksAppDelegate] reportLocation");
    CLLocation *location = [LocationManager sharedInstance].location;
    [self publishLocation:location trigger:@"r"];
}

- (void)connectionOff {
    DDLogVerbose(@"[OwnTracksAppDelegate] connectionOff");
    [self.connection disconnect];
}

- (void)terminateSession {
    DDLogInfo(@"[OwnTracksAppDelegate] terminateSession");

    [self connectionOff];
    [[OwnTracking sharedInstance] syncProcessing];
    [[LocationManager sharedInstance] resetRegions];
    [self.connection reset];
    NSArray *friends = [Friend allFriendsInManagedObjectContext:CoreData.sharedInstance.mainMOC];
    for (Friend *friend in friends) {
        [CoreData.sharedInstance.mainMOC deleteObject:friend];
    }
    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
}

- (void)reconnect {
    DDLogInfo(@"[OwnTracksAppDelegate] reconnect");
    [self.connection disconnect];
    [self connect];
}

- (BOOL)publishLocation:(CLLocation *)location
                trigger:(NSString *)trigger {
    if (location &&
        CLLocationCoordinate2DIsValid(location.coordinate) &&
        location.coordinate.latitude != 0.0 &&
        location.coordinate.longitude != 0.0 &&
        [Settings validIdsInMOC:CoreData.sharedInstance.mainMOC]) {

        int ignoreInaccurateLocations = [Settings intForKey:@"ignoreinaccuratelocations_preference"
                                                      inMOC:CoreData.sharedInstance.mainMOC];
        DDLogVerbose(@"[OwnTracksAppDelegate] location accuracy:%fm, ignoreIncacurationLocations:%dm",
                     location.horizontalAccuracy, ignoreInaccurateLocations);

        if (ignoreInaccurateLocations == 0 || location.horizontalAccuracy < ignoreInaccurateLocations) {
            Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC]
                              inManagedObjectContext:CoreData.sharedInstance.mainMOC];
            if (friend) {
                for (Region *anyRegion in friend.hasRegions) {
                    if ([anyRegion.CLregion.identifier hasPrefix:@"+"]) {
                        if ((anyRegion.radius).doubleValue > 0) {
                            anyRegion.lat = @(location.coordinate.latitude);
                            anyRegion.lon = @(location.coordinate.longitude);
                            if (location.speed >= 0.0) {
                                anyRegion.radius = @(MAX(location.speed * 30.0, 50.0));
                            } else {
                                anyRegion.radius = @(50.0);
                            }
                            [[LocationManager sharedInstance] startRegion:anyRegion.CLregion];
                        }
                    }
                }

                friend.tid = [Settings stringForKey:@"trackerid_preference"
                                              inMOC:CoreData.sharedInstance.mainMOC];

                Waypoint *waypoint = [[OwnTracking sharedInstance] addWaypointFor:friend
                                                                         location:location
                                                                          trigger:trigger
                                                                          context:CoreData.sharedInstance.mainMOC];
                if (waypoint) {
                    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];

                    NSMutableDictionary *json = [[[OwnTracking sharedInstance] waypointAsJSON:waypoint] mutableCopy];
                    if (json) {
                        NSData *data = [self jsonToData:json];
                        [self.connection sendData:data
                                            topic:[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC]
                                       topicAlias:@(1)
                                              qos:[Settings intForKey:@"qos_preference"
                                                                inMOC:CoreData.sharedInstance.mainMOC]
                                           retain:[Settings boolForKey:@"retain_preference"
                                                                 inMOC:CoreData.sharedInstance.mainMOC]];
                    } else {
                        DDLogError(@"[OwnTracksAppDelegate] no JSON created from waypoint %@", waypoint);
                        return FALSE;
                    }
                    [[OwnTracking sharedInstance] limitWaypointsFor:friend
                                                          toMaximum:[Settings intForKey:@"positions_preference"
                                                                                  inMOC:CoreData.sharedInstance.mainMOC]];
                } else {
                    DDLogError(@"[OwnTracksAppDelegate] waypoint creation failed from friend %@, location %@", friend, location);
                    return FALSE;
                }
            } else {
                DDLogError(@"[OwnTracksAppDelegate] no friend found");
                return FALSE;
            }
        }
    } else {
        DDLogError(@"[OwnTracksAppDelegate] invalid location");
        return FALSE;
    }
    return TRUE;
}

- (void)sendEmpty:(NSString *)topic {
    [self.connection sendData:nil
                        topic:topic
                   topicAlias:nil
                          qos:[Settings intForKey:@"qos_preference"
                                            inMOC:CoreData.sharedInstance.mainMOC]
                       retain:YES];
}

- (void)requestLocationFromFriend:(Friend *)friend {
    NSMutableDictionary *json = [@{
                                   @"_type": @"cmd",
                                   @"action": @"reportLocation"
                                   } mutableCopy];
    [self.connection sendData:[self jsonToData:json]
                        topic:[friend.topic stringByAppendingString:@"/cmd"]
                   topicAlias:nil
                          qos:[Settings intForKey:@"qos_preference"
                                            inMOC:CoreData.sharedInstance.mainMOC]
                       retain:NO];
}

- (void)sendRegion:(Region *)region {
    if ([Settings validIdsInMOC:CoreData.sharedInstance.mainMOC]) {
        NSMutableDictionary *json = [[[OwnTracking sharedInstance] regionAsJSON:region] mutableCopy];
        NSData *data = [self jsonToData:json];
        [self.connection sendData:data
                            topic:[[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] stringByAppendingString:@"/waypoint"]
                       topicAlias:@(7)
                              qos:[Settings intForKey:@"qos_preference"
                                                inMOC:CoreData.sharedInstance.mainMOC]
                           retain:NO];
    }
}

#pragma internal helpers

- (void)connect {
    BOOL usePassword = [Settings theMqttUsePasswordInMOC:CoreData.sharedInstance.mainMOC];
    NSString *password = nil;
    if (usePassword) {
        password = [Settings theMqttPassInMOC:CoreData.sharedInstance.mainMOC];
    }
    if ([Settings intForKey:@"mode" inMOC:CoreData.sharedInstance.mainMOC] == CONNECTION_MODE_HTTP) {
        self.connection.key = [Settings stringForKey:@"secret_preference"
                                               inMOC:CoreData.sharedInstance.mainMOC];
        [self.connection connectHTTP:[Settings stringForKey:@"url_preference"
                                                      inMOC:CoreData.sharedInstance.mainMOC]
                                auth:[Settings theMqttAuthInMOC:CoreData.sharedInstance.mainMOC]
                                user:[Settings theMqttUserInMOC:CoreData.sharedInstance.mainMOC]
                                pass:password
                              device:[Settings theDeviceIdInMOC:CoreData.sharedInstance.mainMOC]];

    } else {
        NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                     inDomain:NSUserDomainMask
                                                            appropriateForURL:nil
                                                                       create:YES
                                                                        error:nil];
        NSArray *certificates = nil;
        NSString *fileName = [Settings stringForKey:@"clientpkcs" inMOC:CoreData.sharedInstance.mainMOC];
        if (fileName && fileName.length) {
            DDLogVerbose(@"[OwnTracksAppDelegate] getting p12 filename:%@ passphrase:%@",
                         fileName, [Settings stringForKey:@"passphrase" inMOC:CoreData.sharedInstance.mainMOC]);
            NSString *clientPKCSPath = [directoryURL.path stringByAppendingPathComponent:fileName];
            certificates = [MQTTTransport clientCertsFromP12:clientPKCSPath
                                                  passphrase:[Settings stringForKey:@"passphrase"
                                                                              inMOC:CoreData.sharedInstance.mainMOC]];
            if (!certificates) {
                [self.navigationController alert:NSLocalizedString(@"TLS Client Certificate",
                                                                   @"Heading for certificate error message")
                                         message:NSLocalizedString(@"incorrect file or passphrase",
                                                                   @"certificate error message")
                 ];
            }
        }

        MQTTQosLevel subscriptionQos =[Settings intForKey:@"subscriptionqos_preference"
                                                    inMOC:CoreData.sharedInstance.mainMOC];
        NSArray *subscriptions = [[NSArray alloc] init];
        if ([Settings boolForKey:@"sub_preference" inMOC:CoreData.sharedInstance.mainMOC]) {
            subscriptions = [[Settings theSubscriptionsInMOC:CoreData.sharedInstance.mainMOC] componentsSeparatedByCharactersInSet:
                             [NSCharacterSet whitespaceCharacterSet]];
        }

        self.connection.subscriptions = subscriptions;
        self.connection.subscriptionQos = subscriptionQos;

        NSMutableDictionary *json = [NSMutableDictionary dictionaryWithDictionary:@{
            @"tst": @((int)[NSDate date].timeIntervalSince1970),
            @"_type": @"lwt"
        }];
        
        self.connection.key = [Settings stringForKey:@"secret_preference"
                                               inMOC:CoreData.sharedInstance.mainMOC];

        [self.connection connectTo:[Settings theHostInMOC:CoreData.sharedInstance.mainMOC]
                              port:[Settings intForKey:@"port_preference" inMOC:CoreData.sharedInstance.mainMOC]
                                ws:[Settings boolForKey:@"ws_preference" inMOC:CoreData.sharedInstance.mainMOC]
                               tls:[Settings boolForKey:@"tls_preference" inMOC:CoreData.sharedInstance.mainMOC]
                   protocolVersion:[Settings intForKey:SETTINGS_PROTOCOL inMOC:CoreData.sharedInstance.mainMOC]
                         keepalive:[Settings intForKey:@"keepalive_preference" inMOC:CoreData.sharedInstance.mainMOC]
                             clean:[Settings intForKey:@"clean_preference" inMOC:CoreData.sharedInstance.mainMOC]
                              auth:[Settings theMqttAuthInMOC:CoreData.sharedInstance.mainMOC]
                              user:[Settings theMqttUserInMOC:CoreData.sharedInstance.mainMOC]
                              pass:password
                         willTopic:[Settings theWillTopicInMOC:CoreData.sharedInstance.mainMOC]
                              will:[self jsonToData:json]
                           willQos:[Settings intForKey:@"willqos_preference" inMOC:CoreData.sharedInstance.mainMOC]
                    willRetainFlag:[Settings boolForKey:@"willretain_preference" inMOC:CoreData.sharedInstance.mainMOC]
                      withClientId:[Settings theClientIdInMOC:CoreData.sharedInstance.mainMOC]
        allowUntrustedCertificates:[Settings boolForKey:@"allowinvalidcerts" inMOC:CoreData.sharedInstance.mainMOC]
                      certificates:certificates];
    }
}

- (NSData *)jsonToData:(NSDictionary *)jsonObject {
    NSData *data;

    if ([NSJSONSerialization isValidJSONObject:jsonObject]) {
        NSError *error;
        data = [NSJSONSerialization dataWithJSONObject:jsonObject options:0 /* not pretty printed */ error:&error];
        if (!data) {
            DDLogError(@"[OwnTracksAppDelegate] dataWithJSONObject failed: %@ %@ %@",
                       error.localizedDescription,
                       error.userInfo,
                       [jsonObject description]);
        }

        // *****
        // This is a hack because I don't see another chance to modify NSNumber
        // formatting in NSJSONSerialization
        // *****
        NSNumber *lat = [jsonObject valueForKey:@"lat"];
        NSNumber *lon = [jsonObject valueForKey:@"lon"];
        NSString *jsonString = [[NSString alloc] initWithData:data
                                                     encoding:NSUTF8StringEncoding];
        if (lat) {
            NSString *latString = [NSString stringWithFormat:@"\"lat\":%.6f", lat.doubleValue];
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{@"lat": lat}
                                                               options:0
                                                                 error:nil];
            NSString *jsonSubString = [[NSString alloc] initWithData:jsonData
            encoding:NSUTF8StringEncoding];
            jsonSubString = [jsonSubString substringWithRange:NSMakeRange(1, jsonSubString.length - 2)];

            jsonString = [jsonString stringByReplacingOccurrencesOfString:jsonSubString
                                                               withString:latString];
        }
        if (lon) {
            NSString *lonString = [NSString stringWithFormat:@"\"lon\":%.6f", lon.doubleValue];
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{@"lon": lon}
                                                               options:0
                                                                 error:nil];
            NSString *jsonSubString = [[NSString alloc] initWithData:jsonData
            encoding:NSUTF8StringEncoding];
            jsonSubString = [jsonSubString substringWithRange:NSMakeRange(1, jsonSubString.length - 2)];

            jsonString = [jsonString stringByReplacingOccurrencesOfString:jsonSubString
                                                               withString:lonString];
        }
        data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        // ***** 
    } else {
        DDLogError(@"[OwnTracksAppDelegate] isValidJSONObject failed %@", [jsonObject description]);
    }
    return data;
}

- (void)application:(UIApplication *)application didUpdateUserActivity:(NSUserActivity *)userActivity {
    //
}

- (BOOL)application:(UIApplication *)application willContinueUserActivityWithType:(NSString *)userActivityType  {
    //
    return true;
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
    return TRUE;
}

- (void)application:(UIApplication *)application didFailToContinueUserActivityWithType:(NSString *)userActivityType error:(NSError *)error {
    //
}

@end

