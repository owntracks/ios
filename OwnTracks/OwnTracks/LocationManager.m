//
//  LocationManager.m
//  OwnTracks
//
//  Created by Christoph Krey on 21.10.14.
//  Copyright © 2014-2025  OwnTracks. All rights reserved.
//

#import "LocationManager.h"
#import "OwnTracksAppDelegate.h"
#import "CoreData.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface LocationManager()
@property (strong, nonatomic) CLLocationManager *manager;
@property (strong, nonatomic) CMAltimeter *altimeter;
@property (strong, nonatomic) CLLocation *lastUsedLocation;
@property (strong, nonatomic) NSTimer *activityTimer;
@property (strong, nonatomic) NSMutableSet *pendingRegionEvents;
@property (strong, nonatomic) NSMutableDictionary *insideBeaconRegions;
@property (strong, nonatomic) NSMutableDictionary *insideCircularRegions;
@property (strong, nonatomic) NSMutableArray *rangedBeacons;
@property (strong, nonatomic) NSTimer *backgroundTimer;
@property (strong, nonatomic) NSUserDefaults *sharedUserDefaults;
@property (readwrite, nonatomic) CLAuthorizationStatus locationManagerAuthorizationStatus;
@property (readwrite, nonatomic) CMAuthorizationStatus altimeterAuthorizationStatus;
@property (readwrite, nonatomic) BOOL altimeterIsRelativeAltitudeAvailable;

@end

@interface PendingRegionEvent : NSObject
@property (strong, nonatomic) CLRegion *region;
@property (strong, nonatomic) NSTimer *holdDownTimer;

@end

#define BACKGROUND_STOP_AFTER 5.0

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
    static LocationManager *sharedLocationManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLocationManager = [[self alloc] init];
    });
    return sharedLocationManager;
}

