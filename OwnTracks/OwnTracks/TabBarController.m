//
//  TBC.m
//  OwnTracks
//
//  Created by Christoph Krey on 21.06.15.
//  Copyright © 2015-2024  OwnTracks. All rights reserved.
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

    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [ad addObserver:self
         forKeyPath:@"action"
            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
            context:nil];
    
    [[NSNotificationCenter defaultCenter]
     addObserverForName:@"reload"
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
        [self performSelectorOnMainThread:@selector(adjust)
                               withObject:nil
                            waitUntilDone:NO];
    }
}

- (void)adjust {
    
    NSMutableArray *viewControllers = [[NSMutableArray alloc] initWithArray:self.viewControllers];

    if (self.featuredVC) {
        OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;

        if (ad.action) {
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
    
    if (self.regionVC) {
        if (![Settings theLockedInMOC:CoreData.sharedInstance.mainMOC]) {
            if (![viewControllers containsObject:self.regionVC]) {
                if ([viewControllers containsObject:self.featuredVC]) {
                    if ([viewControllers containsObject:self.historyVC]) {
                        [viewControllers insertObject:self.regionVC
                                              atIndex:viewControllers.count - 2];
                    } else {
                        [viewControllers insertObject:self.regionVC
                                              atIndex:viewControllers.count - 1];
                    }
                } else {
                    if ([viewControllers containsObject:self.historyVC]) {
                        [viewControllers insertObject:self.regionVC
                                              atIndex:viewControllers.count - 1];
                    } else {
                        [viewControllers insertObject:self.regionVC
                                              atIndex:viewControllers.count];
                    }
                }
            }
        } else {
            if ([viewControllers containsObject:self.regionVC]) {
                [viewControllers removeObject:self.regionVC];
            }
        }
    }

    [self setViewControllers:viewControllers animated:FALSE];
}

@end
