//
//  StatusTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 11.09.13.
//  Copyright © 2013-2020  Christoph Krey. All rights reserved.
//

#import "StatusTVC.h"
#import "Connection.h"
#import "OwnTracksAppDelegate.h"
#import "Settings.h"
#import "SettingsTVC.h"
#import "CoreData.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface StatusTVC ()
@property (weak, nonatomic) IBOutlet UITextField *UILocation;
@property (weak, nonatomic) IBOutlet UITextView *UIparameters;
@property (weak, nonatomic) IBOutlet UITextView *UIstatusField;
@property (weak, nonatomic) IBOutlet UITextField *UIVersion;

@end

@implementation StatusTVC
static const DDLogLevel ddLogLevel = DDLogLevelInfo;

- (void)viewWillAppear:(BOOL)animated {
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
}

- (void)viewWillDisappear:(BOOL)animated {
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
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    
    const NSDictionary<NSNumber *, NSString *> *states;
    states = @{
               @(state_starting):   NSLocalizedString(@"idle",          @"description connection idle state"),
               @(state_connecting): NSLocalizedString(@"connecting",    @"description connection connected state"),
               @(state_error):      NSLocalizedString(@"error",         @"description connection error state"),
               @(state_connected):  NSLocalizedString(@"connected",     @"description connection connected state"),
               @(state_closing):    NSLocalizedString(@"closing",       @"description connection closing state"),
               @(state_closed):     NSLocalizedString(@"closed",        @"description connection closed state")
               };
    
    NSString *stateName = [NSString stringWithFormat:@"%@ (%@)",
                           NSLocalizedString(@"unknown state", @"description connection unknown state"),
                           delegate.connectionState];
    if (delegate.connectionState) {
        stateName = states[delegate.connectionState];
        if (!stateName) {
            stateName = delegate.connectionState.description;
        }
    }
    
    self.UIstatusField.text = [NSString stringWithFormat:@"%@ %@ %@ %@ %@",
                               stateName,
                               delegate.connection.lastErrorCode ?
                               delegate.connection.lastErrorCode.domain : @"",
                               delegate.connection.lastErrorCode ?
                               [NSString stringWithFormat:@"%ld", delegate.connection.lastErrorCode.code] : @"",
                               delegate.connection.lastErrorCode ?
                               delegate.connection.lastErrorCode.localizedDescription : @"",
                               delegate.connection.lastErrorCode ?
                               delegate.connection.lastErrorCode.userInfo : @""
                               ];
    
    if ([LocationManager sharedInstance].location) {
        self.UILocation.text = [NSString stringWithFormat:@"%g,%g (%@%.0f%@)",
                                [LocationManager sharedInstance].location.coordinate.latitude,
                                [LocationManager sharedInstance].location.coordinate.longitude,
                                NSLocalizedString(@"±", @"Short for deviation plus/minus"),
                                [LocationManager sharedInstance].location.horizontalAccuracy,
                                NSLocalizedString(@"m", @"Short for meters")
                                ];
    } else {
        self.UILocation.text =NSLocalizedString( @"No location available",  @"No location available indication");
    }

    if (self.UIparameters) {
        self.UIparameters.text = (delegate.connection).parameters;
    }
    
    self.UIVersion.text = [NSString stringWithFormat:@"%@/%@",
                           [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"],
                           [NSLocale currentLocale].localeIdentifier
                           ];

    [self.tableView setNeedsDisplay];
}

- (IBAction)talkPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/owntracks/talk"]
                                       options:@{}
                             completionHandler:nil];
}

- (IBAction)documentationPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://owntracks.org/booklet"]
                                       options:@{}
                             completionHandler:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"privileged"]) {
        if ([segue.destinationViewController isKindOfClass:[SettingsTVC class]]) {
            SettingsTVC *settingsTVC = (SettingsTVC *)segue.destinationViewController;
            settingsTVC.privileged = TRUE;
        }
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && indexPath.row == 0) {
        if ([LocationManager sharedInstance].location) {
            NSString *locationString = [NSString stringWithFormat:@"%g,%g",
                                        [LocationManager sharedInstance].location.coordinate.latitude,
                                        [LocationManager sharedInstance].location.coordinate.longitude
                                        ];
            UIPasteboard *generalPasteboard = [UIPasteboard generalPasteboard];
            [generalPasteboard setString:locationString];
            OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
            [delegate.navigationController alert:NSLocalizedString(@"Clipboard",
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