- (instancetype)init {
    self = [super init];
    
    self.manager = [[CLLocationManager alloc] init];
    self.manager.delegate = self;
    
    self.altimeter = [[CMAltimeter alloc] init];
    
    self.insideBeaconRegions = [[NSMutableDictionary alloc] init];
    self.insideCircularRegions = [[NSMutableDictionary alloc] init];
    self.rangedBeacons = [[NSMutableArray alloc] init];
    self.lastUsedLocation = [[CLLocation alloc] initWithLatitude:0 longitude:0];
    self.pendingRegionEvents = [[NSMutableSet alloc] init];
    self.pendingRegions = [[NSMutableArray alloc] init];
    self.isManagingRegions = NO;
    
    [self authorize];
    
    [[NSNotificationCenter defaultCenter]
     addObserverForName:UIApplicationWillEnterForegroundNotification
     object:nil
     queue:nil
     usingBlock:^(NSNotification *note){
        DDLogVerbose(@"[LocationManager] UIApplicationWillEnterForegroundNotification");
        //
    }];
    [[NSNotificationCenter defaultCenter]
     addObserverForName:UIApplicationWillResignActiveNotification
     object:nil
     queue:nil
     usingBlock:^(NSNotification *note){
        DDLogVerbose(@"[LocationManager] UIApplicationWillResignActiveNotification");
        [self sleep];
    }];

    
    self.sharedUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.org.owntracks.Owntracks"];

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
    if ([keyPath isEqualToString:@"sendNow"]) {
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

- (void)start {
    DDLogVerbose(@"[LocationManager] start");
    [self authorize];
    
    self.altimeterAuthorizationStatus = [CMAltimeter authorizationStatus];
    self.altimeterIsRelativeAltitudeAvailable = [CMAltimeter isRelativeAltitudeAvailable];
    DDLogVerbose(@"[LocationManager] CMAltimeter status=%ld, available=%d",
                 (long)self.altimeterAuthorizationStatus,
                 self.altimeterIsRelativeAltitudeAvailable);
    
    if (self.altimeterIsRelativeAltitudeAvailable &&
        (self.altimeterAuthorizationStatus == CMAuthorizationStatusNotDetermined ||
         self.altimeterAuthorizationStatus == CMAuthorizationStatusAuthorized)) {
        DDLogVerbose(@"[LocationManager] startRelativeAltitudeUpdatesToQueue");
        [self.altimeter startRelativeAltitudeUpdatesToQueue:[NSOperationQueue mainQueue]
                                                withHandler:^(CMAltitudeData *altitudeData, NSError *error) {
            DDLogVerbose(@"[LocationManager] altitudeData %@", altitudeData);
            self.altitude = altitudeData;
        }];
    }

}

- (void)wakeup {
    DDLogVerbose(@"[LocationManager] wakeup");
    [self authorize];

    //if (self.monitoring != LocationMonitoringMove) {
        //self.monitoring = LocationMonitoringMove;
       // [[NSUserDefaults standardUserDefaults] setInteger:LocationMonitoringMove forKey:@"monitoring_preference"];
      //  DDLogInfo(@"[LocationManager] wakeup: switched to LocationMonitoringMove");
    //}
    [[NSUserDefaults standardUserDefaults] setInteger:LocationMonitoringMove forKey:@"monitoring_preference"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // Manage regions when waking up
    [self manageRegions];

    // Optional: Force UI update
    [[NSNotificationCenter defaultCenter] postNotificationName:@"monitoringPreferenceChanged" object:nil];

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

    for (CLRegion *region in self.manager.monitoredRegions) {
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
    DDLogInfo(@"[LocationManager] stop called - app is terminating");
    DDLogInfo(@"[LocationManager] Current monitoring mode: %ld", (long)self.monitoring);
    DDLogInfo(@"[LocationManager] Background state: %ld", 
              (long)[UIApplication sharedApplication].applicationState);
    
    if ([CMAltimeter isRelativeAltitudeAvailable]) {
        DDLogInfo(@"[LocationManager] stopRelativeAltitudeUpdates");
        [self.altimeter stopRelativeAltitudeUpdates];
    }
}

- (void)stopContinuousLocationUpdates {
    DDLogInfo(@"[LocationManager] stopContinuousLocationUpdates called");
    if (self.manager) {
        [self.manager stopUpdatingLocation];
        if (self.activityTimer) {
            [self.activityTimer invalidate];
            self.activityTimer = nil;
        }
    }
}

- (void)startRegion:(CLRegion *)region {
    if (!region) {
        return;
    }
    
    // If we're already monitoring this region, do nothing
    if ([self.manager.monitoredRegions containsObject:region]) {
        return;
    }
    
    // If we're at the limit, add to pending
    if (self.manager.monitoredRegions.count >= MAX_MONITORED_REGIONS) {
        if (![self.pendingRegions containsObject:region]) {
            [self.pendingRegions addObject:region];
        }
        DDLogWarn(@"[LocationManager] Region limit reached, added to pending: %@", region.identifier);
        return;
    }
    
    // Start monitoring the region
    [self.manager startMonitoringForRegion:region];
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
        _lastUsedLocation = self.manager.location;
    } else {
        DDLogVerbose(@"[LocationManager] location == nil");
    }
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
            DDLogInfo(@"[LocationManager] Starting continuous location updates in Move mode");
            self.manager.distanceFilter = kCLDistanceFilterNone;
            self.manager.desiredAccuracy = kCLLocationAccuracyBest;
            [self.activityTimer invalidate];
            [self.manager startMonitoringVisits];
            [self.manager startUpdatingLocation];
            [self.manager startMonitoringSignificantLocationChanges];
            DDLogInfo(@"[LocationManager] Also started SLC as fallback");
            [self.manager stopMonitoringVisits];
            break;

        case LocationMonitoringSignificant:
            [self.activityTimer invalidate];
            DDLogInfo(@"[LocationManager] Enabling Significant: startMonitoringSignificantLocationChanges");

            [self.manager stopUpdatingLocation];
            [self.manager startMonitoringSignificantLocationChanges];
            [self.manager startMonitoringVisits];
            break;

        case LocationMonitoringManual:
        case LocationMonitoringQuiet:
        default:
            [self.activityTimer invalidate];
            DDLogInfo(@"[LocationManager] Disabling all monitoring (Manual/Quiet)");

            [self.manager stopUpdatingLocation];
            [self.manager stopMonitoringSignificantLocationChanges];
            [self.manager stopMonitoringVisits];
            break;
    }
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:@"group.org.owntracks.Owntracks"];
    [shared setInteger:self.monitoring forKey:@"monitoring"];
    [shared synchronize]; // 🚀 Force flush to disk

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
    if (self.manager.location) {
        [self.delegate timerLocation:self.manager.location];
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
            ];
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

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations {
    DDLogInfo(@"[LocationManager] didUpdateLocations triggered in state: %ld", 
              (long)[UIApplication sharedApplication].applicationState);
    
    // Log if this was triggered by SLC
    if (self.wasLaunchedByLocationUpdate) {
        DDLogWarn(@"[LocationManager] Location update from SLC wake");
        [self.manager startMonitoringVisits];
        [self.manager stopUpdatingLocation];
    } else {
        DDLogInfo(@"[LocationManager] Location update from continuous updates");
    }
    
    for (CLLocation *location in locations) {
        DDLogInfo(@"[LocationManager] Location: %@ last: %@ Δs:%.0f/%.0f Δm:%.0f/%.0f monitoring:%ld bgState:%ld",
                  location,
                  self.lastUsedLocation,
                  self.lastUsedLocation ? [location.timestamp timeIntervalSinceDate:self.lastUsedLocation.timestamp] : 0,
                  self.minTime,
                  self.lastUsedLocation ? [location distanceFromLocation:self.lastUsedLocation] : 0,
                  self.minDist,
                  (long)self.monitoring,
                  (long)[UIApplication sharedApplication].applicationState
                  );
        if (self.lastUsedLocation &&
            [location.timestamp timeIntervalSinceDate:self.lastUsedLocation.timestamp] <= 0) {
            continue;
        }
        if (self.lastUsedLocation && 
            [location distanceFromLocation:self.lastUsedLocation] < self.minDist) {
            continue;
        }

        self.lastUsedLocation = location;
        [self.delegate newLocation:location];
    }
    
    // Only stop continuous updates if the app was terminated and restarted by SLC
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground &&
        self.monitoring == LocationMonitoringMove &&
        self.wasLaunchedByLocationUpdate) {
        DDLogInfo(@"[LocationManager] App was launched by SLC after termination - stopping continuous updates");
        [self.manager stopUpdatingLocation];
        if (self.activityTimer) {
            [self.activityTimer invalidate];
            self.activityTimer = nil;
        }
        self.wasLaunchedByLocationUpdate = NO; // Reset for next time
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
    DDLogInfo(@"[LocationManager] didEnterRegion %@", region);
    
    if (![self removeHoldDown:region]) {
        [self locationManager:manager didDetermineState:CLRegionStateInside forRegion:region];
        [self.delegate regionEvent:region enter:YES];
    }
}

- (void)locationManager:(CLLocationManager *)manager
          didExitRegion:(CLRegion *)region {
    DDLogInfo(@"[LocationManager] didExitRegion %@", region);
    
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

- (void)locationManager:(CLLocationManager *)manager 
monitoringDidFailForRegion:(CLRegion *)region 
withError:(NSError *)error {
    DDLogError(@"[LocationManager] monitoringDidFailForRegion %@ %@ %@", 
               region, error.localizedDescription, error.userInfo);
    
    // If error is region limit exceeded
    if (error.domain == kCLErrorDomain && error.code == 5) {
        DDLogWarn(@"[LocationManager] Region monitoring limit exceeded, managing regions");
        [self manageRegions];
        return;
    }
    
    // For other errors, stop monitoring the problematic region
    if ([manager.monitoredRegions containsObject:region]) {
        [self stopRegion:region];
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
    DDLogInfo(@"[LocationManager] startBackgroundTimer");
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        if (!self.backgroundTimer || !self.backgroundTimer.isValid) {
            self.backgroundTimer = [NSTimer scheduledTimerWithTimeInterval:BACKGROUND_STOP_AFTER
                                                                    target:self
                                                                  selector:@selector(stopInBackground)
                                                                  userInfo:nil repeats:FALSE];
        }
    }
}



/*
 - (void)startBackgroundTimer {
    DDLogInfo(@"[LocationManager] startBackgroundTimer");
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        if (!self.backgroundTimer || !self.backgroundTimer.isValid) {
            self.backgroundTimer = [NSTimer scheduledTimerWithTimeInterval:BACKGROUND_STOP_AFTER
                                                                    target:self
                                                                  selector:@selector(stopInBackground)
                                                                  userInfo:nil repeats:FALSE];
        }
    }
}
 */

- (void)stopInBackground {
    DDLogInfo(@"[LocationManager] stopInBackground");
    self.backgroundTimer = nil;
    [self sleep];
}

- (void)setWasLaunchedByLocationUpdate:(BOOL)launched {
    _wasLaunchedByLocationUpdate = launched;
    DDLogInfo(@"[LocationManager] Setting wasLaunchedByLocationUpdate=%d", launched);
}

// New method to manage regions based on proximity
- (void)manageRegions {
    if (self.isManagingRegions) {
        return;
    }
    
    self.isManagingRegions = YES;
    
    // Get current location
    CLLocation *currentLocation = self.location;
    
    // Sort all regions (monitored + pending) by distance from current location
    NSMutableArray *allRegions = [NSMutableArray arrayWithArray:[self.manager.monitoredRegions allObjects]];
    [allRegions addObjectsFromArray:self.pendingRegions];
    
    // Remove duplicates
    NSSet *uniqueRegions = [NSSet setWithArray:allRegions];
    allRegions = [NSMutableArray arrayWithArray:[uniqueRegions allObjects]];
    
    // Sort regions by distance from current location
    [allRegions sortUsingComparator:^NSComparisonResult(CLRegion *region1, CLRegion *region2) {
        if ([region1 isKindOfClass:[CLCircularRegion class]] && [region2 isKindOfClass:[CLCircularRegion class]]) {
            CLCircularRegion *circRegion1 = (CLCircularRegion *)region1;
            CLCircularRegion *circRegion2 = (CLCircularRegion *)region2;
            
            CLLocation *loc1 = [[CLLocation alloc] initWithLatitude:circRegion1.center.latitude
                                                        longitude:circRegion1.center.longitude];
            CLLocation *loc2 = [[CLLocation alloc] initWithLatitude:circRegion2.center.latitude
                                                        longitude:circRegion2.center.longitude];
            
            CLLocationDistance dist1 = [currentLocation distanceFromLocation:loc1];
            CLLocationDistance dist2 = [currentLocation distanceFromLocation:loc2];
            
            return dist1 > dist2 ? NSOrderedDescending : NSOrderedAscending;
        }
        return NSOrderedSame;
    }];
    
    // Stop monitoring regions beyond the limit
    NSArray *currentMonitoredRegions = [self.manager.monitoredRegions allObjects];
    if (currentMonitoredRegions.count > MAX_MONITORED_REGIONS) {
        for (NSInteger i = MAX_MONITORED_REGIONS; i < currentMonitoredRegions.count; i++) {
            CLRegion *region = currentMonitoredRegions[i];
            [self stopRegion:region];
        }
    }
    
    // Start monitoring closest regions up to the limit
    self.pendingRegions = [NSMutableArray array];
    for (CLRegion *region in allRegions) {
        if (self.manager.monitoredRegions.count < MAX_MONITORED_REGIONS) {
            [self startRegion:region];
        } else {
            [self.pendingRegions addObject:region];
        }
    }
    
    self.isManagingRegions = NO;
}


@end

