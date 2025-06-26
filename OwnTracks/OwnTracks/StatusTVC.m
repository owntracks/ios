//
//  StatusTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 11.09.13.
//  Copyright © 2013-2025  Christoph Krey. All rights reserved.
//

#import "StatusTVC.h"
#import "Connection.h"
#import "OwnTracksAppDelegate.h"
#import "Settings.h"
#import "SettingsTVC.h"
#import "CoreData.h"
#import "Waypoint+CoreDataClass.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface StatusTVC ()
@property (weak, nonatomic) IBOutlet UITextField *UILocation;
@property (weak, nonatomic) IBOutlet UITextField *UIpressure;
@property (weak, nonatomic) IBOutlet UITextField *UImotionActivities;
@property (weak, nonatomic) IBOutlet UITextView *UIparameters;
@property (weak, nonatomic) IBOutlet UITextView *UIstatusField;
@property (weak, nonatomic) IBOutlet UITextField *UIVersion;
@property (weak, nonatomic) IBOutlet UITextField *UItrackpoints;
@property (weak, nonatomic) IBOutlet UIButton *UIexportTrack;

@property (strong, nonatomic) UIDocumentInteractionController *dic;
@end

@implementation StatusTVC
static const DDLogLevel ddLogLevel = DDLogLevelInfo;

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [ad addObserver:self
         forKeyPath:@"connectionState"
            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
            context:nil];
    [ad addObserver:self
         forKeyPath:@"connectionBuffered"
            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
            context:nil];
    [[LocationManager sharedInstance] addObserver:self
                                       forKeyPath:@"lastUsedLocation"
                                          options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                          context:nil];
    [[LocationManager sharedInstance] addObserver:self
                                       forKeyPath:@"altitudeData"
                                          options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                          context:nil];
    [[LocationManager sharedInstance] addObserver:self
                                       forKeyPath:@"motionActivity"
                                          options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                          context:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [ad removeObserver:self
            forKeyPath:@"connectionState"
               context:nil];
    [ad removeObserver:self
            forKeyPath:@"connectionBuffered"
               context:nil];
    [[LocationManager sharedInstance] removeObserver:self
                                          forKeyPath:@"lastUsedLocation"
                                             context:nil];
    [[LocationManager sharedInstance] removeObserver:self
                                          forKeyPath:@"altitudeData"
                                             context:nil];
    [[LocationManager sharedInstance] removeObserver:self
                                          forKeyPath:@"motionActivity"
                                             context:nil];
    [super viewWillDisappear:animated];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    DDLogVerbose(@"observeValueForKeyPath %@", keyPath);
    [self performSelectorOnMainThread:@selector(updatedStatus) withObject:nil waitUntilDone:NO];
}

