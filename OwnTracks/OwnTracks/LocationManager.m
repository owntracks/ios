//
//  LocationManager.m
//  OwnTracks
//
//  Created by Christoph Krey on 21.10.14.
//  Copyright © 2014-2025  OwnTracks. All rights reserved.
//

#import "LocationManager.h"
#import "SauronSharedDefaults.h"
#import "OwnTracksAppDelegate.h"
#import "CoreData.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface LocationManager()
@property (strong, nonatomic) CLLocationManager *manager;
@property (strong, nonatomic) CLLocation *lastUsedLocation;
@property (strong, nonatomic) CLLocation *lastLocationWithMovement;
@property (strong, nonatomic) NSTimer *activityTimer;
@property (strong, nonatomic) NSMutableSet *pendingRegionEvents;
- (void)holdDownExpired:(NSTimer *)timer;

@property (strong, nonatomic) NSMutableDictionary *insideBeaconRegions;
@property (strong, nonatomic) NSMutableDictionary *insideCircularRegions;
@property (strong, nonatomic) NSMutableArray *rangedBeacons;
@property (strong, nonatomic) NSTimer *backgroundTimer;
@property (strong, nonatomic) NSUserDefaults *sharedUserDefaults;
@property (nonatomic) BOOL awaitingFreshWakeupLocation;
@property (nonatomic) BOOL requestedFreshWakeupLocation;
@property (strong, nonatomic) NSDate *freshWakeupRequestedAt;

@property (nonatomic) CLAuthorizationStatus locationManagerAuthorizationStatus;

@property (nonatomic) CMAuthorizationStatus altimeterAuthorizationStatus;
@property (nonatomic) BOOL altimeterIsRelativeAltitudeAvailable;
@property (strong, nonatomic) CMAltimeter *altimeter;
@property (strong, nonatomic) CMAltitudeData *altitudeData;

@property (nonatomic) CMAuthorizationStatus motionActivityManagerAuthorizationStatus;
@property (nonatomic) BOOL motionActivityManagerIsActivityAvailable;
@property (strong, nonatomic) CMMotionActivityManager *motionActivityManager;
@property (strong, nonatomic) CMMotionActivity *motionActivity;

@end

@interface PendingRegionEvent : NSObject
@property (strong, nonatomic) CLRegion *region;
@property (strong, nonatomic) NSTimer *holdDownTimer;

@end

#define BACKGROUND_STOP_AFTER 5.0 // seconds
#define ASSUME_NO_MOTION 0.05 // meters per second (0.05 m/sec is 180 m/hour)
static const NSTimeInterval kWakeupLocationMaxAge = 30.0; // seconds
static const CLLocationAccuracy kWakeupLocationMaxHorizontalAccuracy = 200.0; // meters

@implementation PendingRegionEvent

+ (PendingRegionEvent *)holdDown:(CLRegion *)region
for:(NSTimeInterval)interval
to:(id)to {
    PendingRegionEvent *p = [[PendingRegionEvent alloc] init];
    p.region = region;
    p.holdDownTimer = [NSTimer timerWithTimeInterval:interval
                                              target:to
                                            selector:@selector(holdDownExpired:)
                                            userInfo:p
                                             repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:p.holdDownTimer forMode:NSRunLoopCommonModes];
    return p;
}

@end

@implementation LocationManager
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
static LocationManager *theInstance = nil;

+ (LocationManager *)sharedInstance {
    if (theInstance == nil) {
        theInstance = [[LocationManager alloc] init];
    }
    return theInstance;
}

