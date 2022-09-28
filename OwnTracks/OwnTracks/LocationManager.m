//
//  LocationManager.m
//  OwnTracks
//
//  Created by Christoph Krey on 21.10.14.
//  Copyright © 2014-2022  OwnTracks. All rights reserved.
//

#import "LocationManager.h"
#import "OwnTracksAppDelegate.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface LocationManager()
@property (strong, nonatomic) CLLocationManager *manager;
@property (strong, nonatomic) CMAltimeter *altimeter;
@property (strong, nonatomic) CLLocation *lastUsedLocation;
@property (strong, nonatomic) NSTimer *activityTimer;
@property (strong, nonatomic) NSMutableSet *pendingRegionEvents;
- (void)holdDownExpired:(NSTimer *)timer;

@property (strong, nonatomic) NSMutableDictionary *insideBeaconRegions;
@property (strong, nonatomic) NSMutableDictionary *insideCircularRegions;
@property (strong, nonatomic) NSMutableArray *rangedBeacons;
@property (strong, nonatomic) NSTimer *backgroundTimer;
@property (strong, nonatomic) NSUserDefaults *sharedUserDefaults;
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
    
    self.insideBeaconRegions = [[NSMutableDictionary alloc] init];
    self.insideCircularRegions = [[NSMutableDictionary alloc] init];
    self.rangedBeacons = [[NSMutableArray alloc] init];
    self.lastUsedLocation = [[CLLocation alloc] initWithLatitude:0 longitude:0];
    self.pendingRegionEvents = [[NSMutableSet alloc] init];
    
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
    
    self.sharedUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.org.owntracks.Owntracks"];
    [self.sharedUserDefaults addObserver:self forKeyPath:@"monitoring"
                                 options:NSKeyValueObservingOptionNew
                                 context:nil];
    [self.sharedUserDefaults addObserver:self forKeyPath:@"sendNow"
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
        NSInteger monitoring = [shared integerForKey:@"monitoring"];
        if (monitoring != self.monitoring) {
            self.monitoring = monitoring;
        }
    } else if ([keyPath isEqualToString:@"sendNow"]) {
        OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [ad sendNow:self.location];
    }
}

- (void)start {
    DDLogVerbose(@"start");
    [self authorize];
    
    CMAuthorizationStatus status = [CMAltimeter authorizationStatus];
    BOOL available = [CMAltimeter isRelativeAltitudeAvailable];
    DDLogVerbose(@"CMAltimeter status=%ld, available=%d",
                 (long)status,
                 available);
    
    if (available &&
        (status == CMAuthorizationStatusNotDetermined ||
         status == CMAuthorizationStatusAuthorized)) {
        DDLogVerbose(@"startRelativeAltitudeUpdatesToQueue");
        [self.altimeter startRelativeAltitudeUpdatesToQueue:[NSOperationQueue mainQueue]
                                                withHandler:^(CMAltitudeData *altitudeData, NSError *error) {
            DDLogVerbose(@"altitudeData %@", altitudeData);
            self.altitude = altitudeData;
        }];
    }
}

- (void)wakeup {
    DDLogVerbose(@"wakeup");
    [self authorize];
    if (self.monitoring == LocationMonitoringMove) {
        [self.activityTimer invalidate];
        self.activityTimer = [NSTimer timerWithTimeInterval:self.minTime
                                                     target:self
                                                   selector:@selector(activityTimer:)
                                                   userInfo:Nil
                                                    repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:self.activityTimer
                                     forMode:NSRunLoopCommonModes];
    }
    for (CLRegion *region in self.manager.monitoredRegions) {
        DDLogVerbose(@"requestStateForRegion %@", region.identifier);
        [self.manager requestStateForRegion:region];
    }
    if (self.monitoring == LocationMonitoringSignificant) {
        [self.manager requestLocation];
    }
    [self startBackgroundTimer];
}

- (void)authorize {
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    DDLogVerbose(@"authorizationStatus=%d", status);
    if (status == kCLAuthorizationStatusNotDetermined) {
        [self.manager requestAlwaysAuthorization];
    }
}

- (void)sleep {
    DDLogVerbose(@"sleep");
    for (CLBeaconIdentityConstraint *beaconIdentityConstraint in self.manager.rangedBeaconConstraints) {
        [self.manager stopRangingBeaconsSatisfyingConstraint:beaconIdentityConstraint];
    }
    if (self.monitoring != LocationMonitoringMove) {
        [self.activityTimer invalidate];
    }
}

