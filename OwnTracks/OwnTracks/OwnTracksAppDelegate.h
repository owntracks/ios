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
#import "Settings.h"
#import "Messaging.h"

#import "Friend+Create.h"
#import "Region+Create.h"

@interface OwnTracksAppDelegate : UIResponder <UIApplicationDelegate, ConnectionDelegate, LocationManagerDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) NSString *processingMessage;

@property (strong, nonatomic) Connection *connectionOut;
@property (strong, nonatomic) Connection *connectionIn;
@property (strong, nonatomic) Connection *connection;

@property (strong, nonatomic) NSNumber *connectionStateOut;
@property (strong, nonatomic) NSNumber *connectionBufferedOut;
@property (strong, nonatomic) NSNumber *inQueue;

@property (strong, nonatomic) NSDate *configLoad;

- (void)sendNow;
- (void)requestLocationFromFriend:(Friend *)friend;
- (void)sendRegion:(Region *)region;
- (void)sendEmpty:(NSString *)topic;
- (void)reconnect;
- (void)connectionOff;
- (void)syncProcessing;
- (void)terminateSession;

@end
