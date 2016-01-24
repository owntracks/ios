//
//  FeaturedContentVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 23.01.16.
//  Copyright © 2016 OwnTracks. All rights reserved.
//

#import "FeaturedContentVC.h"
#import "Settings.h"
#import "TabBarController.h"
#import "OwnTracksAppDelegate.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface FeaturedContentVC ()
@property (weak, nonatomic) IBOutlet UITextView *UIcontent;

@end

@implementation FeaturedContentVC
static const DDLogLevel ddLogLevel = DDLogLevelError;

- (void)viewDidLoad {
    [super viewDidLoad];
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
    DDLogVerbose(@"observeValueForKeyPath %@", keyPath);
    
    if ([keyPath isEqualToString:@"action"]) {
        [self performSelectorOnMainThread:@selector(updated) withObject:nil waitUntilDone:NO];
    }
}

- (void)updated {
    NSString *content = [Settings stringForKey:SETTINGS_ACTION];
    if (content) {
        self.UIcontent.text = content;
    } else {
        self.UIcontent.text = @"Currently no featured content available";
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updated];
}
@end
