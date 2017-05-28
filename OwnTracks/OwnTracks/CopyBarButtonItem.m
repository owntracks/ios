//
//  CopyBarButtonItem.m
//  OwnTracks
//
//  Created by Christoph Krey on 28.05.17.
//  Copyright © 2017 OwnTracks. All rights reserved.
//

#import "CopyBarButtonItem.h"
#import "OwnTracking.h"
#import "AlertView.h"
#import "Settings.h"

@implementation CopyBarButtonItem

- (instancetype)init {
    self = [super init];
    self.target = self;
    self.action = @selector(pressed);
    [[OwnTracking sharedInstance] addObserver:self
                                   forKeyPath:@"cp"
                                      options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                      context:nil];
    return self;
}

- (void)dealloc {
    [[OwnTracking sharedInstance] removeObserver:self
                                      forKeyPath:@"cp"];

}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([OwnTracking sharedInstance].cp) {
        self.image = [UIImage imageNamed:@"Copy"];
    } else {
        self.image = [UIImage imageNamed:@"NoCopy"];
    }
}

- (void)pressed {
    if ([OwnTracking sharedInstance].cp) {
            [OwnTracking sharedInstance].cp = FALSE;
            [AlertView alert:NSLocalizedString(@"Copying",
                                               @"Header of an alert message regarding copying")
                     message:NSLocalizedString(@"copying disabled",
                                               @"content of an alert message regarding copying disabled")
                dismissAfter:1
             ];
    } else {
        [OwnTracking sharedInstance].cp = TRUE;
        [AlertView alert:NSLocalizedString(@"Copying",
                                           @"Header of an alert message regarding copying")
                 message:NSLocalizedString(@"copying enabled",
                                           @"content of an alert message regarding copying enabled")
            dismissAfter:1
         ];
    }
    [Settings setBool:[OwnTracking sharedInstance].cp forKey:@"cp"];
}
@end