- (instancetype)init {
    self = [super init];
    
    self.manager = [[CLLocationManager alloc] init];
    self.manager.delegate = self;
    
    self.altimeter = [[CMAltimeter alloc] init];
    self.motionActivityManager = [[CMMotionActivityManager alloc] init];
    
    self.insideBeaconRegions = [[NSMutableDictionary alloc] init];
    self.insideCircularRegions = [[NSMutableDictionary alloc] init];
    self.rangedBeacons = [[NSMutableArray alloc] init];
    self.lastUsedLocation = [[CLLocation alloc] initWithLatitude:0 longitude:0];
    self.lastLocationWithMovement = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(0.0, 0.0)
                                                                  altitude:(0.0)
                                                        horizontalAccuracy:-1.0
                                                          verticalAccuracy:-1.0
                                                                 timestamp:[NSDate date]];
    self.pendingRegionEvents = [[NSMutableSet alloc] init];
    
    [self authorize];
    
    [[NSNotificationCenter defaultCenter]
     addObserverForName:UIApplicationWillEnterForegroundNotification
     object:nil
     queue:nil
     usingBlock:^(NSNotification *note){
        DDLogVerbose(@"[LocationManager] UIApplicationWillEnterForegroundNotification");
        [self syncMonitoringFromSharedDefaults];
    }];
    [[NSNotificationCenter defaultCenter]
     addObserverForName:UIApplicationDidBecomeActiveNotification
     object:nil
     queue:nil
     usingBlock:^(NSNotification *note){
        DDLogVerbose(@"[LocationManager] UIApplicationDidBecomeActiveNotification");
        [self wakeup];
    }];
    [[NSNotificationCenter defaultCenter]
     addObserverForName:UIApplicationWillResignActiveNotification
     object:nil
     queue:nil
     usingBlock:^(NSNotification *note){
        DDLogVerbose(@"[LocationManager] UIApplicationWillResignActiveNotification");
        [self sleep];
    }];
    [[NSNotificationCenter defaultCenter]
     addObserverForName:UIApplicationWillTerminateNotification
     object:nil
     queue:nil
     usingBlock:^(NSNotification *note){
        DDLogVerbose(@"[LocationManager] UIApplicationWillTerminateNotification");
        [self stop];
    }];
    
    self.sharedUserDefaults = SauronSharedDefaults();
    [self.sharedUserDefaults addObserver:self forKeyPath:@"monitoring"
                                 options:NSKeyValueObservingOptionNew
                                 context:nil];
    [self.sharedUserDefaults addObserver:self forKeyPath:@"sendNow"
                                 options:NSKeyValueObservingOptionNew
                                 context:nil];
    [self.sharedUserDefaults addObserver:self forKeyPath:@"poi"
                                 options:NSKeyValueObservingOptionNew
                                 context:nil];
    [self.sharedUserDefaults addObserver:self forKeyPath:@"tag"
                                 options:NSKeyValueObservingOptionNew
                                 context:nil];

    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"monitoring"]) {
        NSUserDefaults *shared = object;
        [self applySharedMonitoring:[shared integerForKey:@"monitoring"] reason:@"KVO"];
    } else if ([keyPath isEqualToString:@"sendNow"]) {
        OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [ad sendNow:self.location withPOI:nil withImage:nil withImageName:nil];
    } else if ([keyPath isEqualToString:@"poi"]) {
        NSUserDefaults *shared = object;
        NSString *poi = [shared stringForKey:@"poi"];
        OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [ad sendNow:self.location withPOI:poi withImage:nil withImageName:nil];
    } else if ([keyPath isEqualToString:@"tag"]) {
        NSUserDefaults *shared = object;
        NSString *tag = [shared stringForKey:@"tag"];
        if (tag && tag.length) {
            [[NSUserDefaults standardUserDefaults] setObject:tag forKey:@"tag"];
        } else {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"tag"];
        }
    }
}

- (void)applySharedMonitoring:(NSInteger)monitoring reason:(NSString *)reason {
    if (monitoring == self.monitoring) {
        return;
    }
    DDLogInfo(@"[LocationManager] monitoring %ld -> %ld from shared app group (%@)",
              (long)self.monitoring, (long)monitoring, reason);
    self.monitoring = monitoring;
    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    [Settings setInt:(int)[LocationManager sharedInstance].monitoring
              forKey:@"monitoring_preference" inMOC:moc];
    [CoreData.sharedInstance sync:moc];
}

- (void)syncMonitoringFromSharedDefaults {
    // KVO on the shared app group only reaches a live process. A Siri shortcut
    // fired while the app was suspended or terminated leaves the new value
    // sitting in the container with nobody listening, and the next launch would
    // overwrite it from Core Data. So reconcile explicitly at launch and on
    // every foreground.
    id value = [self.sharedUserDefaults objectForKey:@"monitoring"];
    if (![value isKindOfClass:[NSNumber class]]) {
        // Absent is not the same as 0/Manual - never apply a missing key.
        return;
    }
    [self applySharedMonitoring:((NSNumber *)value).integerValue reason:@"foreground sync"];
}

- (void)start {
    DDLogVerbose(@"[LocationManager] start");
    [self authorize];
    
    self.altimeterAuthorizationStatus = [CMAltimeter authorizationStatus];
    self.altimeterIsRelativeAltitudeAvailable = [CMAltimeter isRelativeAltitudeAvailable];
    DDLogInfo(@"[LocationManager] CMAltimeter status=%ld, available=%d",
              (long)self.altimeterAuthorizationStatus,
              self.altimeterIsRelativeAltitudeAvailable);
    
    if (self.altimeterIsRelativeAltitudeAvailable &&
        (self.altimeterAuthorizationStatus == CMAuthorizationStatusNotDetermined ||
         self.altimeterAuthorizationStatus == CMAuthorizationStatusAuthorized)) {
        DDLogVerbose(@"[LocationManager] startRelativeAltitudeUpdatesToQueue");
        [self.altimeter startRelativeAltitudeUpdatesToQueue:[NSOperationQueue mainQueue]
                                                withHandler:^(CMAltitudeData *altitudeData, NSError *error) {
            DDLogVerbose(@"[LocationManager] altitudeData %@ error %@", altitudeData, error);
            self.altitudeData = altitudeData;
        }];
    }
    
    self.motionActivityManagerAuthorizationStatus = [CMMotionActivityManager authorizationStatus];
    self.motionActivityManagerIsActivityAvailable = [CMMotionActivityManager isActivityAvailable];
    DDLogInfo(@"[LocationManager] CMMotionActivityManager status=%ld, available=%d",
              (long)self.motionActivityManagerAuthorizationStatus,
              self.motionActivityManagerIsActivityAvailable);
    
    if (self.motionActivityManagerIsActivityAvailable &&
        (self.motionActivityManagerAuthorizationStatus == CMAuthorizationStatusNotDetermined ||
         self.motionActivityManagerAuthorizationStatus == CMAuthorizationStatusAuthorized)) {
        DDLogVerbose(@"[LocationManager] startActivityUpdatesToQueue");
        [self.motionActivityManager startActivityUpdatesToQueue:[NSOperationQueue mainQueue]
                                                    withHandler:^(CMMotionActivity * _Nullable activity) {
            DDLogVerbose(@"[LocationManager] activity %@", activity);
            self.motionActivity = activity;
        }];
    }
}

