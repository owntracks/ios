//
//  LoginVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.07.15.
//  Copyright © 2015-2018 OwnTracks. All rights reserved.
//

#import "LoginVC.h"
#import "Settings.h"
#import "CoreData.h"

@interface LoginVC ()
@property (weak, nonatomic) IBOutlet UITextView *UItext1;
@end

@implementation LoginVC

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([Setting existsSettingWithKey:@"mode" inMOC:CoreData.sharedInstance.mainMOC]) {
        [self dismissViewControllerAnimated:TRUE completion:^(void){
        }];
    }
    self.UItext1.text = NSLocalizedStringWithDefaultValue(@"Login_Text_1",
                                                          nil,
                                                          [NSBundle mainBundle],
                                                          @"You need to setup your own OwnTracks server and edit your configuration for full privacy protection.\n\n"
                                                          "Detailed info on https://owntracks.org/booklet",
                                                          @"Text explaining the Setup");
}

- (IBAction)continuePressed:(id)sender {
    [self dismissViewControllerAnimated:TRUE completion:^(void){
    }];
}

@end
