//
//  OwnTracksAppDelegate.m
//  OwnTracks
//
//  Created by Christoph Krey on 03.02.14.
//  Copyright © 2014-2017 OwnTracks. All rights reserved.
//

#import "OwnTracksAppDelegate.h"
#import "CoreData.h"
#import "Setting.h"
#import "AlertView.h"
#import "Settings.h"
#import "Location.h"
#import "Settings.h"
#import "OwnTracking.h"
#import <NotificationCenter/NotificationCenter.h>
#import "ConnType.h"
#import "GeoHashing.h"
#import "MQTTCFSocketTransport.h"
#import "MQTTSSLSecurityPolicy.h"

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
@property (strong, nonatomic) void (^completionHandler)(UIBackgroundFetchResult);
@property (strong, nonatomic) NSString *backgroundFetchCheckMessage;
@property (strong, nonatomic) CoreData *coreData;
@property (strong, nonatomic) CMPedometer *pedometer;

@property (strong, nonatomic) NSManagedObjectContext *queueManagedObjectContext;

#define BACKGROUND_DISCONNECT_AFTER 15.0
@property (strong, nonatomic) NSTimer *disconnectTimer;

@end

@implementation OwnTracksAppDelegate

#pragma ApplicationDelegate

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
#ifdef DEBUG
    [DDLog addLogger:[DDTTYLogger sharedInstance] withLevel:DDLogLevelVerbose];
#endif
    [DDLog addLogger:[DDASLLogger sharedInstance] withLevel:DDLogLevelWarning];


    self.backgroundTask = UIBackgroundTaskInvalid;
    self.completionHandler = nil;

    UIBackgroundRefreshStatus status = [UIApplication sharedApplication].backgroundRefreshStatus;
    switch (status) {
        case UIBackgroundRefreshStatusAvailable:
            DDLogVerbose(@"[OwnTracksAppDelegate] UIBackgroundRefreshStatusAvailable");
            [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
            break;
        case UIBackgroundRefreshStatusDenied:
            DDLogWarn(@"[OwnTracksAppDelegate] UIBackgroundRefreshStatusDenied");
            self.backgroundFetchCheckMessage = NSLocalizedString(@"You did disable background fetch",
                                                                 @"You did disable background fetch");
            break;
        case UIBackgroundRefreshStatusRestricted:
            DDLogWarn(@"[OwnTracksAppDelegate] UIBackgroundRefreshStatusRestricted");
            self.backgroundFetchCheckMessage = NSLocalizedString(@"You cannot use background fetch",
                                                                 @"You cannot use background fetch");
            break;
    }

    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:
                                            UIUserNotificationTypeAlert |UIUserNotificationTypeBadge
                                                                             categories:nil];
    [application registerUserNotificationSettings:settings];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationUserDidTakeScreenshotNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note){
                                                      DDLogVerbose(@"UIApplicationUserDidTakeScreenshotNotification");
                                                  }];
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    DDLogVerbose(@"didFinishLaunchingWithOptions");

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

    [OwnTracking sharedInstance].cp = [Settings boolForKey:@"cp"];

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

-(BOOL)application:(UIApplication *)app
           openURL:(NSURL *)url
           options:(NSDictionary<NSString *,id> *)options {
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
                                                                     @"tst":@((int)([NSDate date].timeIntervalSince1970)),
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

         DDLogVerbose(@"dataTaskWithRequest %@ %@ %@", data, response, error);
         if (!error) {

             if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                 NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                 DDLogVerbose(@"NSHTTPURLResponse %@", httpResponse);
                 if (httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299) {
                     NSError *error;
                     NSString *extension = url.pathExtension;
                     if ([extension isEqualToString:@"otrc"] || [extension isEqualToString:@"mqtc"]) {
                         [self terminateSession];
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
                         [AlertView alert:@"processNSURL"
                                  message:[NSString stringWithFormat:@"OOPS %@ %@",
                                           [NSError errorWithDomain:@"OwnTracks"
                                                               code:2
                                                           userInfo:@{@"extension":extension ? extension : @"(null)"}],
                                           url]];
                     }
                 } else {
                     [AlertView alert:@"processNSURL"
                              message:[NSString stringWithFormat:@"httpResponse.statusCode %ld %@",
                                       (long)httpResponse.statusCode,
                                       url]];
                 }
             } else {
                 [AlertView alert:@"processNSURL"
                          message:[NSString stringWithFormat:@"response %@ %@",
                                   response,
                                   url]];
             }
         } else {
             [AlertView alert:@"processNSURL"
                      message:[NSString stringWithFormat:@"dataTaskWithRequest %@ %@",
                               error,
                               url]];
         }
     }];
    [dataTask resume];
    return TRUE;
}

