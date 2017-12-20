//
//  LoginVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.07.15.
//  Copyright © 2015-2017 OwnTracks. All rights reserved.
//

#import "LoginVC.h"
#import "Settings.h"
#import "CoreData.h"

@interface LoginVC ()
@property (weak, nonatomic) IBOutlet UITextView *UItext2;
@property (weak, nonatomic) IBOutlet UITextView *UItext1;
@end

@implementation LoginVC

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([Settings intForKey:@"mode" inMOC:CoreData.sharedInstance.mainMOC] != CONNECTION_MODE_PUBLIC) {
        [self dismissViewControllerAnimated:TRUE completion:^(void){
        }];
    }
    self.UItext1.text = NSLocalizedStringWithDefaultValue(@"Login_Text_1",
                                                          nil,
                                                          [NSBundle mainBundle],
                                                          @"In Public Mode, you can get an impression of OwnTracks functionality.\n\n"
                                                          "If you press continue you will be starting OwnTracks in Public Mode. In this mode, your location is published anonymously to owntracks.org's shared broker and will be shared with all other users in public mode. Your data will not be stored and will only be forwarded to users connected at the same time.",
                                                          @"Text explaining the purpose and dangers of Public Mode");
    
    self.UItext2.text = NSLocalizedStringWithDefaultValue(@"Login_Text_2",
                                                          nil,
                                                          [NSBundle mainBundle],
                                                          @"Or you may setup your own OwnTracks server for full privacy protection.\n\n"
                                                          "Detailed info on http://owntracks.org/booklet",
                                                          @"Text linking to documentation");
}

- (IBAction)continuePressed:(id)sender {
    [self dismissViewControllerAnimated:TRUE completion:^(void){
    }];
}

@end
