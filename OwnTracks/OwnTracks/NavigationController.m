//
//  NavigationController.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.06.15.
//  Copyright © 2015-2024  OwnTracks. All rights reserved.
//

#import "NavigationController.h"
#import "OwnTracksAppDelegate.h"
#import "OwnTracking.h"

@interface NavigationController ()
@property (strong, nonatomic) UIProgressView *progressView;
@property (strong, nonatomic) NSMutableArray *queuedAlerts;
@end

@implementation NavigationController
- (void)viewDidLoad {
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    ad.navigationController = self;
    self.queuedAlerts = [[NSMutableArray alloc] init];

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    [self.view addSubview:self.progressView];
}

- (void)viewDidLayoutSubviews {
    self.progressView.frame = CGRectMake(0,
                                         self.navigationBar.frame.origin.y +
                                         self.navigationBar.frame.size.height -
                                         self.progressView.bounds.size.height,
                                         self.view.bounds.size.width,
                                         self.progressView.bounds.size.height);
}

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
    [ad addObserver:self
         forKeyPath:@"processingMessage"
            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
            context:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [ad removeObserver:self
            forKeyPath:@"connectionState"];
    [ad removeObserver:self
            forKeyPath:@"connectionBuffered"];
    
    [super viewWillDisappear:animated];
}


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"processingMessage"]) {
        OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        if (ad.processingMessage) {
            [self alert:@"openURL" message:ad.processingMessage];
            ad.processingMessage = nil;
        }
    }

    [self performSelectorOnMainThread:@selector(updateUI) withObject:nil waitUntilDone:NO];
}

- (void)updateUI {
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    switch ((ad.connectionState).intValue) {
        case state_connected:
            self.progressView.progressTintColor = [UIColor colorNamed:@"connectedColor"];
                self.progressView.progress = 0.0;
            break;
        case state_starting:
            self.progressView.progressTintColor = [UIColor colorNamed:@"idleColor"];
            self.progressView.progress = 1.0;
            break;
        case state_closed:
        case state_closing:
        case state_connecting:
            self.progressView.progressTintColor = [UIColor colorNamed:@"connectingColor"];
            self.progressView.progress = 1.0;
            break;
        case state_error:
            self.progressView.progressTintColor = [UIColor colorNamed:@"connectionErrorColor"];
            self.progressView.progress = 1.0;
            break;
    }
}

- (void)alert:(NSString *)title
      message:(NSString *)message {
    [self alert:title message:message dismissAfter:0];
}

- (void)alert:(NSString *)title
      message:(NSString *)message
          url:(NSString *)url {
    [self performSelectorOnMainThread:@selector(alert:)
                           withObject:@{
                               @"title": title,
                               @"message": message,
                               @"url": url,
                               @"interval": [NSNumber numberWithFloat:0.0]
                           }
                        waitUntilDone:NO];

}

- (void)alert:(NSString *)title
      message:(NSString *)message
 dismissAfter:(NSTimeInterval)interval {
    [self performSelectorOnMainThread:@selector(alert:)
                           withObject:@{
                               @"title": title,
                               @"message": message,
                               @"interval": [NSNumber numberWithFloat:interval]
                           }
                        waitUntilDone:NO];
}

- (void)alert:(NSDictionary *)parameters {
    // in MACCATALYST the UIAlert does not dismiss when told so.
    // This means we cannot dismiss it after a few seconds

    if (self.presentedViewController) {
        [self.queuedAlerts addObject:parameters];
        return;
    }

    UIAlertController *ac =
    [UIAlertController alertControllerWithTitle:parameters[@"title"]
                                        message:parameters[@"message"]
                                 preferredStyle:UIAlertControllerStyleAlert];
    NSNumber *interval = parameters[@"interval"];
    if (!interval || interval.floatValue == 0.0) {
        UIAlertAction *ok = [UIAlertAction
                             actionWithTitle:NSLocalizedString(@"Continue",
                                                               @"Continue button title")

                             style:UIAlertActionStyleCancel
                             handler:^(UIAlertAction * action) {
            if (self.queuedAlerts.count > 0) {
                NSDictionary *parameters = self.queuedAlerts.firstObject;
                [self.queuedAlerts removeObjectAtIndex:0];
                [self alert:parameters];
            }
        }];
        [ac addAction:ok];
        if (parameters[@"url"]) {
            UIAlertAction *open = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"Open",
                                                                     @"Open button title")
                                   
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction * action) {
                NSURL *url = [NSURL URLWithString:parameters[@"url"]];
                [[UIApplication sharedApplication] openURL:url
                                                   options:@{}
                                         completionHandler:^(BOOL success) {
                    if (self.queuedAlerts.count > 0) {
                        NSDictionary *parameters = self.queuedAlerts.firstObject;
                        [self.queuedAlerts removeObjectAtIndex:0];
                        [self alert:parameters];
                    }
                }];
            }];
            [ac addAction:open];
        }
    }
    [self presentViewController:ac animated:TRUE completion:nil];

    if (interval && interval.floatValue > 0.0) {
        [self performSelector:@selector(dismiss) withObject:nil afterDelay:interval.floatValue];
    }
}

- (void)dismiss {
    [self dismissViewControllerAnimated:TRUE completion:nil];
}

@end
