//
//  NavigationController.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "NavigationController.h"
#import "OwnTracksAppDelegate.h"
#import "OwnTracking.h"
#import "UIColor+WithName.h"

@interface NavigationController ()

@end

@implementation NavigationController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationBar.translucent = false;
    self.navigationBar.barTintColor = [UIColor colorWithName:@"primary" defaultColor:[UIColor blackColor]];
    self.navigationBar.tintColor = [UIColor whiteColor];
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate addObserver:self forKeyPath:@"connectionStateOut"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    [delegate addObserver:self forKeyPath:@"connectionBufferedOut"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    [[OwnTracking sharedInstance] addObserver:self forKeyPath:@"inQueue"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];

}

- (void)viewWillDisappear:(BOOL)animated {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate removeObserver:self forKeyPath:@"connectionStateOut"];
    [delegate removeObserver:self forKeyPath:@"connectionBufferedOut"];
    [[OwnTracking sharedInstance] removeObserver:self forKeyPath:@"inQueue"];

    [super viewWillDisappear:animated];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    NSMutableDictionary *titleTextAttributes = [self.navigationBar.titleTextAttributes mutableCopy];
    if (!titleTextAttributes) {
        titleTextAttributes = [[NSMutableDictionary alloc] init];
    }
    switch ([delegate.connectionStateOut intValue]) {
        case state_connected:
            titleTextAttributes[NSForegroundColorAttributeName] = [UIColor colorWithName:@"connected" defaultColor:[UIColor whiteColor]];
            break;
        case state_starting:
            titleTextAttributes[NSForegroundColorAttributeName] = [UIColor colorWithName:@"idle" defaultColor:[UIColor blueColor]];
            break;
        case state_closed:
        case state_closing:
        case state_connecting:
            titleTextAttributes[NSForegroundColorAttributeName] = [UIColor colorWithName:@"connecting" defaultColor:[UIColor yellowColor]];
            break;
        case state_error:
            titleTextAttributes[NSForegroundColorAttributeName] = [UIColor colorWithName:@"error" defaultColor:[UIColor redColor]];

            break;
    }
    self.navigationBar.titleTextAttributes = titleTextAttributes;
}

@end