- (void)wakeup {
    DDLogVerbose(@"[LocationManager] wakeup backgroundWakeup=%d", self.backgroundWakeup);
    [self authorize];
    if (self.monitoring == LocationMonitoringMove && !self.backgroundWakeup) {
        /*
         * Only restart the activity timer when we are in active (non-background-wakeup)
         * Move mode. In backgroundWakeup mode, starting the timer would keep the
         * background process alive and defeat the passive-tracking strategy.
         */
        [self.activityTimer invalidate];
        if (self.minTime > 0.0) {
            self.activityTimer = [NSTimer timerWithTimeInterval:self.minTime
                                                         target:self
                                                       selector:@selector(activityTimer:)
                                                       userInfo:Nil
                                                        repeats:YES];
            [[NSRunLoop currentRunLoop] addTimer:self.activityTimer
                                         forMode:NSRunLoopCommonModes];
        }
    }
    for (CLRegion *region in self.manager.monitoredRegions) {
        DDLogVerbose(@"[LocationManager] requestStateForRegion %@", region.identifier);
        [self.manager requestStateForRegion:region];
    }
    if (self.monitoring == LocationMonitoringSignificant) {
        [self.manager requestLocation];
    }
    [self startBackgroundTimer];
}

- (void)authorize {
    self.locationManagerAuthorizationStatus = self.manager.authorizationStatus;
    DDLogVerbose(@"[LocationManager] authorizationStatus=%d",
                 self.locationManagerAuthorizationStatus);
    if (self.locationManagerAuthorizationStatus == kCLAuthorizationStatusNotDetermined) {
        [self.manager requestAlwaysAuthorization];
    }
}

- (void)sleep {
    DDLogVerbose(@"[LocationManager] sleep");
    for (CLBeaconIdentityConstraint *beaconIdentityConstraint in self.manager.rangedBeaconConstraints) {
        [self.manager stopRangingBeaconsSatisfyingConstraint:beaconIdentityConstraint];
    }
    if (self.monitoring != LocationMonitoringMove) {
        [self.activityTimer invalidate];
    }
}

- (void)stop {
    DDLogVerbose(@"[LocationManager] stop");
    
    if ([CMAltimeter isRelativeAltitudeAvailable]) {
        DDLogVerbose(@"[LocationManager] stopRelativeAltitudeUpdates");
        [self.altimeter stopRelativeAltitudeUpdates];
    }
    
    if ([CMMotionActivityManager isActivityAvailable]) {
        DDLogVerbose(@"[LocationManager] stopActivityUpdates");
        [self.motionActivityManager stopActivityUpdates];
    }
}

- (void)startRegion:(CLRegion *)region {
    if (region) {
        [self.manager startMonitoringForRegion:region];
    }
}

- (void)stopRegion:(CLRegion *)region {
    if (region) {
        [self removeHoldDown:region];
        [self.manager stopMonitoringForRegion:region];
        [self.insideBeaconRegions removeObjectForKey:region.identifier];
        [self.insideCircularRegions removeObjectForKey:region.identifier];
    }
}

- (void)resetRegions {
    for (CLRegion *region in self.manager.monitoredRegions) {
        [self stopRegion:region];
    }
}

- (BOOL)insideBeaconRegion {
    return (self.insideBeaconRegions.count != 0);
}

- (BOOL)insideBeaconRegion:(NSString *)identifier {
    NSNumber *number = (self.insideBeaconRegions)[identifier];
    return (number ? number.boolValue : false);
}

- (BOOL)insideCircularRegion {
    return (self.insideCircularRegions.count != 0);
}

- (BOOL)insideCircularRegion:(NSString *)identifier {
    NSNumber *number = (self.insideCircularRegions)[identifier];
    return (number ? number.boolValue : false);
}

- (CLLocation *)location {
    if (self.manager.location) {
        return self.manager.location;
    }
    DDLogVerbose(@"[LocationManager] location == nil");
    return self.lastUsedLocation;
}

- (void)setMinDist:(double)minDist {
    _minDist = minDist;
    self.monitoring = self.monitoring;
}

- (void)setMinTime:(double)minTime {
    _minTime = minTime;
    self.monitoring = self.monitoring;
}

