//
//  LocationManager.m
//  OwnTracks
//
//  Created by Christoph Krey on 21.10.14.
//  Copyright © 2014-2026  OwnTracks. All rights reserved.
//

#import "LocationManager.h"
#import "OwnTracksAppDelegate.h"
#import "CoreData.h"
#import "OwnTracksLog.h"
#import "OwnTracks-Swift.h"

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
        OwnTracksLogDebug("[LocationManager] UIApplicationWillEnterForegroundNotification");
    }];
    [[NSNotificationCenter defaultCenter]
     addObserverForName:UIApplicationDidBecomeActiveNotification
     object:nil
     queue:nil
     usingBlock:^(NSNotification *note){
        OwnTracksLogDebug("[LocationManager] UIApplicationDidBecomeActiveNotification");
        [self wakeup];
    }];
    [[NSNotificationCenter defaultCenter]
     addObserverForName:UIApplicationWillResignActiveNotification
     object:nil
     queue:nil
     usingBlock:^(NSNotification *note){
        OwnTracksLogDebug("[LocationManager] UIApplicationWillResignActiveNotification");
        [self sleep];
    }];
    [[NSNotificationCenter defaultCenter]
     addObserverForName:UIApplicationWillTerminateNotification
     object:nil
     queue:nil
     usingBlock:^(NSNotification *note){
        OwnTracksLogDebug("[LocationManager] UIApplicationWillTerminateNotification");
        [self stop];
    }];
    
    self.sharedUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.org.owntracks.Owntracks"];
    [self.sharedUserDefaults addObserver:self forKeyPath:@"monitoringWithAuthKey"
                                 options:NSKeyValueObservingOptionNew
                                 context:nil];
    [self.sharedUserDefaults addObserver:self forKeyPath:@"sendNowWithAuthKey"
                                 options:NSKeyValueObservingOptionNew
                                 context:nil];
    [self.sharedUserDefaults addObserver:self forKeyPath:@"poiWithAuthKey"
                                 options:NSKeyValueObservingOptionNew
                                 context:nil];
    [self.sharedUserDefaults addObserver:self forKeyPath:@"tagWithAuthKey"
                                 options:NSKeyValueObservingOptionNew
                                 context:nil];

    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    OwnTracksLogDebug("[LocationManager] observeValueForKeyPath %@", keyPath);

    if (![Settings theAllowIntentControlInMOC:CoreData.sharedInstance.mainMOC]) {
        [NavigationController alertWithTitle:
         NSLocalizedString(@"Intent Control",
                           @"Header of an alert message regarding intent control")
                            message:
         NSLocalizedString(@"Intent control not allowed",
                           @"content of an alert message regarding intent control")];
        OwnTracksLogError("[LocationManager] Intents not allowed: %{public}@", keyPath);
    } else {
        if ([keyPath isEqualToString:@"monitoringWithAuthKey"]) {
            NSUserDefaults *shared = object;
            NSDictionary *dict = [shared objectForKey:@"monitoringWithAuthKey"];
            NSString *intentAuthKey = dict[@"intentAuthKey"];
            NSNumber *monitoringNumber = dict[@"monitoring"];
            NSInteger monitoring = monitoringNumber != nil ? monitoringNumber.integerValue : 0;
            if (intentAuthKey == nil || ![intentAuthKey isEqualToString:[Settings theIntentAuthKey]]) {
                [NavigationController alertWithTitle:
                 NSLocalizedString(@"Intent Control",
                                   @"Header of an alert message regarding intent control")
                                             message:
                 NSLocalizedString(@"Wrong intent auth key",
                                   @"content of an alert message regarding intent auth key")];
                OwnTracksLogError("[LocationManager] Wrong Intent Auth Key");
            } else {
                if (monitoring != self.monitoring) {
                    self.monitoring = monitoring;
                    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
                    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
                    [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                              forKey:@"monitoring_preference" inMOC:moc];
                    [CoreData.sharedInstance sync:moc];
                }
            }
        } else if ([keyPath isEqualToString:@"sendNowWithAuthKey"]) {
            NSUserDefaults *shared = object;
            NSDictionary *dict = [shared objectForKey:@"sendNowWithAuthKey"];
            NSString *intentAuthKey = dict[@"intentAuthKey"];
            if (intentAuthKey == nil || ![intentAuthKey isEqualToString:[Settings theIntentAuthKey]]) {
                [NavigationController alertWithTitle:
                 NSLocalizedString(@"Intent Control",
                                   @"Header of an alert message regarding intent control")
                                             message:
                 NSLocalizedString(@"Wrong intent auth key",
                                   @"content of an alert message regarding intent auth key")];
                OwnTracksLogError("[LocationManager] Wrong Intent Auth Key");
            } else {
                OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
                [ad sendNow:self.location withPOI:nil withImage:nil withImageName:nil];
            }
        } else if ([keyPath isEqualToString:@"poiWithAuthKey"]) {
            NSUserDefaults *shared = object;
            NSDictionary *dict = [shared objectForKey:@"poiWithAuthKey"];
            NSString *intentAuthKey = dict[@"intentAuthKey"];
            NSString *poi = dict[@"poi"];
            if (intentAuthKey == nil || ![intentAuthKey isEqualToString:[Settings theIntentAuthKey]]) {
                [NavigationController alertWithTitle:
                 NSLocalizedString(@"Intent Control",
                                   @"Header of an alert message regarding intent control")
                                             message:
                 NSLocalizedString(@"Wrong intent auth key",
                                   @"content of an alert message regarding intent auth key")];
                OwnTracksLogError("[LocationManager] Wrong Intent Auth Key");
            } else {
                OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
                [ad sendNow:self.location withPOI:poi withImage:nil withImageName:nil];
            }
        } else if ([keyPath isEqualToString:@"tagWithAuthKey"]) {
            NSUserDefaults *shared = object;
            NSDictionary *dict = [shared objectForKey:@"tagWithAuthKey"];
            NSString *intentAuthKey = dict[@"intentAuthKey"];
            NSString *tag = dict[@"tag"];
            if (intentAuthKey == nil || ![intentAuthKey isEqualToString:[Settings theIntentAuthKey]]) {
                [NavigationController alertWithTitle:
                 NSLocalizedString(@"Intent Control",
                                   @"Header of an alert message regarding intent control")
                                             message:
                 NSLocalizedString(@"Wrong intent auth key",
                                   @"content of an alert message regarding intent auth key")];
                OwnTracksLogError("[LocationManager] Wrong Intent Auth Key");
            } else {
                if (tag && tag.length) {
                    [[NSUserDefaults standardUserDefaults] setObject:tag forKey:@"tag"];
                } else {
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"tag"];
                }
            }
        }
    }
}

