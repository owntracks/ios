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
#import "AlertView.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface LoginVC ()
@property (weak, nonatomic) IBOutlet UITextField *UIuser;
@property (weak, nonatomic) IBOutlet UITextField *UIdevice;
@property (weak, nonatomic) IBOutlet UITextField *UItoken;
@property (weak, nonatomic) IBOutlet UIScrollView *UIscrollView;

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
    
    CGFloat offset = self.UIscrollView.frame.origin.y + self.UItoken.frame.origin.y + self.UItoken.frame.size.height - (self.view.frame.size.height - kbSize.height);
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
    [[UIApplication sharedApplication] openURL:
     [NSURL URLWithString:@"https://hosted.owntracks.org"]];
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
