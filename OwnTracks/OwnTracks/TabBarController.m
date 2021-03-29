//
//  TBC.m
//  OwnTracks
//
//  Created by Christoph Krey on 21.06.15.
//  Copyright © 2015-2021  OwnTracks. All rights reserved.
//

#import "TabBarController.h"
#import "Settings.h"
#import "OwnTracksAppDelegate.h"
#import "CoreData.h"

@interface TabBarController ()
@property (strong, nonatomic) UIViewController *featuredVC;
@property (strong, nonatomic) UIViewController *historyVC;
@property (strong, nonatomic) UIViewController *regionVC;
@property (strong, nonatomic) UIViewController *friendsVC;
@property (nonatomic) BOOL warning;
@end

@implementation TabBarController

- (void)viewDidLoad {
    [super viewDidLoad];

    for (UIViewController *vc in self.viewControllers) {
        if (vc.tabBarItem.tag == 95) {
            self.friendsVC = vc;
        }
        if (vc.tabBarItem.tag == 96) {
            self.regionVC = vc;
        }
        if (vc.tabBarItem.tag == 97) {
            self.historyVC = vc;
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

    [[NSNotificationCenter defaultCenter] addObserverForName:@"reload"
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note){
                                                      [self performSelectorOnMainThread:@selector(adjust)
                                                                             withObject:nil
                                                                          waitUntilDone:NO];
                                                  }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
    if ([keyPath isEqualToString:@"action"]) {
        [self performSelectorOnMainThread:@selector(adjust) withObject:nil waitUntilDone:NO];
    }
}

- (void)adjust {
    NSMutableArray *viewControllers = [[NSMutableArray alloc] initWithArray:self.viewControllers];

    if (self.featuredVC) {
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;

        if (delegate.action) {
            if (![viewControllers containsObject:self.featuredVC]) {
                [viewControllers insertObject:self.featuredVC
                                      atIndex:viewControllers.count];
                self.featuredVC.tabBarItem.badgeValue = NSLocalizedString(@"!",
                                                                          @"New featured content indicator");
            }
        } else {
            if ([viewControllers containsObject:self.featuredVC]) {
                [viewControllers removeObject:self.featuredVC];
            }
        }
    }

    if (self.historyVC) {
        if ([Settings theMaximumHistoryInMOC:[CoreData sharedInstance].mainMOC]) {
            if (![viewControllers containsObject:self.historyVC]) {
                if ([viewControllers containsObject:self.featuredVC]) {
                    [viewControllers insertObject:self.historyVC
                                          atIndex:viewControllers.count - 1];
                } else {
                    [viewControllers insertObject:self.historyVC
                                          atIndex:viewControllers.count];
                }
            }
        } else {
            if ([viewControllers containsObject:self.historyVC]) {
                [viewControllers removeObject:self.historyVC];
            }
        }
    }
    [self setViewControllers:viewControllers animated:TRUE];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.warning &&
        ![Setting existsSettingWithKey:@"mode" inMOC:CoreData.sharedInstance.mainMOC]) {
        self.warning = TRUE;
        [self performSegueWithIdentifier:@"login" sender:nil];
    }
}


@end
