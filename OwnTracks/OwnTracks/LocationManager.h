//
//  LocationManager.h
//  OwnTracks
//
//  Created by Christoph Krey on 21.10.14.
//  Copyright © 2014-2025  OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>

@protocol LocationManagerDelegate <NSObject>

- (void)newLocation:(CLLocation *)location;
- (void)timerLocation:(CLLocation *)location;
- (void)visitLocation:(CLLocation *)location;
- (void)regionEvent:(CLRegion *)region enter:(BOOL)enter;
- (void)regionState:(CLRegion *)region inside:(BOOL)inside;
- (void)beaconInRange:(CLBeacon *)beacon beaconConstraint:(CLBeaconIdentityConstraint *)beaconConstraint;

@end

@interface LocationManager : NSObject <CLLocationManagerDelegate>

/**
 Enumeration of LocationMonitoring modes
 */
typedef NS_ENUM(NSInteger, LocationMonitoring) {
    LocationMonitoringQuiet = -1,
    LocationMonitoringManual = 0,
    LocationMonitoringSignificant = 1,
    LocationMonitoringMove = 2
};


@property (weak, nonatomic) id<LocationManagerDelegate> delegate;
@property (nonatomic) LocationMonitoring monitoring;
@property (nonatomic) BOOL ranging;
@property (nonatomic) double minDist;
@property (nonatomic) double minTime;
@property (nonatomic) BOOL wasLaunchedByLocationUpdate;
@property (readonly, nonatomic) CLLocation *location;
@property (readonly, nonatomic) CLLocation *lastUsedLocation;
@property (readonly, nonatomic) CLLocation *lastLocationWithMovement;

// Maximum number of regions that can be monitored simultaneously
#define MAX_MONITORED_REGIONS 20

// Properties for region management
@property (strong, nonatomic) NSMutableArray *pendingRegions;
@property (nonatomic) BOOL isManagingRegions;

@property (readonly, nonatomic) CLAuthorizationStatus locationManagerAuthorizationStatus;

@property (readonly, nonatomic) CMAuthorizationStatus altimeterAuthorizationStatus;
@property (readonly, nonatomic) BOOL altimeterIsRelativeAltitudeAvailable;
@property (readonly, nonatomic) CMAltitudeData *altitudeData;

@property (readonly, nonatomic) CMAuthorizationStatus motionActivityManagerAuthorizationStatus;
@property (readonly, nonatomic) BOOL motionActivityManagerIsActivityAvailable;
@property (readonly, nonatomic) CMMotionActivity *motionActivity;



+ (LocationManager *)sharedInstance;
- (void)start;
- (void)wakeup;
- (void)sleep;
- (void)authorize;
- (void)startRegion:(CLRegion *)region;
- (void)stopRegion:(CLRegion *)region;
- (void)resetRegions;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL insideBeaconRegion;
- (BOOL)insideBeaconRegion:(NSString *)identifier;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL insideCircularRegion;
- (BOOL)insideCircularRegion:(NSString *)identifier;
@property (readonly, strong, nonatomic) NSMutableDictionary *insideBeaconRegions;
@property (readonly, strong, nonatomic) NSMutableDictionary *insideCircularRegions;

- (void)setWasLaunchedByLocationUpdate:(BOOL)launched;
- (void)stopContinuousLocationUpdates;

@end

