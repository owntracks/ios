//
//  SettingsInterfaceController.m
//  OwnTracksWrist WatchKit Extension
//
//  Created by Christoph Krey on 01.04.20.
//  Copyright © 2020 OwnTracks. All rights reserved.
//

#import "SettingsInterfaceController.h"

@interface SettingsInterfaceController ()
@property (weak, nonatomic) IBOutlet WKInterfaceTextField *url;
@property (weak, nonatomic) IBOutlet WKInterfaceTextField *tid;

@end

@implementation SettingsInterfaceController

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
}

- (IBAction)urlChanged:(NSString *)value {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:@"url"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction)tidChanged:(NSString *)value {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:@"tid"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)willActivate {
    [super willActivate];
    [self.url setText:[[NSUserDefaults standardUserDefaults] stringForKey:@"url"]];
    [self.tid setText:[[NSUserDefaults standardUserDefaults] stringForKey:@"tid"]];
}

- (void)didDeactivate {
    [super didDeactivate];
}

@end



