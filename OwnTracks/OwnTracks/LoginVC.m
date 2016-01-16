//
//  LoginVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.07.15.
//  Copyright © 2015-2016 OwnTracks. All rights reserved.
//

#import "LoginVC.h"
#import "OwnTracksAppDelegate.h"
#import "Settings.h"
#import "AlertView.h"
#import "Hosted.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

#define WITH_REGISTRATION 0 // change to 1 if ad hoc registration allowed

@interface LoginVC ()
@property (weak, nonatomic) IBOutlet UITextField *UIfullname;
@property (weak, nonatomic) IBOutlet UITextField *UIemail;
@property (weak, nonatomic) IBOutlet UITextField *UIpassword;
@property (weak, nonatomic) IBOutlet UITextField *UIuser;
@property (weak, nonatomic) IBOutlet UITextField *UIdevice;
@property (weak, nonatomic) IBOutlet UITextField *UItoken;

@property (strong, nonatomic) UITextField *currentTextField;
@property (weak, nonatomic) IBOutlet UIScrollView *UIscrollView;
@property (weak, nonatomic) IBOutlet UIButton *UIregister;

@property (strong, nonatomic) QRCodeReaderViewController *reader;


@end

@implementation LoginVC
static const DDLogLevel ddLogLevel = DDLogLevelError;

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appEnteredBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidHide:)
                                                 name:UIKeyboardDidHideNotification
                                               object:nil];
    
}

- (void)keyboardDidShow:(NSNotification *)note {
    NSDictionary *userInfo = [note userInfo];
    CGSize kbSize = [[userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    DDLogVerbose(@"Keyboard Height: %f Width: %f", kbSize.height, kbSize.width);
    
    CGFloat offset =
        self.UIscrollView.frame.origin.y
        + self.currentTextField.frame.origin.y
        + self.currentTextField.frame.size.height
        - (self.view.frame.size.height - kbSize.height);
    if  (offset > 0) {
        CGPoint scrollPoint = CGPointMake(0, offset);
        [self.UIscrollView setContentOffset:scrollPoint animated:YES];
    }
}

- (void)keyboardDidHide:(NSNotification *)note {
    [self.UIscrollView setContentOffset:CGPointZero animated:YES];
}


- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskPortrait;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
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
    self.UIemail.delegate = self;
    self.UIpassword.delegate = self;
    self.UIfullname.delegate = self;
    
    if (self.UIregister) {
        if (WITH_REGISTRATION == 1) {
            self.UIregister.enabled = true;
        } else {
            self.UIregister.enabled = false;
        }
    }
    
    if ([Settings intForKey:@"mode"] != 2) {
        [self dismissViewControllerAnimated:TRUE completion:^(void){
        }];
    }
}

- (void)appEnteredBackground{
    [self.UIuser resignFirstResponder];
    [self.UIdevice resignFirstResponder];
    [self.UItoken resignFirstResponder];
    [self.UIemail resignFirstResponder];
    [self.UIpassword resignFirstResponder];
    [self.UIfullname resignFirstResponder];
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    self.currentTextField = textField;
    return TRUE;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return TRUE;
}

- (IBAction)continuePressed:(id)sender {
    [self dismissViewControllerAnimated:TRUE completion:^(void){
    }];
}

- (IBAction)loginPressed:(id)sender {
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

- (IBAction)registerPressed:(id)sender {
    if (WITH_REGISTRATION != 1) {
        [self websitePressed:sender];
        return;
    }

    Hosted *hosted = [[Hosted alloc] init];
    [hosted createUser:self.UIuser.text
              password:self.UIpassword.text
              fullname:self.UIfullname.text
                 email:self.UIemail.text
       completionBlock:^(NSInteger status, NSDictionary *user) {
           DDLogVerbose(@"createUser (%ld) %@", (long)status, user);
           if (status == 201 || status == 409) {
               [hosted authenticate:self.UIuser.text
                           password:self.UIpassword.text
                    completionBlock:^(NSInteger status, NSString *refreshToken) {
                        DDLogVerbose(@"refreshToken (%ld) %@", (long)status, refreshToken);
                        
                        if (refreshToken) {
                            [hosted accessToken:refreshToken
                                completionBlock:^(NSInteger status, NSString *accessToken) {
                                    DDLogVerbose(@"accessToken (%ld) %@", (long)status, accessToken);
                                    
                                    NSDictionary *me = [Hosted decode:accessToken];
                                    DDLogVerbose(@"de-LWTed %@", me);
                                    
                                    NSNumber *userId = [me valueForKey:@"userId"];
                                    if (userId) {
                                        [hosted createDevice:accessToken
                                                  devicename:self.UIdevice.text
                                                      userId:[userId integerValue]
                                             completionBlock:^(NSInteger status, NSDictionary *device) {
                                                 DDLogVerbose(@"createDevice(%ld) %@", (long)status, device);
                                                 if (device) {
                                                     NSString *loginAccessToken = [device valueForKey:@"accessToken"];
                                                     if (loginAccessToken) {
                                                         OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
                                                         [delegate terminateSession];

                                                         [Settings setInt:1 forKey:@"mode"];
                                                         [Settings setString:self.UIuser.text forKey:@"user"];
                                                         [Settings setString:self.UIdevice.text forKey:@"device"];
                                                         [Settings setString:loginAccessToken forKey:@"token"];
                                                         
                                                         [delegate reconnect];
                                                         
                                                         [self dismissViewControllerAnimated:TRUE completion:^(void){
                                                         }];
                                                     } else {
                                                         [AlertView alert:@"Registration"
                                                                  message:@"createDevice: no accessToken issued"];
                                                     }
                                                 } else {
                                                     [AlertView alert:@"Registration"
                                                              message:[NSString stringWithFormat:@"createDevice status %ld", (long)status]];
                                                 }
                                             }];
                                    } else {
                                        [AlertView alert:@"Registration"
                                                 message:[NSString stringWithFormat:@"accessToken status %ld", (long)status]];
                                    }
                                }];
                        } else {
                            [AlertView alert:@"Registration"
                                     message:[NSString stringWithFormat:@"refreshToken status %ld", (long)status]];
                        }
                    }];
           } else {
               [AlertView alert:@"Registration"
                        message:[NSString stringWithFormat:@"createUser status %ld", (long)status]];
           }
       }];
}

- (IBAction)websitePressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:
     [NSURL URLWithString:@"https://hosted.owntracks.org"]];
    [self dismissViewControllerAnimated:TRUE completion:^(void){
    }];
}

