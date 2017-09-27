//
//  NavigationController.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.06.15.
//  Copyright © 2015-2017 OwnTracks. All rights reserved.
//

#import "NavigationController.h"
#import "OwnTracksAppDelegate.h"
#import "OwnTracking.h"
#import "UIColor+WithName.h"

@interface NavigationController ()
@property (strong, nonatomic) UIProgressView *progressView;
@end

@implementation NavigationController
- (void)viewDidLoad {
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    [self.view addSubview:self.progressView];
}

- (void)viewDidLayoutSubviews {
    self.progressView.frame = CGRectMake(0,
                                         self.navigationBar.frame.origin.y + self.navigationBar.frame.size.height - self.progressView.bounds.size.height,
                                         self.view.bounds.size.width,
                                         self.progressView.bounds.size.height);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationBar.translucent = false;
    self.navigationBar.barTintColor = [UIColor colorWithName:@"primary" defaultColor:[UIColor blackColor]];
    self.navigationBar.tintColor = [UIColor whiteColor];

    NSMutableDictionary *titleTextAttributes = [self.navigationBar.titleTextAttributes mutableCopy];
    if (!titleTextAttributes) {
        titleTextAttributes = [NSMutableDictionary dictionaryWithObject:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
    }
    self.navigationBar.titleTextAttributes = titleTextAttributes;
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate addObserver:self forKeyPath:@"connectionState"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    [delegate addObserver:self forKeyPath:@"connectionBuffered"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];

}

- (void)viewWillDisappear:(BOOL)animated {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate removeObserver:self forKeyPath:@"connectionState"];
    [delegate removeObserver:self forKeyPath:@"connectionBuffered"];

    [super viewWillDisappear:animated];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    switch ((delegate.connectionState).intValue) {
        case state_connected:
            self.progressView.progressTintColor = [UIColor colorWithName:@"connected" defaultColor:[UIColor whiteColor]];
                self.progressView.progress = 0.0;
            break;
        case state_starting:
            self.progressView.progressTintColor = [UIColor colorWithName:@"idle" defaultColor:[UIColor blueColor]];
            self.progressView.progress = 1.0;
            break;
        case state_closed:
        case state_closing:
        case state_connecting:
            self.progressView.progressTintColor = [UIColor colorWithName:@"connecting" defaultColor:[UIColor yellowColor]];
            self.progressView.progress = 1.0;
            break;
        case state_error:
            self.progressView.progressTintColor = [UIColor colorWithName:@"error" defaultColor:[UIColor redColor]];
            self.progressView.progress = 1.0;
            break;
    }
}

@end