- (void)start {
    OwnTracksLogDebug("[LocationManager] start");
    [self authorize];
    
    self.altimeterAuthorizationStatus = [CMAltimeter authorizationStatus];
    self.altimeterIsRelativeAltitudeAvailable = [CMAltimeter isRelativeAltitudeAvailable];
    OwnTracksLogDefault("[LocationManager] CMAltimeter status=%ld, available=%d",
              (long)self.altimeterAuthorizationStatus,
              self.altimeterIsRelativeAltitudeAvailable);
    
    if (self.altimeterIsRelativeAltitudeAvailable &&
        (self.altimeterAuthorizationStatus == CMAuthorizationStatusNotDetermined ||
         self.altimeterAuthorizationStatus == CMAuthorizationStatusAuthorized)) {
        OwnTracksLogDebug("[LocationManager] startRelativeAltitudeUpdatesToQueue");
        [self.altimeter startRelativeAltitudeUpdatesToQueue:[NSOperationQueue mainQueue]
                                                withHandler:^(CMAltitudeData *altitudeData, NSError *error) {
            OwnTracksLogDebug("[LocationManager] altitudeData %@ error %{public}@", altitudeData, error);
            self.altitudeData = altitudeData;
        }];
    }
    
    self.motionActivityManagerAuthorizationStatus = [CMMotionActivityManager authorizationStatus];
    self.motionActivityManagerIsActivityAvailable = [CMMotionActivityManager isActivityAvailable];
    OwnTracksLogDefault("[LocationManager] CMMotionActivityManager status=%ld, available=%d",
              (long)self.motionActivityManagerAuthorizationStatus,
              self.motionActivityManagerIsActivityAvailable);
    
    if (self.motionActivityManagerIsActivityAvailable &&
        (self.motionActivityManagerAuthorizationStatus == CMAuthorizationStatusNotDetermined ||
         self.motionActivityManagerAuthorizationStatus == CMAuthorizationStatusAuthorized)) {
        OwnTracksLogDebug("[LocationManager] startActivityUpdatesToQueue");
        [self.motionActivityManager startActivityUpdatesToQueue:[NSOperationQueue mainQueue]
                                                    withHandler:^(CMMotionActivity * _Nullable activity) {
            OwnTracksLogDebug("[LocationManager] activity %{public}@", activity);
            self.motionActivity = activity;
        }];
    }
}