- (void)setMonitoring:(LocationMonitoring)monitoring {
    DDLogInfo(@"[LocationManager] set monitoring=%ld", (long)monitoring);
    if (monitoring != LocationMonitoringMove &&
        monitoring != LocationMonitoringManual &&
        monitoring != LocationMonitoringQuiet &&
        monitoring != LocationMonitoringSignificant) {
        monitoring = LocationMonitoringQuiet;
        DDLogWarn(@"[LocationManager] monitoring set to %ld", (long)monitoring);
    }
    _monitoring = monitoring;
    self.manager.pausesLocationUpdatesAutomatically = NO;
    self.manager.allowsBackgroundLocationUpdates = TRUE;
    
    switch (monitoring) {
        case LocationMonitoringMove:
            [self.activityTimer invalidate];

            if (self.backgroundWakeup) {
                /*
                 * The app was launched in the background by a significant location change
                 * or geofence event after having been terminated by the OS.
                 *
                 * DO NOT call startUpdatingLocation here. Doing so would keep the
                 * background process alive until the OS kills it again, creating a
                 * kill-wakeup-kill loop without the user ever regaining full tracking.
                 *
                 * Instead, use passive mode: keep SLC + visit monitoring active so iOS
                 * can continue to wake us for future events. The triggering SLC/geofence
                 * event is delivered via the existing delegate callbacks (didUpdateLocations,
                 * didEnterRegion, didExitRegion) without needing startUpdatingLocation.
                 *
                 * Full continuous tracking resumes in applicationDidBecomeActive: when
                 * the user brings the app to foreground.
                 */
                DDLogInfo(@"[LocationManager] Move mode: background wakeup - passive tracking only");
                [self recordBackgroundWakeup];
                self.awaitingFreshWakeupLocation = NO;
                self.requestedFreshWakeupLocation = NO;
                self.freshWakeupRequestedAt = nil;
                [self.manager startMonitoringSignificantLocationChanges];
                [self.manager startMonitoringVisits];
                DDLogInfo(@"[LocationManager] Move/passive: SLC started ✓, Visits started ✓, "
                          @"startUpdatingLocation SUPPRESSED (background wakeup — avoiding kill loop). "
                          @"applicationState=%ld",
                          (long)[UIApplication sharedApplication].applicationState);
            } else {
                /*
                 * Active tracking: start continuous high-accuracy updates.
                 * Also keep SLC monitoring active as a safety net: if the OS terminates
                 * this process unexpectedly (memory pressure), SLC ensures iOS will wake
                 * the app again so it can resume tracking.
                 */
                self.manager.distanceFilter = kCLDistanceFilterNone;
                self.manager.desiredAccuracy = kCLLocationAccuracyBest;
                [self.manager startUpdatingLocation];
                [self.manager startMonitoringSignificantLocationChanges];
                [self.manager stopMonitoringVisits];
                DDLogInfo(@"[LocationManager] Move/active: startUpdatingLocation ✓, SLC safety-net ✓. "
                          @"applicationState=%ld",
                          (long)[UIApplication sharedApplication].applicationState);

                if (self.minTime > 0.0) {
                    self.activityTimer = [NSTimer timerWithTimeInterval:self.minTime
                                                                 target:self
                                                               selector:@selector(activityTimer:)
                                                               userInfo:Nil
                                                                repeats:YES];
                    [[NSRunLoop currentRunLoop] addTimer:self.activityTimer
                                                 forMode:NSRunLoopCommonModes];
                }
            }
            break;

        case LocationMonitoringSignificant:
            [self.activityTimer invalidate];
            [self.manager stopUpdatingLocation];
            [self.manager startMonitoringSignificantLocationChanges];
            [self.manager startMonitoringVisits];
            if (self.backgroundWakeup) {
                [self recordBackgroundWakeup];
                self.awaitingFreshWakeupLocation = NO;
                self.requestedFreshWakeupLocation = NO;
                self.freshWakeupRequestedAt = nil;
            }
            break;

        case LocationMonitoringManual:
        case LocationMonitoringQuiet:
        default:
            [self.activityTimer invalidate];
            [self.manager stopUpdatingLocation];
            [self.manager stopMonitoringSignificantLocationChanges];
            [self.manager stopMonitoringVisits];
            break;
    }
    NSUserDefaults *shared = SauronSharedDefaults();
    [shared setInteger:self.monitoring forKey:@"monitoring"];
}

- (void)setRanging:(BOOL)ranging {
    DDLogVerbose(@"[LocationManager] set ranging=%d", ranging);
    _ranging = ranging;
    
    if (!ranging) {
        for (CLBeaconIdentityConstraint *beaconIdentityConstraint in self.manager.rangedBeaconConstraints) {
            DDLogVerbose(@"[LocationManager] stopRangingBeaconsSatisfyingConstraint %@",
                         [NSString stringWithFormat:@"%@:%@:%@",
                          beaconIdentityConstraint.UUID.UUIDString,
                          beaconIdentityConstraint.major,
                          beaconIdentityConstraint.minor]);
            [self.manager stopRangingBeaconsSatisfyingConstraint:beaconIdentityConstraint];
        }
    }
    for (CLRegion *region in self.manager.monitoredRegions) {
        DDLogVerbose(@"[LocationManager] requestStateForRegion %@", region.identifier);
        [self.manager requestStateForRegion:region];
    }
}

