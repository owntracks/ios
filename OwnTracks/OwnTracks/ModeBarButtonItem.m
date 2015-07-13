//
//  ModeBarButtonItem.m
//  OwnTracks
//
//  Created by Christoph Krey on 30.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "ModeBarButtonItem.h"
#import "LocationManager.h"
#import "AlertView.h"
#import "Settings.h"

@implementation ModeBarButtonItem
- (instancetype)init {
    self = [super init];
    self.target = self;
    self.action = @selector(pressed);
    [[LocationManager sharedInstance] addObserver:self
                                       forKeyPath:@"monitoring"
                                          options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                          context:nil];
    return self;
}

- (void)dealloc {
    [[LocationManager sharedInstance] removeObserver:self
                                          forKeyPath:@"monitoring"];

}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    switch ([LocationManager sharedInstance].monitoring) {
        case 2:
            self.image = [UIImage imageNamed:@"FastMode"];
            break;
        case 1:
            self.image = [UIImage imageNamed:@"PlayMode"];
            break;
        case 0:
        default:
            self.image = [UIImage imageNamed:@"StopMode"];
            break;
    }
}

- (void)pressed {
    switch ([LocationManager sharedInstance].monitoring) {
        case 0:
            [LocationManager sharedInstance].monitoring = 1;
            [AlertView alert:@"Mode" message:@"significant changes mode enabled" dismissAfter:1];
            break;
        case 1:
            [LocationManager sharedInstance].monitoring = 2;
            [AlertView alert:@"Mode" message:@"move mode enabled" dismissAfter:1];
            break;
        case 2:
        default:
            [LocationManager sharedInstance].monitoring = 0;
            [AlertView alert:@"Mode" message:@"manual mode enabled" dismissAfter:1];
            break;
    }
    [Settings setInt:[LocationManager sharedInstance].monitoring forKey:@"monitoring_preference"];
}
@end
