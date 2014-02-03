//
//  OwnTracksAppDelegate.h
//  OwnTracks
//
//  Created by Christoph Krey on 03.02.14.
//  Copyright (c) 2014 OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "Connection.h"
#import "Location+Create.h"
#import "Settings.h"


@interface OwnTracksAppDelegate : UIResponder <UIApplicationDelegate, CLLocationManagerDelegate, ConnectionDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) CLLocationManager *manager;
@property (nonatomic) NSInteger monitoring;
@property (strong, nonatomic) Connection *connection;
@property (strong, nonatomic) Settings *settings;

- (void)switchOff;
- (void)sendNow;
- (void)sendWayPoint:(Location *)location;
- (void)reconnect;
- (void)connectionOff;
- (void)saveContext;

@end