- (void)configFromDictionary:(NSDictionary *)json {
    NSError *error = [Settings fromDictionary:json];
    [CoreData saveContext];
    if (error) {
        [AlertView alert:@"processNSURL"
                 message:[NSString stringWithFormat:@"configFromDictionary %@ %@",
                          error,
                          json]];
    }
}

- (void)waypointsFromDictionary:(NSDictionary *)json {
    NSError *error = [Settings waypointsFromDictionary:json];
    [CoreData saveContext];
    if (error) {
        [AlertView alert:@"processNSURL"
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

    DDLogVerbose(@"URL pathExtension %@", url.pathExtension);

    NSError *error;
    NSString *extension = url.pathExtension;
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
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
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

- (void)applicationDidEnterBackground:(UIApplication *)application {
    DDLogVerbose(@"applicationDidEnterBackground");
    [self background];
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    DDLogVerbose(@"applicationDidBecomeActive");

    if (self.disconnectTimer && self.disconnectTimer.isValid) {
        DDLogVerbose(@"disconnectTimer invalidate %@",
                     self.disconnectTimer.fireDate);
        [self.disconnectTimer invalidate];
    }

    if (self.backgroundFetchCheckMessage) {
        [AlertView alert:@"Background Fetch" message:self.backgroundFetchCheckMessage];
        self.backgroundFetchCheckMessage = nil;
    }

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

- (void)application:(UIApplication *)application
performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {

    DDLogVerbose(@"performFetchWithCompletionHandler");
    self.completionHandler = completionHandler;
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

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    DDLogVerbose(@"didRegisterUserNotificationSettings %@", notificationSettings);
}

- (void)background {
    [self startBackgroundTimer];
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground &&
        self.backgroundTask == UIBackgroundTaskInvalid) {
        self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            DDLogVerbose(@"BackgroundTaskExpirationHandler");

            if (self.completionHandler) {
                DDLogVerbose(@"completionHandler");
                self.completionHandler(UIBackgroundFetchResultNewData);
                self.completionHandler = nil;
            }

            if (self.backgroundTask) {
                [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
                self.backgroundTask = UIBackgroundTaskInvalid;
            }

        }];
    }
}

- (void)startBackgroundTimer {
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground &&
        [LocationManager sharedInstance].monitoring != LocationMonitoringMove) {
        if (self.disconnectTimer && self.disconnectTimer.isValid) {
            DDLogVerbose(@"disconnectTimer.isValid %@",
                         self.disconnectTimer.fireDate);
        } else {
            self.disconnectTimer = [NSTimer timerWithTimeInterval:BACKGROUND_DISCONNECT_AFTER
                                                           target:self
                                                         selector:@selector(disconnectInBackground)
                                                         userInfo:Nil
                                                          repeats:FALSE];
            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            [runLoop addTimer:self.disconnectTimer forMode:NSDefaultRunLoopMode];
            DDLogVerbose(@"disconnectTimer %@",
                         self.disconnectTimer.fireDate);
        }
    }
}

- (void)disconnectInBackground {
    DDLogVerbose(@"disconnectInBackground");
    self.disconnectTimer = nil;
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
    [[GeoHashing sharedInstance] newLocation:location];
}

- (void)timerLocation:(CLLocation *)location {
    [self background];
    [self publishLocation:location trigger:@"t"];
    [[GeoHashing sharedInstance] newLocation:location];
}

- (void)visitLocation:(CLLocation *)location {
    [self background];
    [self publishLocation:location trigger:@"v"];
    [[GeoHashing sharedInstance] newLocation:location];
}

- (void)regionEvent:(CLRegion *)region enter:(BOOL)enter {
    [self background];
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
                                       @"tst": @(floor((location.timestamp).timeIntervalSince1970)),
                                       @"acc": @(location.horizontalAccuracy),
                                       @"tid": myself.effectiveTid,
                                       @"event": enter ? @"enter" : @"leave",
                                       @"t": [region isKindOfClass:[CLBeaconRegion class]] ? @"b" : @"c"
                                       } mutableCopy];

        for (Region *anyRegion in myself.hasRegions) {
            if ([region.identifier isEqualToString:anyRegion.CLregion.identifier]) {
                anyRegion.name = anyRegion.name;
                if ((anyRegion.share).boolValue) {
                    [json setValue:region.identifier forKey:@"desc"];
                    [json setValue:@(floor(anyRegion.andFillTst.timeIntervalSince1970)) forKey:@"wtst"];

                    switch ([Settings intForKey:@"mode"]) {
                        case CONNECTION_MODE_WATSON:
                        case CONNECTION_MODE_WATSONREGISTERED:
                            [self.connection sendData:[self jsonToData:json]
                                                topic:[[Settings theGeneralTopic] stringByReplacingOccurrencesOfString:@"/location/"
                                                                                                            withString:@"/event/"]
                                                  qos:[Settings intForKey:@"qos_preference"]
                                               retain:NO];
                            break;

                        default:
                            [self.connection sendData:[self jsonToData:json]
                                                topic:[[Settings theGeneralTopic] stringByAppendingString:@"/event"]
                                                  qos:[Settings intForKey:@"qos_preference"]
                                               retain:NO];
                            break;
                    }
                }
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

- (void)beaconInRange:(CLBeacon *)beacon region:(CLBeaconRegion *)region {
    [self background];
    if ([Settings validIds]) {
        Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopic]
                                inManagedObjectContext:[CoreData theManagedObjectContext]];

        NSMutableDictionary *json = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                    @"_type": @"beacon",
                                                                                    @"tid": myself.effectiveTid,
                                                                                    @"tst": @(floor(([LocationManager sharedInstance].location.timestamp).timeIntervalSince1970)),
                                                                                    @"uuid": (beacon.proximityUUID).UUIDString,
                                                                                    @"major": beacon.major,
                                                                                    @"minor": beacon.minor,
                                                                                    @"prox": @(beacon.proximity),
                                                                                    @"acc": @(beacon.accuracy),
                                                                                    @"rssi": @(beacon.rssi)
                                                                                    }];
        switch ([Settings intForKey:@"mode"]) {
            case CONNECTION_MODE_WATSON:
            case CONNECTION_MODE_WATSONREGISTERED:
                [self.connection sendData:[self jsonToData:json]
                                    topic:[[Settings theGeneralTopic] stringByReplacingOccurrencesOfString:@"/location/"
                                                                                                withString:@"/beacon/"]
                                      qos:[Settings intForKey:@"qos_preference"]
                                   retain:NO];
                break;

            default:
                [self.connection sendData:[self jsonToData:json]
                                    topic:[[Settings theGeneralTopic] stringByAppendingString:@"/beacon"]
                                      qos:[Settings intForKey:@"qos_preference"]
                                   retain:NO];
                break;

        }
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
    DDLogInfo(@"showState %g", [UIApplication sharedApplication].backgroundTimeRemaining);

    if ((self.connectionState).intValue == state_closed) {
        if (self.completionHandler) {
            DDLogVerbose(@"completionHandler");
            self.completionHandler(UIBackgroundFetchResultNewData);
            self.completionHandler = nil;
        }
        if (self.backgroundTask) {
            DDLogVerbose(@"endBackGroundTask");
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
            self.backgroundTask = UIBackgroundTaskInvalid;
        }
    }
}