- (void)stop {
    DDLogVerbose(@"stop");
    
    if ([CMAltimeter isRelativeAltitudeAvailable]) {
        DDLogVerbose(@"stopRelativeAltitudeUpdates");
        [self.altimeter stopRelativeAltitudeUpdates];
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
        _lastUsedLocation = self.manager.location;
    } else {
        DDLogVerbose(@"location == nil");
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
    DDLogVerbose(@"monitoring=%ld", (long)monitoring);
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
    
    [self.manager stopUpdatingLocation];
    [self.manager stopMonitoringVisits];
    [self.manager stopMonitoringSignificantLocationChanges];
    
    switch (monitoring) {
        case LocationMonitoringMove:
            self.manager.distanceFilter = self.minDist > 0 ? self.minDist : kCLDistanceFilterNone;
            self.manager.desiredAccuracy = kCLLocationAccuracyBest;
            [self.activityTimer invalidate];
            
            [self.manager startUpdatingLocation];
            self.activityTimer = [NSTimer timerWithTimeInterval:self.minTime
                                                         target:self selector:@selector(activityTimer:)
                                                       userInfo:Nil
                                                        repeats:YES];
            [[NSRunLoop currentRunLoop] addTimer:self.activityTimer
                                         forMode:NSRunLoopCommonModes];
            break;
            
        case LocationMonitoringSignificant:
            [self.activityTimer invalidate];
            [self.manager startMonitoringSignificantLocationChanges];
            [self.manager startMonitoringVisits];
            break;
            
        case LocationMonitoringManual:
        case LocationMonitoringQuiet:
        default:
            [self.activityTimer invalidate];
            break;
    }
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:@"group.org.owntracks.Owntracks"];
    [shared setInteger:self.monitoring forKey:@"monitoring"];
}

- (void)setRanging:(BOOL)ranging {
    DDLogVerbose(@"ranging=%d", ranging);
    _ranging = ranging;
    
    if (!ranging) {
        for (CLBeaconIdentityConstraint *beaconIdentityConstraint in self.manager.rangedBeaconConstraints) {
            DDLogVerbose(@"stopRangingBeaconsSatisfyingConstraint %@",
                         [NSString stringWithFormat:@"%@:%@:%@",
                          beaconIdentityConstraint.UUID.UUIDString,
                          beaconIdentityConstraint.major,
                          beaconIdentityConstraint.minor]);
            [self.manager stopRangingBeaconsSatisfyingConstraint:beaconIdentityConstraint];
        }
    }
    for (CLRegion *region in self.manager.monitoredRegions) {
        DDLogVerbose(@"requestStateForRegion %@", region.identifier);
        [self.manager requestStateForRegion:region];
    }
}

- (void)activityTimer:(NSTimer *)timer {
    DDLogVerbose(@"activityTimer");
    if (self.manager.location) {
        [self.delegate timerLocation:self.manager.location];
    } else {
        DDLogWarn(@"activityTimer found no location");
    }
}


/*
 *
 * Delegate
 *
 */

- (void)locationManager:(CLLocationManager *)manager
didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    DDLogVerbose(@"didChangeAuthorizationStatus to %d", status);
    if (status != kCLAuthorizationStatusAuthorizedAlways) {
        [self showError];
    }
}

