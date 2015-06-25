//
//  TBC.m
//  OwnTracks
//
//  Created by Christoph Krey on 21.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "TabBarController.h"
#import "Settings.h"

@interface TabBarController ()
@property (strong, nonatomic) UIViewController *messageVC;
@end

@implementation TabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    for (UIViewController *vc in self.viewControllers) {
        if (vc.tabBarItem.tag == 99) {
            self.messageVC = vc;
        }
    }
    [self adjust];
}

- (void)adjust {
    if (self.messageVC) {
        NSMutableArray *viewControllers = [[NSMutableArray alloc] initWithArray:self.viewControllers];
        
        if ([Settings boolForKey:SETTINGS_MESSAGING]) {
            if (![viewControllers containsObject:self.messageVC]) {
                [viewControllers insertObject:self.messageVC atIndex:viewControllers.count - 1];
            }
        } else {
            if ([viewControllers containsObject:self.messageVC]) {
                [viewControllers removeObject:self.messageVC];
            }
        }
        [self setViewControllers:viewControllers animated:TRUE];
    }
}

@end