- (void)updatedStatus {
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    
    const NSDictionary<NSNumber *, NSString *> *states;
    states = @{
               @(state_starting):   NSLocalizedString(@"idle",
                                                      @"description connection idle state"),
               @(state_connecting): NSLocalizedString(@"connecting",
                                                      @"description connection connected state"),
               @(state_error):      NSLocalizedString(@"error",
                                                      @"description connection error state"),
               @(state_connected):  NSLocalizedString(@"connected",
                                                      @"description connection connected state"),
               @(state_closing):    NSLocalizedString(@"closing",
                                                      @"description connection closing state"),
               @(state_closed):     NSLocalizedString(@"closed",
                                                      @"description connection closed state")
               };
    
    NSString *stateName = [NSString stringWithFormat:@"%@ (%@)",
                           NSLocalizedString(@"unknown state", @"description connection unknown state"),
                           ad.connectionState];
    if (ad.connectionState) {
        stateName = states[ad.connectionState];
        if (!stateName) {
            stateName = ad.connectionState.description;
        }
    }
    
    self.UIstatusField.text = [NSString stringWithFormat:@"%@ %@ %@ %@ %@",
                               stateName,
                               ad.connection.lastErrorCode ?
                               ad.connection.lastErrorCode.domain : @"",
                               ad.connection.lastErrorCode ?
                               [NSString stringWithFormat:@"%ld", ad.connection.lastErrorCode.code] : @"",
                               ad.connection.lastErrorCode ?
                               ad.connection.lastErrorCode.localizedDescription : @"",
                               ad.connection.lastErrorCode ?
                               ad.connection.lastErrorCode.userInfo : @""
                               ];
    
    CLLocation *location = [LocationManager sharedInstance].location;

    if (location) {
        self.UILocation.text = [Waypoint CLLocationCoordinateText:location];
    } else {
        self.UILocation.text =NSLocalizedString( @"No location recorded",  @"No location recorded indication");
    }

    if ([LocationManager sharedInstance].altitudeData) {
        NSMeasurement *m = [[NSMeasurement alloc] initWithDoubleValue:[LocationManager sharedInstance].altitudeData.pressure.doubleValue
                                                                 unit:[NSUnitPressure kilopascals]];
        NSMeasurementFormatter *mf = [[NSMeasurementFormatter alloc] init];
        mf.unitOptions = NSMeasurementFormatterUnitOptionsNaturalScale;
        mf.numberFormatter.maximumFractionDigits = 3;
        self.UIpressure.text = [mf stringFromMeasurement:m];
    } else {
        self.UIpressure.text = NSLocalizedString( @"No pressure available",  @"No pressure available");
    }

    if (self.UIparameters) {
        self.UIparameters.text = (ad.connection).parameters;
    }
    
    NSString *motionActivities = @"()";
    CMMotionActivity *motionActivity = [LocationManager sharedInstance].motionActivity;
    if (motionActivity != nil) {
        switch (motionActivity.confidence) {
            case CMMotionActivityConfidenceLow:
                motionActivities = @"(L)";
                break;
                
            case CMMotionActivityConfidenceMedium:
                motionActivities = @"(M)";
                break;
                
            case CMMotionActivityConfidenceHigh:
                motionActivities = @"(H)";
                break;
        }
        
        if (motionActivity.stationary) {
            motionActivities = [motionActivities stringByAppendingFormat:@" stationary"];
        }
        if (motionActivity.walking) {
            motionActivities = [motionActivities stringByAppendingFormat:@" walking"];
        }
        if (motionActivity.running) {
            motionActivities = [motionActivities stringByAppendingFormat:@" running"];
        }
        if (motionActivity.automotive) {
            motionActivities = [motionActivities stringByAppendingFormat:@" automotive"];
        }
        if (motionActivity.cycling) {
            motionActivities = [motionActivities stringByAppendingFormat:@" cycling"];
        }
        if (motionActivity.unknown) {
            motionActivities = [motionActivities stringByAppendingFormat:@" unknown"];
        }
    }
    self.UImotionActivities.text = motionActivities;

    self.UIVersion.text = [NSString stringWithFormat:@"%@/%@",
                           [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"],
                           [NSLocale currentLocale].localeIdentifier
                           ];

    NSString *topic = [Settings theGeneralTopicInMOC:[CoreData sharedInstance].mainMOC];
    Friend *myself = [Friend existsFriendWithTopic:topic
                            inManagedObjectContext:[CoreData sharedInstance].mainMOC];
    self.UItrackpoints.text = [NSString stringWithFormat:@"%ld", myself.hasWaypoints.count];
    
    [self.tableView setNeedsDisplay];
}

- (IBAction)sendDebugStatusPressed:(UIButton *)sender {
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [ad status];
}

- (IBAction)webPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://owntracks.org"]
                                       options:@{}
                             completionHandler:nil];
}
- (IBAction)githubPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/owntracks/talk"]
                                       options:@{}
                             completionHandler:nil];
}
- (IBAction)mastodonPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://fosstodon.org/@owntracks"]
                                       options:@{}
                             completionHandler:nil];
}

- (IBAction)documentationPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://owntracks.org/booklet"]
                                       options:@{}
                             completionHandler:nil];
}

- (IBAction)exportTrackPressed:(UIButton *)sender {
    NSError *error;

    NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                 inDomain:NSUserDomainMask
                                                        appropriateForURL:nil
                                                                   create:YES
                                                                    error:&error];
    NSString *fileName = [NSString stringWithFormat:@"track.gpx"];
    NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];

    NSString *topic = [Settings theGeneralTopicInMOC:[CoreData sharedInstance].mainMOC];
    Friend *myself = [Friend existsFriendWithTopic:topic
                            inManagedObjectContext:[CoreData sharedInstance].mainMOC];

    NSOutputStream *output = [NSOutputStream outputStreamWithURL:fileURL append:FALSE];
    [output open];
    [myself trackToGPX:output];
    [output close];
    
    self.dic = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    self.dic.delegate = self;

    [self.dic presentOptionsMenuFromRect:self.UIexportTrack.frame inView:self.UIexportTrack animated:TRUE];
}

- (NSIndexPath *)tableView:(UITableView *)tableView
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && indexPath.row == 0) {
        CLLocation *location = [LocationManager sharedInstance].location;
        if (location) {
            NSString *locationString = [NSString stringWithFormat:@"%g,%g",
                                        location.coordinate.latitude,
                                        location.coordinate.longitude
                                        ];
            UIPasteboard *generalPasteboard = [UIPasteboard generalPasteboard];
            [generalPasteboard setString:locationString];
            [NavigationController alert:NSLocalizedString(@"Clipboard",
                                                          @"Clipboard")
                                message:NSLocalizedString(@"Location copied to clipboard",
                                                          @"Location copied to clipboard")
                           dismissAfter:1
            ];
        }
    }
    return nil;
}

@end
