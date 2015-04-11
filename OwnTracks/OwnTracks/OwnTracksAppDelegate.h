//
//  OwnTracksAppDelegate.h
//  OwnTracks
//
//  Created by Christoph Krey on 03.02.14.
//  Copyright (c) 2014-2015 OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>

#import "LocationManager.h"
#import "Connection.h"
#import "Location+Create.h"
#import "Settings.h"

@protocol RangingDelegate <NSObject>

- (void)regionState:(CLRegion *)region inside:(BOOL)inside;
- (void)beaconInRange:(CLBeacon *)beacon;

@end

@interface OwnTracksAppDelegate : UIResponder <UIApplicationDelegate, ConnectionDelegate, LocationManagerDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (weak, nonatomic) id<RangingDelegate> delegate;
@property (strong, nonatomic) Settings *settings;

@property (strong, nonatomic) Connection *connectionOut;
@property (strong, nonatomic) Connection *connectionIn;

@property (strong, nonatomic) NSNumber *connectionStateOut;
@property (strong, nonatomic) NSNumber *connectionBufferedOut;
@property (strong, nonatomic) NSNumber *inQueue;

- (void)sendNow;
- (void)requestLocationFromFriend:(Friend *)friend;
- (void)sendWayPoint:(Location *)location;
- (void)sendEmpty:(NSString *)topic;
- (void)reconnect;
- (void)connectionOff;
- (void)syncProcessing;

@end
