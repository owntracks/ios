//
//  LoginVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.07.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "LoginVC.h"
#import "OwnTracksAppDelegate.h"
#import "Settings.h"

@interface LoginVC ()
@property (weak, nonatomic) IBOutlet UITextField *UIuser;
@property (weak, nonatomic) IBOutlet UITextField *UIdevice;
@property (weak, nonatomic) IBOutlet UITextField *UItoken;

@end

@implementation LoginVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appEnteredBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.UIuser.delegate = self;
    self.UIdevice.delegate = self;
    self.UItoken.delegate = self;

    if ([Settings intForKey:@"mode"] != 2) {
        [self dismissViewControllerAnimated:TRUE completion:^(void){
        }];
    }
}

- (void)appEnteredBackground{
    [self.UIuser resignFirstResponder];
    [self.UIdevice resignFirstResponder];
    [self.UItoken resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return TRUE;
}

- (IBAction)continuePressed:(UIButton *)sender {
    [self dismissViewControllerAnimated:TRUE completion:^(void){
    }];
}

- (IBAction)loginPressed:(UIButton *)sender {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate terminateSession];

    [Settings setInt:1 forKey:@"mode"];
    if (self.UIuser) [Settings setString:self.UIuser.text forKey:@"user"];
    if (self.UIdevice) [Settings setString:self.UIdevice.text forKey:@"device"];
    if (self.UItoken) [Settings setString:self.UItoken.text forKey:@"token"];

    [delegate reconnect];
    [self dismissViewControllerAnimated:TRUE completion:^(void){
    }];
}

- (IBAction)registerPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:
     [NSURL URLWithString:@"https://hosted.owntracks.org"]];
    [self dismissViewControllerAnimated:TRUE completion:^(void){
    }];
}


- (void) animateTextField: (UITextField*) textField up: (BOOL) up
{
    const int movementDistance = self.UItoken.frame.origin.y + self.UItoken.frame.size.height - self.view.frame.size.height / 2;
    const float movementDuration = 0.3f;
    
    int movement = (up ? -movementDistance : movementDistance);
    
    [UIView beginAnimations: @"anim" context: nil];
    [UIView setAnimationBeginsFromCurrentState: YES];
    [UIView setAnimationDuration: movementDuration];
    self.view.frame = CGRectOffset(self.view.frame, 0, movement);
    [UIView commitAnimations];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    [self animateTextField: textField up: YES];
}


- (void)textFieldDidEndEditing:(UITextField *)textField
{
    [self animateTextField: textField up: NO];
}
@end
