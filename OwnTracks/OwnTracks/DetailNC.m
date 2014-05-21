//
//  DetailNC.m
//  OwnTracks
//
//  Created by Christoph Krey on 21.05.14.
//  Copyright (c) 2014 OwnTracks. All rights reserved.
//

#import "DetailNC.h"
#import "ViewController.h"

@interface DetailNC ()

@end

@implementation DetailNC

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UISplitViewController *splitViewController;
    
    if (self.splitViewController) {
        splitViewController = self.splitViewController;
    }
    
    if (splitViewController) {
        splitViewController.delegate = self;
    }
}

- (BOOL)splitViewController:(UISplitViewController *)svc
   shouldHideViewController:(UIViewController *)vc
              inOrientation:(UIInterfaceOrientation)orientation
{
    return YES;
}

- (void)splitViewController:(UISplitViewController *)svc
          popoverController:(UIPopoverController *)pc
  willPresentViewController:(UIViewController *)aViewController
{
    //
}

- (void)splitViewController:(UISplitViewController *)svc
     willHideViewController:(UIViewController *)aViewController
          withBarButtonItem:(UIBarButtonItem *)barButtonItem
       forPopoverController:(UIPopoverController *)pc
{
    if ([self.topViewController respondsToSelector:@selector(showRootPopoverButtonItem:)]) {
        [self.topViewController performSelector:@selector(showRootPopoverButtonItem:) withObject:barButtonItem];
    }
}

- (void)splitViewController:(UISplitViewController *)svc
     willShowViewController:(UIViewController *)aViewController
  invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    if ([self.topViewController respondsToSelector:@selector(invalidateRootPopoverButtonItem:)]) {
        [self.topViewController performSelector:@selector(invalidateRootPopoverButtonItem:) withObject:barButtonItem];
    }
}

@end