- (void)wakeup {
    OwnTracksLogDebug("[LocationManager] wakeup");
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
        OwnTracksLogDebug("[LocationManager] requestStateForRegion %{public}@", region.identifier);
        [self.manager requestStateForRegion:region];
    }
    if (self.monitoring == LocationMonitoringSignificant) {
        [self.manager requestLocation];
    }
    [self startBackgroundTimer];
}

- (void)authorize {
    self.locationManagerAuthorizationStatus = self.manager.authorizationStatus;
    OwnTracksLogDebug("[LocationManager] authorizationStatus=%d",
                 self.locationManagerAuthorizationStatus);
    if (self.locationManagerAuthorizationStatus == kCLAuthorizationStatusNotDetermined) {
        [self.manager requestAlwaysAuthorization];
    }
}

- (void)sleep {
    OwnTracksLogDebug("[LocationManager] sleep");
    for (CLBeaconIdentityConstraint *beaconIdentityConstraint in self.manager.rangedBeaconConstraints) {
        [self.manager stopRangingBeaconsSatisfyingConstraint:beaconIdentityConstraint];
    }
    if (self.monitoring != LocationMonitoringMove) {
        [self.activityTimer invalidate];
    }
}

- (void)stop {
    OwnTracksLogDebug("[LocationManager] stop");
    
    if ([CMAltimeter isRelativeAltitudeAvailable]) {
        OwnTracksLogDebug("[LocationManager] stopRelativeAltitudeUpdates");
        [self.altimeter stopRelativeAltitudeUpdates];
    }
    
    if ([CMMotionActivityManager isActivityAvailable]) {
        OwnTracksLogDebug("[LocationManager] stopActivityUpdates");
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

- (BOOL)monitoredRegion:(NSString *)identifier {
    for (CLRegion *region in self.manager.monitoredRegions) {
        if ([identifier isEqualToString:region.identifier]) {
            return true;
        }
    }
    return false;
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
        OwnTracksLogDebug("[LocationManager] location == nil");
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
    OwnTracksLogDefault("[LocationManager] set monitoring=%ld", (long)monitoring);
    if (monitoring != LocationMonitoringMove &&
        monitoring != LocationMonitoringManual &&
        monitoring != LocationMonitoringQuiet &&
        monitoring != LocationMonitoringSignificant) {
        monitoring = LocationMonitoringQuiet;
        OwnTracksLogDefault("[LocationManager] monitoring set to %ld", (long)monitoring);
    }
    _monitoring = monitoring;
    self.manager.pausesLocationUpdatesAutomatically = NO;
    self.manager.allowsBackgroundLocationUpdates = TRUE;
    
    switch (monitoring) {
        case LocationMonitoringMove:
            self.manager.distanceFilter = kCLDistanceFilterNone;
            self.manager.desiredAccuracy = kCLLocationAccuracyBest;
            [self.activityTimer invalidate];
            
            [self.manager startUpdatingLocation];
            [self.manager stopMonitoringSignificantLocationChanges];
            [self.manager stopMonitoringVisits];

            if (self.minTime > 0.0) {
                self.activityTimer = [NSTimer timerWithTimeInterval:self.minTime
                                                             target:self selector:@selector(activityTimer:)
                                                           userInfo:Nil
                                                            repeats:YES];
                [[NSRunLoop currentRunLoop] addTimer:self.activityTimer
                                             forMode:NSRunLoopCommonModes];
            }
            break;
            
        case LocationMonitoringSignificant:
            [self.activityTimer invalidate];
            [self.manager stopUpdatingLocation];
            [self.manager startMonitoringSignificantLocationChanges];
            [self.manager startMonitoringVisits];
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
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:@"group.org.owntracks.Owntracks"];
    [shared setInteger:self.monitoring forKey:@"monitoring"];
}

- (void)setRanging:(BOOL)ranging {
    OwnTracksLogDefault("[LocationManager] set ranging=%d", ranging);
    _ranging = ranging;
    
    if (!ranging) {
        for (CLBeaconIdentityConstraint *beaconIdentityConstraint in self.manager.rangedBeaconConstraints) {
            OwnTracksLogDebug("[LocationManager] stopRangingBeaconsSatisfyingConstraint %{public}@:%{public}@:%{public}@",
                          beaconIdentityConstraint.UUID.UUIDString,
                          beaconIdentityConstraint.major,
                          beaconIdentityConstraint.minor);
            [self.manager stopRangingBeaconsSatisfyingConstraint:beaconIdentityConstraint];
        }
    }
    for (CLRegion *region in self.manager.monitoredRegions) {
        OwnTracksLogDebug("[LocationManager] requestStateForRegion %{public}@", region.identifier);
        [self.manager requestStateForRegion:region];
    }
}

- (void)activityTimer:(NSTimer *)timer {
    OwnTracksLogDebug("[LocationManager] activityTimer fired after %f", self.minTime);
    CLLocation *location = self.manager.location;
    if (location) {
        self.lastUsedLocation = location;
        [self.delegate timerLocation:location];
    } else {
        OwnTracksLogError("[LocationManager] activityTimer found no location");
    }
}

/*
 *
 * Delegate
 *
 */

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    OwnTracksLogDefault("[LocationManager] didChangeAuthorizationStatus to %d",
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
            [NavigationController alertWithTitle:@"LocationManager"
                                         message:
                 NSLocalizedString(@"App is not allowed to use location services in background",
                                   @"Location Manager error message")
            ];
            OwnTracksLogDefault("[LocationManager] %@", @"App is not allowed to use location services in background");
            break;
        case kCLAuthorizationStatusNotDetermined:
            [NavigationController alertWithTitle:@"LocationManager"
                                         message:
                 NSLocalizedString(@"App is not allowed to use location services yet",
                                   @"Location Manager error message")
            ];
            OwnTracksLogDefault("[LocationManager] %@", @"App is not allowed to use location services yet");
            break;
        case kCLAuthorizationStatusDenied:
            [NavigationController alertWithTitle:@"LocationManager"
                                         message:
                 NSLocalizedString(@"App is not allowed to use location services",
                                   @"Location Manager error message")
            ];
            OwnTracksLogDefault("[LocationManager] %@", @"App is not allowed to use location services");
            break;
        case kCLAuthorizationStatusRestricted:
            [NavigationController alertWithTitle:@"LocationManager"
                                         message:
                 NSLocalizedString(@"App use of location services is restricted",
                                   @"Location Manager error message")
            ];
            OwnTracksLogDefault("[LocationManager] %@", @"App use of location services is restricted");
            break;
        default:
            [NavigationController alertWithTitle:@"LocationManager"
                                         message:
                 NSLocalizedString(@"App use of location services is unclear",
                                   @"Location Manager error message")
            ];
            OwnTracksLogDefault("[LocationManager] %@", @"App use of location services is unclear");
            break;
    }
        
}

+ (NSString *)CLLocationText:(CLLocation *)location {
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;

    return [NSString stringWithFormat:@"%g,%g(±%.0f,%.2f,%.2f)@%@",
            location.coordinate.longitude,
            location.coordinate.latitude,
            location.horizontalAccuracy,
            location.speed,
            location.course,
            [formatter stringFromDate:location.timestamp]];
}


- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations {
    OwnTracksLogDebug("[LocationManager] didUpdateLocations");
    
    int count = 0;
    for (CLLocation *location in locations) {
        count++;
        OwnTracksLogDefault("[LocationManager] Location#%d: %.0fs/%.0fs %.0fm/%.0fm %.0fs %@ %@ %@",
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
        
        if (self.lastUsedLocation &&
            [location.timestamp timeIntervalSinceDate:self.lastUsedLocation.timestamp] <= 0) {
            continue;
        }
        
        if (self.monitoring == LocationMonitoringMove &&
            self.lastUsedLocation &&
            [location distanceFromLocation:self.lastUsedLocation] < self.minDist) {
            continue;
        }

        self.lastUsedLocation = location;
        [self.delegate newLocation:location];
    }
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error {
    OwnTracksLogError("[LocationManager] didFailWithError %{public}@", error.localizedDescription);
}

/*
 *
 * Regions
 *
 */
- (void)locationManager:(CLLocationManager *)manager
      didDetermineState:(CLRegionState)state
              forRegion:(CLRegion *)region {
    OwnTracksLogDebug("[LocationManager] didDetermineState %ld %{public}@", (long)state, region.identifier);
    
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
    OwnTracksLogDefault("[LocationManager] didEnterRegion %{public}@", region.identifier);
    
    if (![self removeHoldDown:region]) {
        [self locationManager:manager didDetermineState:CLRegionStateInside forRegion:region];
        [self.delegate regionEvent:region enter:YES];
    }
}

- (void)locationManager:(CLLocationManager *)manager
          didExitRegion:(CLRegion *)region {
    OwnTracksLogDefault("[LocationManager] didExitRegion %{public}@", region.identifier);
    
    if ([region.identifier hasPrefix:@"-"]) {
        [self removeHoldDown:region];
        [self.pendingRegionEvents addObject:[PendingRegionEvent holdDown:region for:3.0 to:self]];
    } else {
        [self locationManager:manager didDetermineState:CLRegionStateOutside forRegion:region];
        [self.delegate regionEvent:region enter:NO];
    }
}

- (BOOL)removeHoldDown:(CLRegion *)region {
    OwnTracksLogDebug("[LocationManager] removeHoldDown %@ [%lu]",
                      region.identifier, (unsigned long)self.pendingRegionEvents.count);
    
    for (PendingRegionEvent *p in self.pendingRegionEvents) {
        if (p.region == region) {
            OwnTracksLogDebug("[LocationManager] holdDownInvalidated %{public}@", region.identifier);
            [p.holdDownTimer invalidate];
            p.region = nil;
            [self.pendingRegionEvents removeObject:p];
            return TRUE;
        }
    }
    return FALSE;
}

- (void)holdDownExpired:(NSTimer *)timer {
    OwnTracksLogDebug("[LocationManager] holdDownExpired %{public}@", timer.userInfo);
    if ([timer.userInfo isKindOfClass:[PendingRegionEvent class]]) {
        PendingRegionEvent *p = (PendingRegionEvent *)timer.userInfo;
        OwnTracksLogDebug("[LocationManager] holdDownExpired %{public}@", p.region.identifier);
        [self.delegate regionEvent:p.region enter:NO];
        [self removeHoldDown:p.region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    OwnTracksLogDebug("[LocationManager] didStartMonitoringForRegion %{public}@", region.identifier);
    [self.manager requestStateForRegion:region];
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    OwnTracksLogError("[LocationManager] monitoringDidFailForRegion %{public}@ %{public}@",
                      region.identifier, error.localizedDescription);
}

/*
 *
 * Beacons
 *
 */
- (void)locationManager:(CLLocationManager *)manager
didFailRangingBeaconsForConstraint:(CLBeaconIdentityConstraint *)beaconConstraint
                  error:(NSError *)error {
    OwnTracksLogError("[LocationManager] didFailRangingBeaconsForConstraint %{public}@ %{public}@",
                 beaconConstraint, error.localizedDescription);
    
}

- (void)locationManager:(CLLocationManager *)manager
        didRangeBeacons:(NSArray<CLBeacon *> *)beacons
   satisfyingConstraint:(CLBeaconIdentityConstraint *)beaconConstraint {
    OwnTracksLogDebug("[LocationManager] didRangeBeacons %{public}@ satisfyingContraint %{public}@",
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
    OwnTracksLogDebug("[LocationManager] didVisit %g,%g ha=%g a=%@ d=%@",
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
    OwnTracksLogDefault("[LocationManager] startBackgroundTimer");
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
    OwnTracksLogDefault("[LocationManager] stopInBackground");
    self.backgroundTimer = nil;
    [self sleep];
}

@end