- (void)activityTimer:(NSTimer *)timer {
    DDLogInfo(@"[LocationManager] activityTimer fired after %f", self.minTime);
    CLLocation *location = self.manager.location;
    if (location) {
        self.lastUsedLocation = location;
        [self.delegate timerLocation:location];
    } else {
        DDLogWarn(@"[LocationManager] activityTimer found no location");
    }
}

/*
 *
 * Delegate
 *
 */

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    DDLogInfo(@"[LocationManager] didChangeAuthorizationStatus to %d",
              manager.authorizationStatus);
    self.locationManagerAuthorizationStatus = manager.authorizationStatus;
    if (manager.authorizationStatus != kCLAuthorizationStatusAuthorizedAlways) {
        [self showError];
    }
}

- (void)showError {
    CLAuthorizationStatus status = self.manager.authorizationStatus;
    switch (status) {
        case kCLAuthorizationStatusAuthorizedAlways:
            break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            [NavigationController alert:@"LocationManager"
                                message:
                 NSLocalizedString(@"App is not allowed to use location services in background",
                                   @"Location Manager error message")
                                    url:UIApplicationOpenSettingsURLString];
            DDLogInfo(@"[LocationManager] %@", @"App is not allowed to use location services in background");
            break;
        case kCLAuthorizationStatusNotDetermined:
            [NavigationController alert:@"LocationManager"
                                message:
                 NSLocalizedString(@"App is not allowed to use location services yet",
                                   @"Location Manager error message")
            ];
            DDLogInfo(@"[LocationManager] %@", @"App is not allowed to use location services yet");
            break;
        case kCLAuthorizationStatusDenied:
            [NavigationController alert:@"LocationManager"
                                message:
                 NSLocalizedString(@"App is not allowed to use location services",
                                   @"Location Manager error message")
            ];
            DDLogInfo(@"[LocationManager] %@", @"App is not allowed to use location services");
            break;
        case kCLAuthorizationStatusRestricted:
            [NavigationController alert:@"LocationManager"
                                message:
                 NSLocalizedString(@"App use of location services is restricted",
                                   @"Location Manager error message")
            ];
            DDLogInfo(@"[LocationManager] %@", @"App use of location services is restricted");
            break;
        default:
            [NavigationController alert:@"LocationManager"
                                message:
                 NSLocalizedString(@"App use of location services is unclear",
                                   @"Location Manager error message")
            ];
            DDLogInfo(@"[LocationManager] %@", @"App use of location services is unclear");
            break;
    }
        
}

+ (NSString *)CLLocationText:(CLLocation *)location {
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;

    return [NSString stringWithFormat:@"%g%g(±%.0f,%.2f,%.2f)@%@",
            location.coordinate.longitude,
            location.coordinate.latitude,
            location.horizontalAccuracy,
            location.speed,
            location.course,
            [formatter stringFromDate:location.timestamp]];
}


/*
 * Background wakeup event recording.
 *
 * Stores the last 50 wakeup events in the shared app-group NSUserDefaults so
 * they survive force-quit and are visible in the Status screen after the user
 * reopens the app.
 */

static NSString * const kWakeupEventsKey = @"backgroundWakeupEvents";
static const NSUInteger kMaxWakeupEvents = 50;

- (void)recordBackgroundWakeup {
    NSISO8601DateFormatter *fmt = [[NSISO8601DateFormatter alloc] init];
    fmt.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSDictionary *event = @{
        @"timestamp": [fmt stringFromDate:[NSDate date]],
        @"lat":       @(0.0),
        @"lon":       @(0.0),
        @"accuracy":  @(-1.0)
    };
    NSMutableArray *events = [[self.sharedUserDefaults arrayForKey:kWakeupEventsKey] mutableCopy]
                              ?: [NSMutableArray array];
    [events insertObject:event atIndex:0];
    if (events.count > kMaxWakeupEvents) {
        [events removeObjectsInRange:NSMakeRange(kMaxWakeupEvents, events.count - kMaxWakeupEvents)];
    }
    [self.sharedUserDefaults setObject:[events copy] forKey:kWakeupEventsKey];
    DDLogInfo(@"[LocationManager] recorded background wakeup event (%lu total)", (unsigned long)events.count);
}

