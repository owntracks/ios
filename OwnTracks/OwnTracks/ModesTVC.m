//
//  ModesTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.03.21.
//  Copyright © 2021-2024 OwnTracks. All rights reserved.
//

#import "ModesTVC.h"

@interface ModesTVC ()
@property (weak, nonatomic) IBOutlet UITextView *mqttDescription;
@property (weak, nonatomic) IBOutlet UITextView *httpDescription;
@property (weak, nonatomic) IBOutlet UITextView *pleaseNote;

@end

@implementation ModesTVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mqttDescription.text = NSLocalizedString(@"Setup your own OwnTracks server for full privacy protection. More Info on https://owntracks.org/booklet", @"MQTT Description Text");
    self.httpDescription.text = NSLocalizedString(@"Similar to MQTT mode, except data transmission uses HTTP, not MQTT.", @"HTTP Description Text");
    self.pleaseNote.text = NSLocalizedString(@"When switching between modes, all OwnTracks data will be deleted for privacy reasons.", @"Please Note Text");
}


@end
