//
//  LocationManager.h
//  OwnTracks
//
//  Created by Christoph Krey on 21.10.14.
//  Copyright (c) 2014 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@protocol LocationManagerDelegate <NSObject>

- (void)newLocation:(CLLocation *)location;
- (void)timerLocation:(CLLocation *)location;
- (void)regionEvent:(CLRegion *)region enter:(BOOL)enter;
- (void)regionState:(CLRegion *)region inside:(BOOL)inside;
- (void)beaconInRange:(CLBeacon *)beacon;

@end

@interface LocationManager : NSObject <CLLocationManagerDelegate>
+ (LocationManager *)sharedInstance;
@property (weak, nonatomic) id<LocationManagerDelegate> delegate;
@property (nonatomic) BOOL ranging;
@property (nonatomic) int monitoring;
@property (nonatomic) double minDist;
@property (nonatomic) double minTime;
@property (readonly, nonatomic) CLLocation *location;

- (void)start;
- (void)wakeup;
- (void)sleep;
- (void)stop;
- (void)startRegion:(CLRegion *)region;
- (void)stopRegion:(CLRegion *)region;
- (void)resetRegions;

@end

