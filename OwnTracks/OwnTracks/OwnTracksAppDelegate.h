//
//  OwnTracksAppDelegate.h
//  OwnTracks
//
//  Created by Christoph Krey on 03.02.14.
//  Copyright © 2014 -2019 OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>

#import "LocationManager.h"
#import "Connection.h"
#import "Settings.h"

#import "Friend+CoreDataClass.h"
#import "Region+CoreDataClass.h"

#import "NavigationController.h"

@interface OwnTracksAppDelegate : UIResponder <UIApplicationDelegate, ConnectionDelegate, LocationManagerDelegate, NSUserActivityDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (weak, nonatomic) NavigationController *navigationController;

@property (strong, nonatomic) NSString *processingMessage;

@property (strong, nonatomic) Connection *connection;
@property (strong, nonatomic) NSNumber *connectionState;
@property (strong, nonatomic) NSNumber *connectionBuffered;

@property (strong, nonatomic) NSDate *configLoad;
@property (strong, nonatomic) NSString *action;

- (void)sendNow;
- (void)dump;
- (void)waypoints;
- (void)requestLocationFromFriend:(Friend *)friend;
- (void)sendRegion:(Region *)region;
- (void)sendEmpty:(NSString *)topic;
- (void)reconnect;
- (void)connectionOff;
- (void)terminateSession;

@end
