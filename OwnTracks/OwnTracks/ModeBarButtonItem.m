//
//  ModeBarButtonItem.m
//  OwnTracks
//
//  Created by Christoph Krey on 30.06.15.
//  Copyright © 2015-2016 OwnTracks. All rights reserved.
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
        case LocationMonitoringMove:
            self.image = [UIImage imageNamed:@"MoveMode"];
            break;
        case LocationMonitoringSignificant:
            self.image = [UIImage imageNamed:@"SignificantMode"];
            break;
        case LocationMonitoringManual:
            self.image = [UIImage imageNamed:@"ManualMode"];
            break;
        case LocationMonitoringQuiet:
        default:
            self.image = [UIImage imageNamed:@"QuietMode"];
            break;
    }
}

- (void)pressed {
    switch ([LocationManager sharedInstance].monitoring) {
        case LocationMonitoringMove:
            [LocationManager sharedInstance].monitoring = LocationMonitoringSignificant;
            [AlertView alert:NSLocalizedString(@"Mode",
                                               @"Header of an alert message regarding monitoring mode")
                     message:NSLocalizedString(@"significant changes mode enabled",
                                               @"content of an alert message regarding monitoring mode")
                dismissAfter:1
             ];
            break;
            
        case LocationMonitoringQuiet:
            [LocationManager sharedInstance].monitoring = LocationMonitoringMove;
            [AlertView alert:NSLocalizedString(@"Mode",
                                               @"Header of an alert message regarding monitoring mode")
                     message:NSLocalizedString(@"move mode enabled",
                                               @"content of an alert message regarding monitoring mode")
                dismissAfter:1
             ];
            break;
            
        case LocationMonitoringManual:
            [LocationManager sharedInstance].monitoring = LocationMonitoringQuiet;
            [AlertView alert:NSLocalizedString(@"Mode",
                                               @"Header of an alert message regarding monitoring mode")
                     message:NSLocalizedString(@"quiet mode enabled",
                                               @"content of an alert message regarding monitoring mode")
                dismissAfter:1
             ];
            break;
            
        case LocationMonitoringSignificant:
        default:
            [LocationManager sharedInstance].monitoring = LocationMonitoringManual;
            [AlertView alert:NSLocalizedString(@"Mode",
                                               @"Header of an alert message regarding monitoring mode")
                     message:NSLocalizedString(@"manual mode enabled",
                                               @"content of an alert message regarding monitoring mode")
                dismissAfter:1
             ];

            break;
    }
    [Settings setInt:[LocationManager sharedInstance].monitoring forKey:@"monitoring_preference"];
}
@end
