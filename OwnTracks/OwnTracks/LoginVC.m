//
//  LoginVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.07.15.
//  Copyright © 2015-2017 OwnTracks. All rights reserved.
//

#import "LoginVC.h"
#import "Settings.h"

@interface LoginVC ()
@end

@implementation LoginVC

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([Settings intForKey:@"mode"] != CONNECTION_MODE_PUBLIC) {
        [self dismissViewControllerAnimated:TRUE completion:^(void){
        }];
    }
}

- (IBAction)continuePressed:(id)sender {
    [self dismissViewControllerAnimated:TRUE completion:^(void){
    }];
}

@end
