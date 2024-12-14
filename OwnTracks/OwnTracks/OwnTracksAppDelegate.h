//
//  OwnTracksAppDelegate.h
//  OwnTracks
//
//  Created by Christoph Krey on 03.02.14.
//  Copyright © 2014-2024  OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>

#import <UserNotifications/UNUserNotificationCenter.h>

#import "LocationManager.h"
#import "Connection.h"
#import "Settings.h"

#import "Friend+CoreDataClass.h"
#import "Region+CoreDataClass.h"

#import "NavigationController.h"

#import <CocoaLumberjack/CocoaLumberjack.h>

@interface OwnTracksAppDelegate : UIResponder <UIApplicationDelegate, ConnectionDelegate, LocationManagerDelegate, UNUserNotificationCenterDelegate>

@property (strong, nonatomic) UIWindow * _Nullable window;
@property (weak, nonatomic) NavigationController * _Nullable navigationController;

@property (strong, nonatomic) NSString * _Nullable processingMessage;

@property (strong, nonatomic) Connection * _Nullable connection;
@property (strong, nonatomic) NSNumber * _Nullable connectionState;
@property (strong, nonatomic) NSNumber * _Nullable connectionBuffered;

@property (strong, nonatomic) NSDate * _Nullable configLoad;
@property (strong, nonatomic) NSString * _Nullable action;
@property (nonatomic) BOOL inRefresh;

@property (strong, nonatomic) DDFileLogger * _Nullable fl;


- (BOOL)sendNow:(CLLocation *_Nonnull)location
        withPOI:(nullable NSString *)poi
      withImage:(nullable NSData *)image
  withImageName:(nullable NSString *)imageName;
- (void)dump;
- (void)status;
- (void)waypoints;
- (void)sendRegion:(nonnull Region *)region;
- (void)sendEmpty:(nonnull NSString *)topic;
- (void)reconnect;
- (void)connectionOff;
- (void)terminateSession;

@end
