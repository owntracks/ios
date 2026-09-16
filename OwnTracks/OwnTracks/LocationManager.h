//
//  LocationManager.h
//  OwnTracks
//
//  Created by Christoph Krey on 21.10.14.
//  Copyright © 2014-2026  OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>

@protocol LocationManagerDelegate <NSObject>

- (void)newLocation:(CLLocation * _Nonnull)location;
- (void)timerLocation:(CLLocation * _Nonnull)location;
- (void)visitLocation:(CLLocation * _Nonnull)location;
- (void)regionEvent:(CLRegion * _Nonnull)region enter:(BOOL)enter;
- (void)regionState:(CLRegion * _Nonnull)region inside:(BOOL)inside;
- (void)beaconInRange:(CLBeacon * _Nonnull)beacon beaconConstraint:(CLBeaconIdentityConstraint * _Nonnull)beaconConstraint;

@end

@interface LocationManager : NSObject <CLLocationManagerDelegate>

/**
 Enumeration of LocationMonitoring modes
 */
typedef NS_ENUM(NSInteger, LocationMonitoring) {
    LocationMonitoringQuiet = -1,
    LocationMonitoringManual,
    LocationMonitoringSignificant,
    LocationMonitoringMove
};


+ (LocationManager * _Nonnull) sharedInstance;
@property (weak, nonatomic) id<LocationManagerDelegate> delegate;
@property (nonatomic) LocationMonitoring monitoring;
@property (nonatomic) BOOL ranging;
@property (nonatomic) double minDist;
@property (nonatomic) double minTime;
@property (readonly, nonatomic) CLLocation * _Nonnull location;
@property (readonly, nonatomic) CLLocation * _Nonnull lastUsedLocation;
@property (readonly, nonatomic) CLLocation * _Nonnull lastLocationWithMovement;

@property (readonly, nonatomic) CLAuthorizationStatus locationManagerAuthorizationStatus;

@property (readonly, nonatomic) CMAuthorizationStatus altimeterAuthorizationStatus;
@property (readonly, nonatomic) BOOL altimeterIsRelativeAltitudeAvailable;
@property (readonly, nonatomic) CMAltitudeData * _Nullable altitudeData;

@property (readonly, nonatomic) CMAuthorizationStatus motionActivityManagerAuthorizationStatus;
@property (readonly, nonatomic) BOOL motionActivityManagerIsActivityAvailable;
@property (readonly, nonatomic) CMMotionActivity * _Nullable motionActivity;



- (void)start;
- (void)wakeup;
- (void)sleep;
- (void)stop;

- (void)startRegion:(CLRegion * _Nonnull)region;
- (void)stopRegion:(CLRegion *_Nonnull)region;
- (void)resetRegions;
- (BOOL)monitoredRegion:(NSString *_Nonnull)identifier;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL insideBeaconRegion;
- (BOOL)insideBeaconRegion:(NSString * _Nonnull)identifier;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL insideCircularRegion;
- (BOOL)insideCircularRegion:(NSString * _Nonnull)identifier;
@property (readonly, strong, nonatomic) NSMutableDictionary * _Nonnull insideBeaconRegions;
@property (readonly, strong, nonatomic) NSMutableDictionary * _Nonnull insideCircularRegions;

@end