- (IBAction)cancelPressed:(UIButton *)sender {
    [self dismissViewControllerAnimated:TRUE completion:^(void){
    }];
}


- (IBAction)qrPressed:(id)sender {
    if ([QRCodeReader isAvailable]) {
        NSArray *types = @[AVMetadataObjectTypeQRCode];
        self.reader = [QRCodeReaderViewController readerWithMetadataObjectTypes:types];
        
        self.reader.modalPresentationStyle = UIModalPresentationFormSheet;
        
        self.reader.delegate = self;
        
        [self presentViewController:_reader animated:YES completion:NULL];
    } else {
        [AlertView alert:@"QRScanner" message:@"Does not have access to camera!"];
    }
}


#pragma mark - QRCodeReader Delegate Methods

- (void)reader:(QRCodeReaderViewController *)reader didScanResult:(NSString *)result
{
    DDLogVerbose(@"didScanResult %@", result);
    
    [reader dismissViewControllerAnimated:YES completion:^{
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        NSURL *url = [NSURL URLWithString:result];
        DDLogVerbose(@"url %@", url);
        NSDictionary *options = [[NSDictionary alloc] init];
        
        [delegate application:[UIApplication sharedApplication] openURL:url options:options];
        [AlertView alert:@"QRScanner" message:delegate.processingMessage];
        delegate.processingMessage = nil;
        if ([Settings intForKey:@"mode"] != 2) {
            [self dismissViewControllerAnimated:TRUE completion:^(void){
            }];
        }
    }];
}

- (void)readerDidCancel:(QRCodeReaderViewController *)reader {
    [self dismissViewControllerAnimated:YES completion:NULL];
}
@end
