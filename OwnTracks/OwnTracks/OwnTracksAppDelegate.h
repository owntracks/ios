//
//  OwnTracksAppDelegate.h
//  OwnTracks
//
//  Created by Christoph Krey on 03.02.14.
//  Copyright (c) 2014 OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>
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

@property (strong, nonatomic) Connection *connection;
@property (strong, nonatomic) Settings *settings;

@property (strong, nonatomic) NSNumber *connectionState;
@property (strong, nonatomic) NSNumber *connectionBuffered;

- (void)sendNow;
- (void)sendWayPoint:(Location *)location;
- (void)sendEmpty:(Friend *)friend;
- (void)reconnect;
- (void)connectionOff;
- (void)saveContext;

@end
