//
//  LocationManager.m
//  OwnTracks
//
//  Created by Christoph Krey on 21.10.14.
//  Copyright (c) 2014-2015 OwnTracks. All rights reserved.
//

#import "LocationManager.h"
#import "AlertView.h"

#ifdef DEBUG
#define DEBUGLM FALSE
#else
#define DEBUGLM FALSE
#endif

@interface LocationManager()
@property (strong, nonatomic) CLLocationManager *manager;
@property (strong, nonatomic) NSDate *lastUsedLocationTime;
@property (strong, nonatomic) NSTimer *activityTimer;
@property (strong, nonatomic) NSMutableSet *pendingRegionEvents;
- (void)holdDownExpired:(NSTimer *)timer;
@end

@interface PendingRegionEvent : NSObject
@property (strong, nonatomic) CLRegion *region;
@property (strong, nonatomic) NSTimer *holdDownTimer;

@end

@implementation PendingRegionEvent

+ (PendingRegionEvent *)holdDown:(CLRegion *)region for:(NSTimeInterval)interval to:(id)to{
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
static LocationManager *theInstance = nil;

+ (LocationManager *)sharedInstance {
    if (theInstance == nil) {
        theInstance = [[LocationManager alloc] init];
    }
    return theInstance;
}

- (id)init {
    self = [super init];
    self.manager = [[CLLocationManager alloc] init];
    self.manager.delegate = self;
    self.lastUsedLocationTime = [NSDate date];
    self.pendingRegionEvents = [[NSMutableSet alloc] init];
    [self authorize];
    return self;
}

- (void)start {
    [self authorize];
}

- (void)wakeup {
    [self authorize];
}

- (void)authorize {
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (DEBUGLM) NSLog(@"authorizationStatus=%d", status);
    if (status == kCLAuthorizationStatusNotDetermined) {
        if (DEBUGLM) NSLog(@"systemVersion=%@", [[UIDevice currentDevice] systemVersion]);
        if ([[[UIDevice currentDevice] systemVersion] compare:@"8.0"] != NSOrderedAscending) {
            [self.manager requestAlwaysAuthorization];
        }
    }
}

- (void)sleep {
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0"] != NSOrderedAscending) {
        for (CLBeaconRegion *beaconRegion in self.manager.rangedRegions) {
            [self.manager stopRangingBeaconsInRegion:beaconRegion];
        }
    }
    [self.activityTimer invalidate];
}

- (void)stop {
}

- (void)startRegion:(CLRegion *)region {
    [self.manager startMonitoringForRegion:region];
}

- (void)stopRegion:(CLRegion *)region {
    [self removeHoldDown:region];
    [self.manager stopMonitoringForRegion:region];
}

- (void)resetRegions {
    for (CLRegion *region in self.manager.monitoredRegions) {
        [self.manager stopMonitoringForRegion:region];
    }
}

- (CLLocation *)location {
    self.lastUsedLocationTime = self.manager.location.timestamp;
    return self.manager.location;
}

- (void)setMonitoring:(int)monitoring {
    if (DEBUGLM) NSLog(@"monitoring=%ld", (long)monitoring);
    _monitoring = monitoring;
    
    switch (monitoring) {
        case 2:
            self.manager.distanceFilter = self.minDist;
            self.manager.desiredAccuracy = kCLLocationAccuracyBest;
            self.manager.pausesLocationUpdatesAutomatically = YES;
            [self.manager stopMonitoringSignificantLocationChanges];
            
            [self.manager startUpdatingLocation];
            self.activityTimer = [NSTimer timerWithTimeInterval:self.minTime target:self selector:@selector(activityTimer:) userInfo:Nil repeats:YES];
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
    if (DEBUGLM) NSLog(@"ranging=%d", ranging);
    _ranging = ranging;
    
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0"] != NSOrderedAscending) {
        if (!ranging) {
            for (CLBeaconRegion *beaconRegion in self.manager.rangedRegions) {
                if (DEBUGLM) NSLog(@"stopRangingBeaconsInRegion %@", beaconRegion.identifier);
                [self.manager stopRangingBeaconsInRegion:beaconRegion];
            }
        }
    }
    for (CLRegion *region in self.manager.monitoredRegions) {
        if (DEBUGLM) NSLog(@"requestStateForRegion %@", region.identifier);
        [self.manager requestStateForRegion:region];
    }
}

- (void)activityTimer:(NSTimer *)timer {
    if (DEBUGLM) NSLog(@"activityTimer");
    [self.delegate timerLocation:self.manager.location];
}


/*
 *
 * Delegate
 *
 */

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (DEBUGLM) NSLog(@"didChangeAuthorizationStatus to %d", status);
    if (status != kCLAuthorizationStatusAuthorizedAlways) {
        [self showError];
    }
}
    