- (void)updateLastWakeupEventWithLocation:(CLLocation *)location {
    NSMutableArray *events = [[self.sharedUserDefaults arrayForKey:kWakeupEventsKey] mutableCopy];
    if (!events.count) return;
    NSDictionary *latest = events[0];
    if ([latest[@"accuracy"] doubleValue] >= 0) return; // already updated
    NSMutableDictionary *updated = [latest mutableCopy];
    updated[@"lat"]      = @(location.coordinate.latitude);
    updated[@"lon"]      = @(location.coordinate.longitude);
    updated[@"accuracy"] = @(location.horizontalAccuracy);
    events[0] = [updated copy];
    [self.sharedUserDefaults setObject:[events copy] forKey:kWakeupEventsKey];
    DDLogInfo(@"[LocationManager] updated background wakeup event with location %.4f,%.4f acc=%.0f",
              location.coordinate.latitude, location.coordinate.longitude, location.horizontalAccuracy);
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations {
    DDLogVerbose(@"[LocationManager] didUpdateLocations");
    
    int count = 0;
    for (CLLocation *location in locations) {
        count++;
        DDLogInfo(@"[LocationManager] Location#%d: Δs:%.0f/%.0f Δm:%.0f/%.0f Δs:%.0f %@ %@ %@",
                  count,
                  self.lastUsedLocation ? [location.timestamp timeIntervalSinceDate:self.lastUsedLocation.timestamp] : 0,
                  self.minTime,
                  self.lastUsedLocation ? [location distanceFromLocation:self.lastUsedLocation] : 0,
                  self.minDist,
                  [location.timestamp timeIntervalSinceDate:self.lastLocationWithMovement.timestamp],
                  [LocationManager CLLocationText:location],
                  self.lastUsedLocation ? [LocationManager CLLocationText:self.lastUsedLocation] : @"nil",
                  [LocationManager CLLocationText:self.lastLocationWithMovement]
        );
        
        if (location.speed > ASSUME_NO_MOTION) {
            self.lastLocationWithMovement = location;
        }
        
        if (self.backgroundWakeup) {
            BOOL fromFreshAcquisition = self.awaitingFreshWakeupLocation;
            NSTimeInterval age = -[location.timestamp timeIntervalSinceNow];
            BOOL hasValidAccuracy = location.horizontalAccuracy >= 0.0;
            BOOL isRecentEnough = age <= kWakeupLocationMaxAge;
            BOOL isAccurateEnough = hasValidAccuracy &&
                                    location.horizontalAccuracy <= kWakeupLocationMaxHorizontalAccuracy;
            BOOL isFreshEnoughForRequest = !fromFreshAcquisition ||
                                           !self.freshWakeupRequestedAt ||
                                           [location.timestamp timeIntervalSinceDate:self.freshWakeupRequestedAt] >= -2.0;

            DDLogInfo(@"[LocationManager] Location#%d backgroundWakeup source=%@ age=%.0fs acc=%.0fm "
                      @"appState=%ld relativeToLastUsed=%.0fs location=%@",
                      count,
                      fromFreshAcquisition ? @"fresh-acquisition" : @"slc-trigger",
                      age,
                      location.horizontalAccuracy,
                      (long)[UIApplication sharedApplication].applicationState,
                      self.lastUsedLocation
                          ? [location.timestamp timeIntervalSinceDate:self.lastUsedLocation.timestamp]
                          : 0.0,
                      [LocationManager CLLocationText:location]);

            if (!(isRecentEnough && isAccurateEnough && isFreshEnoughForRequest)) {
                DDLogInfo(@"[LocationManager] Location#%d REJECTED source=%@ reason="
                          @"recent=%d accurate=%d freshSinceRequest=%d age=%.0fs acc=%.0fm requestAt=%@",
                          count,
                          fromFreshAcquisition ? @"fresh-acquisition" : @"slc-trigger",
                          isRecentEnough,
                          isAccurateEnough,
                          isFreshEnoughForRequest,
                          age,
                          location.horizontalAccuracy,
                          self.freshWakeupRequestedAt);

                if (!fromFreshAcquisition && !self.requestedFreshWakeupLocation) {
                    self.requestedFreshWakeupLocation = YES;
                    self.awaitingFreshWakeupLocation = YES;
                    self.freshWakeupRequestedAt = [NSDate date];
                    DDLogInfo(@"[LocationManager] Location#%d requesting fresh location fix after SLC trigger",
                              count);
                    [self.manager requestLocation];
                }
                continue;
            }
            self.awaitingFreshWakeupLocation = NO;
            self.requestedFreshWakeupLocation = NO;
            self.freshWakeupRequestedAt = nil;
            // Skip distance filter: single-shot wakeup, no prior publish to compare against.
        } else {
            self.awaitingFreshWakeupLocation = NO;
            self.requestedFreshWakeupLocation = NO;
            self.freshWakeupRequestedAt = nil;
            if (self.lastUsedLocation &&
                [location.timestamp timeIntervalSinceDate:self.lastUsedLocation.timestamp] <= 0.0) {
                continue;
            }
            if (self.monitoring == LocationMonitoringMove &&
                self.lastUsedLocation &&
                [location distanceFromLocation:self.lastUsedLocation] < self.minDist) {
                continue;
            }
        }

        self.lastUsedLocation = location;
        if (self.backgroundWakeup) {
            DDLogInfo(@"[LocationManager] Location#%d delivered in BACKGROUND WAKEUP (passive SLC mode) "
                      @"appState=%ld",
                      count,
                      (long)[UIApplication sharedApplication].applicationState);
            [self updateLastWakeupEventWithLocation:location];
        }
        [self.delegate newLocation:location];
    }
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error {
    DDLogError(@"[LocationManager] didFailWithError %@ %@", error.localizedDescription, error.userInfo);
    // error
}

/*
 *
 * Regions
 *
 */
- (void)locationManager:(CLLocationManager *)manager
      didDetermineState:(CLRegionState)state
              forRegion:(CLRegion *)region {
    DDLogVerbose(@"[LocationManager] didDetermineState %ld %@", (long)state, region);
    
    if ([region isKindOfClass:[CLBeaconRegion class]]) {
        if (state == CLRegionStateInside) {
            (self.insideBeaconRegions)[region.identifier] = [NSNumber numberWithBool:TRUE];
            if (self.ranging) {
                CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
                CLBeaconIdentityConstraint *beaconIdentityConstraint;
                if (beaconRegion.major && beaconRegion.minor) {
                    beaconIdentityConstraint =
                    [[CLBeaconIdentityConstraint alloc] initWithUUID:beaconRegion.UUID
                                                               major:beaconRegion.major.intValue
                                                               minor:beaconRegion.minor.intValue];
                } else if (beaconRegion.major) {
                    beaconIdentityConstraint =
                    [[CLBeaconIdentityConstraint alloc] initWithUUID:beaconRegion.UUID
                                                               major:beaconRegion.major.intValue];
                } else {
                    beaconIdentityConstraint =
                    [[CLBeaconIdentityConstraint alloc] initWithUUID:beaconRegion.UUID];
                }
                [self.manager startRangingBeaconsSatisfyingConstraint:beaconIdentityConstraint];
            }
        } else {
            [self.insideBeaconRegions removeObjectForKey:region.identifier];
            CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
            CLBeaconIdentityConstraint *beaconIdentityConstraint;
            if (beaconRegion.major && beaconRegion.minor) {
                beaconIdentityConstraint =
                [[CLBeaconIdentityConstraint alloc] initWithUUID:beaconRegion.UUID
                                                           major:beaconRegion.major.intValue
                                                           minor:beaconRegion.minor.intValue];
            } else if (beaconRegion.major) {
                beaconIdentityConstraint =
                [[CLBeaconIdentityConstraint alloc] initWithUUID:beaconRegion.UUID
                                                           major:beaconRegion.major.intValue];
            } else {
                beaconIdentityConstraint =
                [[CLBeaconIdentityConstraint alloc] initWithUUID:beaconRegion.UUID];
            }
            [self.manager stopRangingBeaconsSatisfyingConstraint:beaconIdentityConstraint];
            
        }
    }
    
    if ([region isKindOfClass:[CLCircularRegion class]]) {
        if (state == CLRegionStateInside) {
            (self.insideCircularRegions)[region.identifier] = [NSNumber numberWithBool:TRUE];
        } else {
            [self.insideCircularRegions removeObjectForKey:region.identifier];
        }
    }
    [self.delegate regionState:region inside:(state == CLRegionStateInside)];
}

- (void)locationManager:(CLLocationManager *)manager
         didEnterRegion:(CLRegion *)region {
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    DDLogInfo(@"[LocationManager] didEnterRegion %@ | appState=%@ | backgroundWakeup=%d | "
              @"wakeup trigger: GEOFENCE ENTER",
              region,
              state == UIApplicationStateBackground ? @"BACKGROUND" :
              state == UIApplicationStateActive     ? @"FOREGROUND" : @"INACTIVE",
              self.backgroundWakeup);

    if (![self removeHoldDown:region]) {
        [self locationManager:manager didDetermineState:CLRegionStateInside forRegion:region];
        [self.delegate regionEvent:region enter:YES];
    }
}

- (void)locationManager:(CLLocationManager *)manager
          didExitRegion:(CLRegion *)region {
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    DDLogInfo(@"[LocationManager] didExitRegion %@ | appState=%@ | backgroundWakeup=%d | "
              @"wakeup trigger: GEOFENCE EXIT",
              region,
              state == UIApplicationStateBackground ? @"BACKGROUND" :
              state == UIApplicationStateActive     ? @"FOREGROUND" : @"INACTIVE",
              self.backgroundWakeup);
    
    if ([region.identifier hasPrefix:@"-"]) {
        [self removeHoldDown:region];
        [self.pendingRegionEvents addObject:[PendingRegionEvent holdDown:region for:3.0 to:self]];
    } else {
        [self locationManager:manager didDetermineState:CLRegionStateOutside forRegion:region];
        [self.delegate regionEvent:region enter:NO];
    }
}

- (BOOL)removeHoldDown:(CLRegion *)region {
    DDLogInfo(@"[LocationManager] removeHoldDown %@ [%lu]", region.identifier, (unsigned long)self.pendingRegionEvents.count);
    
    for (PendingRegionEvent *p in self.pendingRegionEvents) {
        if (p.region == region) {
            DDLogVerbose(@"[LocationManager] holdDownInvalidated %@", region.identifier);
            [p.holdDownTimer invalidate];
            p.region = nil;
            [self.pendingRegionEvents removeObject:p];
            return TRUE;
        }
    }
    return FALSE;
}

- (void)holdDownExpired:(NSTimer *)timer {
    DDLogInfo(@"[LocationManager] holdDownExpired %@", timer.userInfo);
    if ([timer.userInfo isKindOfClass:[PendingRegionEvent class]]) {
        PendingRegionEvent *p = (PendingRegionEvent *)timer.userInfo;
        DDLogVerbose(@"[LocationManager] holdDownExpired %@", p.region.identifier);
        [self.delegate regionEvent:p.region enter:NO];
        [self removeHoldDown:p.region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    DDLogVerbose(@"[LocationManager] didStartMonitoringForRegion %@", region);
    [self.manager requestStateForRegion:region];
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    DDLogError(@"[LocationManager] monitoringDidFailForRegion %@ %@ %@", region, error.localizedDescription, error.userInfo);
    for (CLRegion *monitoredRegion in manager.monitoredRegions) {
        DDLogError(@"[LocationManager] monitoredRegion: %@", monitoredRegion);
    }
    
    if ((error.domain != kCLErrorDomain || error.code != 5) && [manager.monitoredRegions containsObject:region]) {
        // error
    }
    
}

/*
 *
 * Beacons
 *
 */
- (void)locationManager:(CLLocationManager *)manager
didFailRangingBeaconsForConstraint:(CLBeaconIdentityConstraint *)beaconConstraint
                  error:(NSError *)error {
    DDLogError(@"[LocationManager] didFailRangingBeaconsForConstraint %@ %@ %@",
                 beaconConstraint, error.localizedDescription, error.userInfo);
    
}

- (void)locationManager:(CLLocationManager *)manager
        didRangeBeacons:(NSArray<CLBeacon *> *)beacons
   satisfyingConstraint:(CLBeaconIdentityConstraint *)beaconConstraint {
    DDLogInfo(@"[LocationManager] didRangeBeacons %@ satisfyingContraint %@",
                 beacons, beaconConstraint);
    for (CLBeacon *beacon in beacons) {
        if (beacon.proximity != CLProximityUnknown) {
            CLBeacon *foundBeacon = nil;
            for (CLBeacon *rangedBeacon in self.rangedBeacons) {
                uuid_t rangedBeaconUUID;
                uuid_t beaconUUID;
                [rangedBeacon.UUID getUUIDBytes:rangedBeaconUUID];
                [beacon.UUID getUUIDBytes:beaconUUID];
                
                if (uuid_compare(rangedBeaconUUID, beaconUUID) == 0 &&
                    (rangedBeacon.major).intValue == (beacon.major).intValue &&
                    (rangedBeacon.minor).intValue == (beacon.minor).intValue) {
                    foundBeacon = rangedBeacon;
                    break;
                }
            }
            if (foundBeacon == nil) {
                [self.delegate beaconInRange:beacon beaconConstraint:beaconConstraint];
                [self.rangedBeacons addObject:beacon];
            } else {
                //if (foundBeacon.proximity != beacon.proximity) {
                //if (foundBeacon.rssi != beacon.rssi) {
                if (fabs(foundBeacon.accuracy / beacon.accuracy - 1) > 0.2) {
                    [self.delegate beaconInRange:beacon beaconConstraint:beaconConstraint];
                    [self.rangedBeacons removeObject:foundBeacon];
                    [self.rangedBeacons addObject:beacon];
                }
            }
        }
    }
    
}

/*
 *
 * Deferred Updates
 *
 */
- (void)locationManager:(CLLocationManager *)manager didFinishDeferredUpdatesWithError:(NSError *)error {
    //
}

- (void)locationManagerDidPauseLocationUpdates:(CLLocationManager *)manager {
    //
}

- (void)locationManagerDidResumeLocationUpdates:(CLLocationManager *)manager {
    //
}

/*
 *
 * Heading
 *
 */
- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
    // we don't use heading
}

- (BOOL)locationManagerShouldDisplayHeadingCalibration:(CLLocationManager *)manager {
    // we don't use heading
    return false;
}

/*
 *
 * Visits
 *
 */
- (void)locationManager:(CLLocationManager *)manager didVisit:(CLVisit *)visit {
    DDLogInfo(@"[LocationManager] didVisit %g,%g ha=%g a=%@ d=%@",
                 visit.coordinate.latitude,
                 visit.coordinate.longitude,
                 visit.horizontalAccuracy,
                 visit.arrivalDate,
                 visit.departureDate);
    
    if (manager.location) {
        [self.delegate visitLocation:manager.location];
    }
}


- (void)startBackgroundTimer {
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    DDLogInfo(@"[LocationManager] startBackgroundTimer called: applicationState=%ld (%@)",
              (long)state,
              state == UIApplicationStateBackground ? @"BACKGROUND - timer will start" :
              state == UIApplicationStateActive     ? @"FOREGROUND - timer suppressed" :
                                                     @"INACTIVE - timer suppressed");
    if (state == UIApplicationStateBackground) {
        if (!self.backgroundTimer || !self.backgroundTimer.isValid) {
            self.backgroundTimer = [NSTimer scheduledTimerWithTimeInterval:BACKGROUND_STOP_AFTER
                                                                    target:self
                                                                  selector:@selector(stopInBackground)
                                                                  userInfo:nil repeats:FALSE];
        }
    }
}

- (void)stopInBackground {
    DDLogInfo(@"[LocationManager] stopInBackground");
    self.backgroundTimer = nil;
    [self sleep];
}

@end
