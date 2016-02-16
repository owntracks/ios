//
//  TBC.m
//  OwnTracks
//
//  Created by Christoph Krey on 21.06.15.
//  Copyright © 2015-2016 OwnTracks. All rights reserved.
//

#import "TabBarController.h"
#import "Settings.h"
#import "UIColor+WithName.h"
#import "OwnTracksAppDelegate.h"

@interface TabBarController ()
@property (strong, nonatomic) UIViewController *messageVC;
@property (strong, nonatomic) UIViewController *featuredVC;
@property (nonatomic) BOOL warning;
@end

@implementation TabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    
    for (UIViewController *vc in self.viewControllers) {
        if (vc.tabBarItem.tag == 99) {
            self.messageVC = vc;
        }
        if (vc.tabBarItem.tag == 98) {
            self.featuredVC = vc;
        }
    }
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate addObserver:self
               forKeyPath:@"action"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
    if ([keyPath isEqualToString:@"action"]) {
        [self performSelectorOnMainThread:@selector(adjust) withObject:nil waitUntilDone:YES];
    }
}

- (void)adjust {
    
    if (self.messageVC) {
        NSMutableArray *viewControllers = [[NSMutableArray alloc] initWithArray:self.viewControllers];
        
        if ([Settings boolForKey:SETTINGS_MESSAGING]) {
            if (![viewControllers containsObject:self.messageVC]) {
                [viewControllers insertObject:self.messageVC atIndex:viewControllers.count];
            }
        } else {
            if ([viewControllers containsObject:self.messageVC]) {
                [viewControllers removeObject:self.messageVC];
            }
        }
        [self setViewControllers:viewControllers animated:TRUE];
    }
    
    if (self.featuredVC) {
        NSMutableArray *viewControllers = [[NSMutableArray alloc] initWithArray:self.viewControllers];
        
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;

        if (delegate.action) {
            if (![viewControllers containsObject:self.featuredVC]) {
                [viewControllers insertObject:self.featuredVC atIndex:viewControllers.count];
            }
        } else {
            if ([viewControllers containsObject:self.featuredVC]) {
                [viewControllers removeObject:self.featuredVC];
            }
        }
        [self setViewControllers:viewControllers animated:TRUE];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.warning && [Settings intForKey:@"mode"] == 2) {
        self.warning = TRUE;
        [self performSegueWithIdentifier:@"login" sender:nil];
    }
}

@end