- (NSManagedObjectContext *)queueManagedObjectContext
{
    if (!_queueManagedObjectContext) {
        _queueManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _queueManagedObjectContext.parentContext = [CoreData theManagedObjectContext];
    }
    return _queueManagedObjectContext;
}

- (BOOL)handleMessage:(Connection *)connection data:(NSData *)data onTopic:(NSString *)topic retained:(BOOL)retained {
    DDLogVerbose(@"handleMessage");

    if (![[GeoHashing sharedInstance] processMessage:topic data:data retained:retained context:self.queueManagedObjectContext]) {
        return false;
    }

    if (![[OwnTracking sharedInstance] processMessage:topic data:data retained:retained context:self.queueManagedObjectContext]) {
        return false;
    }

    NSArray *baseComponents = [[Settings theGeneralTopic] componentsSeparatedByString:@"/"];
    NSArray *topicComponents = [[Settings theGeneralTopic] componentsSeparatedByString:@"/"];

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

    DDLogVerbose(@"device %@", device);

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
                    [Settings boolForKey:@"cmd_preference"]
#endif
                    ) {
                    if ([@"dump" saveEqual:dictionary[@"action"]]) {
                        [self dump];

                    } else if ([@"reportLocation" saveEqual:dictionary[@"action"]]) {
                        if ([LocationManager sharedInstance].monitoring == LocationMonitoringSignificant ||
                            [LocationManager sharedInstance].monitoring == LocationMonitoringMove ||
                            [Settings boolForKey:@"allowremotelocation_preference"]) {
                            [self publishLocation:[LocationManager sharedInstance].location trigger:@"r"];
                        }

                    } else if ([@"reportSteps" saveEqual:dictionary[@"action"]]) {
                        [self stepsFrom:[NSNumber saveCopy:dictionary[@"from"]]
                                     to:[NSNumber saveCopy:dictionary[@"to"]]];

                    } else if ([@"waypoints" saveEqual:dictionary[@"action"]]) {
                        [self waypoints];

                    } else if ([@"action" saveEqual:dictionary[@"action"]]) {
                        NSString *content = [NSString saveCopy:dictionary[@"content"]];
                        NSString *url = [NSString saveCopy:dictionary[@"url"] ];
                        NSString *notificationMessage = [NSString saveCopy:dictionary[@"notification"]];
                        NSNumber *external = [NSNumber saveCopy:dictionary[@"extern"]];

                        [Settings setString:content forKey:SETTINGS_ACTION];
                        [Settings setString:url forKey:SETTINGS_ACTIONURL];
                        [Settings setBool:external.boolValue forKey:SETTINGS_ACTIONEXTERN];

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

                    } else if ([@"setWaypoints" saveEqual:dictionary[@"action"]]) {
                        NSDictionary *payload = [NSDictionary saveCopy:dictionary[@"payload"]];
                        NSDictionary *waypoints = [NSDictionary saveCopy:dictionary[@"waypoints"]];
                        if (waypoints && [waypoints isKindOfClass:[NSDictionary class]]) {
                            [Settings waypointsFromDictionary:waypoints];
                        } else if (payload && [payload isKindOfClass:[NSDictionary class]]) {
                            [Settings waypointsFromDictionary:payload];
                        }

                    } else if ([@"setConfiguration" saveEqual:dictionary[@"action"]]) {
                        NSDictionary *payload = [NSDictionary saveCopy:dictionary[@"payload"]];
                        NSDictionary *configuration = [NSDictionary saveCopy:dictionary[@"configuration"]];
                        if (configuration && [configuration isKindOfClass:[NSDictionary class]]) {
                            [Settings fromDictionary:configuration];
                        } else if (payload && [payload isKindOfClass:[NSDictionary class]]) {
                            [Settings fromDictionary:payload];
                        }
                        self.configLoad = [NSDate date];
                        [self performSelectorOnMainThread:@selector(reconnect) withObject:nil waitUntilDone:NO];

                    } else {
                        DDLogVerbose(@"unknown action %@", dictionary[@"action"]);
                    }
                }
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
                                                               topic:[[Settings theGeneralTopic] stringByAppendingString:@"/step"]
                                                                 qos:[Settings intForKey:@"qos_preference"]
                                                              retain:NO];
                                       });
                                   }];
}

