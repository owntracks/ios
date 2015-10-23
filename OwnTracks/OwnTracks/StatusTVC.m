//
//  StatusTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 11.09.13.
//  Copyright (c) 2013-2015 Christoph Krey. All rights reserved.
//

#import "StatusTVC.h"
#import "Connection.h"
#import "OwnTracksAppDelegate.h"
#import "Settings.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface StatusTVC ()
@property (weak, nonatomic) IBOutlet UITextField *UILocation;
@property (weak, nonatomic) IBOutlet UITextField *UIGeoHash;
@property (weak, nonatomic) IBOutlet UITextView *UIparameters;
@property (weak, nonatomic) IBOutlet UITextView *UIstatusField;
@property (weak, nonatomic) IBOutlet UITextField *UIVersion;

@end

@implementation StatusTVC
static const DDLogLevel ddLogLevel = DDLogLevelError;

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate addObserver:self
               forKeyPath:@"connectionState"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:nil];
    [delegate addObserver:self
               forKeyPath:@"connectionBuffered"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:nil];
    [[LocationManager sharedInstance] addObserver:self
                                       forKeyPath:@"location"
                                          options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                          context:nil];
    [[Messaging sharedInstance] addObserver:self
                                 forKeyPath:@"lastGeoHash"
                                    options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                    context:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate removeObserver:self
                  forKeyPath:@"connectionState"
                     context:nil];
    [delegate removeObserver:self
                  forKeyPath:@"connectionBuffered"
                     context:nil];
    [[LocationManager sharedInstance] removeObserver:self
                                          forKeyPath:@"location"
                                             context:nil];
    [[Messaging sharedInstance] removeObserver:self
                                    forKeyPath:@"lastGeoHash"
                                       context:nil];
    
    [super viewWillDisappear:animated];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    DDLogVerbose(@"observeValueForKeyPath %@", keyPath);
    [self performSelectorOnMainThread:@selector(updatedStatus) withObject:nil waitUntilDone:NO];
}

- (void)updatedStatus
{
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    
    const NSDictionary *states = @{
                                   @(state_starting): @"idle",
                                   @(state_connecting): @"connecting",
                                   @(state_error): @"error",
                                   @(state_connected): @"connected",
                                   @(state_closing): @"closing",
                                   @(state_closed): @"closed"
                                   };
    
    self.UIstatusField.text = [NSString stringWithFormat:@"%@ %@ %@",
                               states[delegate.connectionState],
                               delegate.connection.lastErrorCode ?
                               delegate.connection.lastErrorCode.localizedDescription : @"",
                               delegate.connection.lastErrorCode ?
                               delegate.connection.lastErrorCode.userInfo : @""
                               ];
    
    if ([LocationManager sharedInstance].location) {
        self.UILocation.text = [NSString stringWithFormat:@"%g,%g (±%.0fm)",
                                [LocationManager sharedInstance].location.coordinate.latitude,
                                [LocationManager sharedInstance].location.coordinate.longitude,
                                [LocationManager sharedInstance].location.horizontalAccuracy
                                ];
    } else {
        self.UILocation.text = @"No location available";
    }
    if ([Messaging sharedInstance].lastGeoHash) {
        self.UIGeoHash.text = [Messaging sharedInstance].lastGeoHash;
    } else {
        self.UIGeoHash.text = @"No geo hash available";
    }
    
    int mode = [Settings intForKey:@"mode"];
    if (self.UIparameters) {
        if (mode == 1) {
            self.UIparameters.text = @"Hosted";
        } else if (mode == 2) {
            self.UIparameters.text = @"Public";
        } else {
            self.UIparameters.text = [delegate.connection parameters];
        }
    }
    
    self.UIVersion.text = [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"];    

    [self.tableView setNeedsDisplay];
}

- (IBAction)documentationPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:
     [NSURL URLWithString:@"http://owntracks.org/booklet"]];
}

@end