- (void)showError {
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    switch (status) {
        case kCLAuthorizationStatusAuthorizedAlways:
            break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            [AlertView alert:@"LocationManager" message:@"App is not allowed to use location services in background"];
            break;
        case kCLAuthorizationStatusNotDetermined:
            [AlertView alert:@"LocationManager" message:@"App is not allowed to use location services yet"];
            break;
        case kCLAuthorizationStatusDenied:
            [AlertView alert:@"LocationManager" message:@"App is not allowed to use location services"];
            break;
        case kCLAuthorizationStatusRestricted:
            [AlertView alert:@"LocationManager" message:@"App use of location services is restricted"];
            break;
        default:
            [AlertView alert:@"LocationManager" message:@"App use of location services is unclear"];
            break;
    }
    
    if (![CLLocationManager locationServicesEnabled]) {
        [AlertView alert:@"LocationManager" message:@"Location services are not enabled"];
    }
    
    if (![CLLocationManager significantLocationChangeMonitoringAvailable]) {
        [AlertView alert:@"LocationManager" message:@"Significant location change monitoring not available"];
    }
    
    if (![CLLocationManager isMonitoringAvailableForClass:[CLCircularRegion class]]) {
        [AlertView alert:@"LocationManager" message:@"Circular region monitoring not available"];
    }
    
    if (![CLLocationManager isMonitoringAvailableForClass:[CLBeaconRegion class]]) {
        [AlertView alert:@"LocationManager" message:@"iBeacon region monitoring not available"];
    }
    
    if (![CLLocationManager isRangingAvailable]) {
        [AlertView alert:@"LocationManager" message:@"iBeacon ranging not available"];
    }
    
    if (![CLLocationManager deferredLocationUpdatesAvailable]) {
        // [AlertView alert:where message:@"Deferred location updates not available"];
    }

    if (![CLLocationManager headingAvailable]) {
        // [AlertView alert:where message:@"Heading not available"];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    if (DEBUGLM) NSLog(@"didUpdateLocations");
    
    for (CLLocation *location in locations) {
        if (DEBUGLM) NSLog(@"Location: %@", [location description]);
        if ([location.timestamp compare:self.lastUsedLocationTime] != NSOrderedAscending ) {
            [self.delegate newLocation:location];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if (DEBUGLM) NSLog(@"didFailWithError %@", error.localizedDescription);
    // error
}


/*
 *
 * Regions
 *
 */
- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region {
    if (DEBUGLM) NSLog(@"didDetermineState %ld %@", (long)state, region);
    if (state == CLRegionStateInside) {
        if (self.ranging) {
            if ([region isKindOfClass:[CLBeaconRegion class]]) {
                CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
                [self.manager startRangingBeaconsInRegion:beaconRegion];
            }
        }
    } else if (state == CLRegionStateOutside) {
        if ([region isKindOfClass:[CLBeaconRegion class]]) {
            CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
            [self.manager stopRangingBeaconsInRegion:beaconRegion];
        }
    }
    
    [self.delegate regionState:region inside:(state == CLRegionStateInside)];
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    if (DEBUGLM) NSLog(@"didEnterRegion %@", region);
    if (![self removeHoldDown:region]) {
        [self.delegate regionEvent:region enter:YES];
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    if (DEBUGLM) NSLog(@"didExitRegion %@", region);
    if ([region.identifier hasPrefix:@"-"]) {
                [self removeHoldDown:region];
        [self.pendingRegionEvents addObject:[PendingRegionEvent holdDown:region for:3.0 to:self]];
    } else {
        [self.delegate regionEvent:region enter:NO];
    }
}

- (BOOL)removeHoldDown:(CLRegion *)region {
    if (DEBUGLM) NSLog(@"removeHoldDown %@ [%lu]", region.identifier, (unsigned long)self.pendingRegionEvents.count);

    for (PendingRegionEvent *p in self.pendingRegionEvents) {
        if (p.region == region) {
            if (DEBUGLM) NSLog(@"holdDownInvalidated %@", region.identifier);
            [p.holdDownTimer invalidate];
            p.region = nil;
            [self.pendingRegionEvents removeObject:p];
            return TRUE;
        }
    }
    return FALSE;
}

- (void)holdDownExpired:(NSTimer *)timer {
    if (DEBUGLM) NSLog(@"holdDownExpired %@", timer.userInfo);
    if ([timer.userInfo isKindOfClass:[PendingRegionEvent class]]) {
        PendingRegionEvent *p = (PendingRegionEvent *)timer.userInfo;
        if (DEBUGLM) NSLog(@"holdDownExpired %@", p.region.identifier);
        [self.delegate regionEvent:p.region enter:NO];
        [self removeHoldDown:p.region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    if (DEBUGLM) NSLog(@"didStartMonitoringForRegion %@", region);
    [self.manager requestStateForRegion:region];
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    if (DEBUGLM) {
        NSLog(@"monitoringDidFailForRegion %@ %@", region, error.localizedDescription);
        for (CLRegion *monitoredRegion in manager.monitoredRegions) {
            NSLog(@"monitoredRegion: %@", monitoredRegion);
        }
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
- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error {
    if (DEBUGLM) NSLog(@"rangingBeaconsDidFailForRegion %@ %@", region, error.localizedDescription);
    // error
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region {
    if (DEBUGLM) NSLog(@"didRangeBeacons %@ %@", beacons, region);
    for (CLBeacon *beacon in beacons) {
        [self.delegate beaconInRange:beacon];
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
    //
}

@end