#pragma actions

- (void)sendNow {
    DDLogVerbose(@"sendNow");
    CLLocation *location = [LocationManager sharedInstance].location;
    [self publishLocation:location trigger:@"u"];
    [[GeoHashing sharedInstance] newLocation:location];
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
}

- (void)publishLocation:(CLLocation *)location trigger:(NSString *)trigger {
    if (location &&
        CLLocationCoordinate2DIsValid(location.coordinate) &&
        location.coordinate.latitude != 0.0 &&
        location.coordinate.longitude != 0.0 &&
        [Settings validIds]) {

        int ignoreInaccurateLocations = [Settings intForKey:@"ignoreinaccuratelocations_preference"];
        DDLogVerbose(@"inaccurate location %fm/%dm",
                     location.horizontalAccuracy, ignoreInaccurateLocations);

        if (ignoreInaccurateLocations == 0 || location.horizontalAccuracy < ignoreInaccurateLocations) {
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
    if ([Settings intForKey:@"mode"] == CONNECTION_MODE_HTTP) {
        self.connection.key = [Settings stringForKey:@"secret_preference"];
        [self.connection connectHTTP:[Settings stringForKey:@"url_preference"]
                                auth:[Settings theMqttAuth]
                                user:[Settings theMqttUser]
                                pass:[Settings theMqttPass]];

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
        NSArray *subscriptions = [[NSArray alloc] init];
        if ([Settings boolForKey:@"sub"]) {
            subscriptions = [[Settings theSubscriptions] componentsSeparatedByCharactersInSet:
                             [NSCharacterSet whitespaceCharacterSet]];
        }

        self.connection.subscriptions = subscriptions;
        self.connection.subscriptionQos = subscriptionQos;

        NSMutableDictionary *json = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                    @"tst": [NSString stringWithFormat:@"%.0f", [NSDate date].timeIntervalSince1970],
                                                                                    @"_type": @"lwt"}];
        self.connection.key = [Settings stringForKey:@"secret_preference"];

        [self.connection connectTo:[Settings theHost]
                              port:[Settings intForKey:@"port_preference"]
                                ws:[Settings boolForKey:@"ws_preference"]
                               tls:[Settings boolForKey:@"tls_preference"]
                   protocolVersion:[Settings sharedInstance].protocol
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