- (void)showError {
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    switch (status) {
        case kCLAuthorizationStatusAuthorizedAlways:
            break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            [ad.navigationController alert:@"LocationManager"
                                   message:
                 NSLocalizedString(@"App is not allowed to use location services in background",
                                   @"Location Manager error message")
            ];
            break;
        case kCLAuthorizationStatusNotDetermined:
            [ad.navigationController alert:@"LocationManager"
                                   message:
                 NSLocalizedString(@"App is not allowed to use location services yet",
                                   @"Location Manager error message")
            ];
            break;
        case kCLAuthorizationStatusDenied:
            [ad.navigationController alert:@"LocationManager"
                                   message:
                 NSLocalizedString(@"App is not allowed to use location services",
                                   @"Location Manager error message")
            ];
            break;
        case kCLAuthorizationStatusRestricted:
            [ad.navigationController alert:@"LocationManager"
                                   message:
                 NSLocalizedString(@"App use of location services is restricted",
                                   @"Location Manager error message")
            ];
            break;
        default:
            [ad.navigationController alert:@"LocationManager"
                                   message:
                 NSLocalizedString(@"App use of location services is unclear",
                                   @"Location Manager error message")
            ];
            break;
    }
    
    if (![CLLocationManager locationServicesEnabled]) {
        [ad.navigationController alert:@"LocationManager"
                               message:
             NSLocalizedString(@"Location services are not enabled",
                               @"Location Manager error message")
        ];
    }
    
#if 0
    if (![CLLocationManager significantLocationChangeMonitoringAvailable]) {
        [delegate.navigationController alert:@"LocationManager"
                                     message:
             NSLocalizedString(@"Significant location change monitoring not available",
                               @"Location Manager error message")
        ];
    }
    
    if (![CLLocationManager isMonitoringAvailableForClass:[CLCircularRegion class]]) {
        [delegate.navigationController alert:@"LocationManager"
                                     message:
             NSLocalizedString(@"Circular region monitoring not available",
                               @"Location Manager error message")
        ];
    }
    
    if (![CLLocationManager isMonitoringAvailableForClass:[CLBeaconRegion class]]) {
        [delegate.navigationController alert:@"LocationManager"
                                     message:
             NSLocalizedString(@"iBeacon region monitoring not available",
                               @"Location Manager error message")
        ];
    }
    
    if (![CLLocationManager isRangingAvailable]) {
        [delegate.navigationController alert:@"LocationManager"
                                     message:
             NSLocalizedString(@"iBeacon ranging not available",
                               @"Location Manager error message")
        ];
    }
    
    if (![CLLocationManager headingAvailable]) {
        // [delegate.navigationController alert:where message:@"Heading not available"];
    }
#endif
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations {
    DDLogVerbose(@"[LocationManager] didUpdateLocations");
    
    for (CLLocation *location in locations) {
        DDLogVerbose(@"[LocationManager] Location: %@", location);
        if ([location.timestamp compare:self.lastUsedLocation.timestamp] != NSOrderedAscending ) {
            self.lastUsedLocation = location;
            [self.delegate newLocation:location];
        }
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
    DDLogVerbose(@"[LocationManager] didEnterRegion %@", region);
    
    if (![self removeHoldDown:region]) {
        [self locationManager:manager didDetermineState:CLRegionStateInside forRegion:region];
        [self.delegate regionEvent:region enter:YES];
    }
}

- (void)locationManager:(CLLocationManager *)manager
          didExitRegion:(CLRegion *)region {
    DDLogVerbose(@"[LocationManager] didExitRegion %@", region);
    
    if ([region.identifier hasPrefix:@"-"]) {
        [self removeHoldDown:region];
        [self.pendingRegionEvents addObject:[PendingRegionEvent holdDown:region for:3.0 to:self]];
    } else {
        [self locationManager:manager didDetermineState:CLRegionStateOutside forRegion:region];
        [self.delegate regionEvent:region enter:NO];
    }
}

- (BOOL)removeHoldDown:(CLRegion *)region {
    DDLogVerbose(@"[LocationManager] removeHoldDown %@ [%lu]", region.identifier, (unsigned long)self.pendingRegionEvents.count);
    
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
    DDLogVerbose(@"[LocationManager] holdDownExpired %@", timer.userInfo);
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
    DDLogVerbose(@"[LocationManager] monitoringDidFailForRegion %@ %@ %@", region, error.localizedDescription, error.userInfo);
    for (CLRegion *monitoredRegion in manager.monitoredRegions) {
        DDLogVerbose(@"[LocationManager] monitoredRegion: %@", monitoredRegion);
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
    DDLogVerbose(@"[LocationManager] didFailRangingBeaconsForConstraint %@ %@ %@",
                 beaconConstraint, error.localizedDescription, error.userInfo);
    
}

- (void)locationManager:(CLLocationManager *)manager
        didRangeBeacons:(NSArray<CLBeacon *> *)beacons
   satisfyingConstraint:(CLBeaconIdentityConstraint *)beaconConstraint {
    DDLogVerbose(@"[LocationManager] didRangeBeacons %@ satisfyingContraint %@",
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
    DDLogVerbose(@"[LocationManager] didVisit %g,%g ±%gm a=%@ d=%@",
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
    DDLogVerbose(@"[LocationManager] startBackgroundTimer");
    
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        if (!self.backgroundTimer || !self.backgroundTimer.isValid) {
            self.backgroundTimer = [NSTimer scheduledTimerWithTimeInterval:BACKGROUND_STOP_AFTER
                                                                    target:self
                                                                  selector:@selector(stopInBackground)
                                                                  userInfo:nil repeats:FALSE];
        }
    }
}

- (void)stopInBackground {
    DDLogVerbose(@"[LocationManager] stopInBackground");
    self.backgroundTimer = nil;
    [self sleep];
}

@end

