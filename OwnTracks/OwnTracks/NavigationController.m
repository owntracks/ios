//
//  NavigationController.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.06.15.
//  Copyright © 2015 -2019 OwnTracks. All rights reserved.
//

#import "NavigationController.h"
#import "OwnTracksAppDelegate.h"
#import "OwnTracking.h"

@interface NavigationController ()
@property (strong, nonatomic) UIProgressView *progressView;
@end

@implementation NavigationController
- (void)viewDidLoad {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    delegate.navigationController = self;

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
    self.navigationBar.translucent = false;
    self.navigationBar.barTintColor = [UIColor colorNamed:@"primaryColor"];
    self.navigationBar.tintColor = [UIColor colorNamed:@"primaryTintColor"];

    NSMutableDictionary *titleTextAttributes = [self.navigationBar.titleTextAttributes mutableCopy];
    if (!titleTextAttributes) {
        titleTextAttributes =
        [NSMutableDictionary dictionaryWithObject:[UIColor colorNamed:@"primaryTintColor"]
                                           forKey:NSForegroundColorAttributeName];
    }
    self.navigationBar.titleTextAttributes = titleTextAttributes;

    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate addObserver:self
               forKeyPath:@"connectionState"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:nil];
    [delegate addObserver:self
               forKeyPath:@"connectionBuffered"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate removeObserver:self
                  forKeyPath:@"connectionState"];
    [delegate removeObserver:self
                  forKeyPath:@"connectionBuffered"];

    [super viewWillDisappear:animated];
}


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    [self performSelectorOnMainThread:@selector(updateUI) withObject:nil waitUntilDone:NO];
}

- (void)updateUI {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    switch ((delegate.connectionState).intValue) {
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
UIAlertController *ac = [UIAlertController
                              alertControllerWithTitle:parameters[@"title"]
                              message:parameters[@"message"]
                              preferredStyle:UIAlertControllerStyleAlert];
#if !TARGET_OS_MACCATALYST
    // in MACCATALYST the UIAlert does not dismiss when told so.
    // This means we cannot dismiss it after a few seconds
    NSNumber *interval = parameters[@"interval"];
    if (!interval || interval.floatValue == 0.0) {
#endif
        UIAlertAction *ok = [UIAlertAction
                             actionWithTitle:NSLocalizedString(@"Continue",
                                                               @"Continue button title")

                             style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction * action) {}];
        [ac addAction:ok];
#if !TARGET_OS_MACCATALYST
    }
#endif
    [self presentViewController:ac animated:TRUE completion:nil];

#if !TARGET_OS_MACCATALYST
    // in MACCATALYST the UIAlert does not dismiss when told so.
    // This means we cannot dismiss it after a few seconds
    if (interval && interval.floatValue > 0.0) {
        [self performSelector:@selector(dismiss) withObject:nil afterDelay:interval.floatValue];
    }
#endif
}

- (void)dismiss {
    [self dismissViewControllerAnimated:TRUE completion:nil];
}

@end
