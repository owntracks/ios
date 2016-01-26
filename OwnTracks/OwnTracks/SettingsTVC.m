//
//  SettingsTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 11.09.13.
//  Copyright © 2013-2016 Christoph Krey. All rights reserved.
//

#import "SettingsTVC.h"
#import "CertificatesTVC.h"
#import "TabBarController.h"
#import "OwnTracksAppDelegate.h"
#import "Settings.h"
#import "Friend+Create.h"
#import "CoreData.h"
#import "AlertView.h"
#import "OwnTracking.h"
#import "Subscriptions.h"
#import "Messaging.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

#define BUY_OPTION 0 // modify to 1 if you want to enable auto renewing subscription buying

@interface SettingsTVC ()
@property (weak, nonatomic) IBOutlet UITableViewCell *UITLSCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *UIclientPKCSCell;
@property (weak, nonatomic) IBOutlet UITextField *UIclientPKCS;
@property (weak, nonatomic) IBOutlet UISwitch *UIallowinvalidcerts;
@property (weak, nonatomic) IBOutlet UITextField *UIpassphrase;
@property (weak, nonatomic) IBOutlet UISwitch *UIvalidatecertificatechain;
@property (weak, nonatomic) IBOutlet UISwitch *UIvalidatedomainname;
@property (weak, nonatomic) IBOutlet UISegmentedControl *UIpolicymode;
@property (weak, nonatomic) IBOutlet UISwitch *UIusepolicy;
@property (weak, nonatomic) IBOutlet UITableViewCell *UIserverCERCell;
@property (weak, nonatomic) IBOutlet UITextField *UIserverCER;
@property (weak, nonatomic) IBOutlet UISegmentedControl *UImode;
@property (weak, nonatomic) IBOutlet UITextField *UIDeviceID;
@property (weak, nonatomic) IBOutlet UITextField *UIHost;
@property (weak, nonatomic) IBOutlet UITextField *UIUserID;
@property (weak, nonatomic) IBOutlet UITextField *UIPassword;
@property (weak, nonatomic) IBOutlet UITextField *UIPort;
@property (weak, nonatomic) IBOutlet UISwitch *UITLS;
@property (weak, nonatomic) IBOutlet UISwitch *UIAuth;
@property (weak, nonatomic) IBOutlet UITextField *UItrackerid;
@property (weak, nonatomic) IBOutlet UIButton *UIexport;
@property (weak, nonatomic) IBOutlet UIButton *UIpublish;
@property (weak, nonatomic) IBOutlet UITextField *UIuser;
@property (weak, nonatomic) IBOutlet UITextField *UIdevice;
@property (weak, nonatomic) IBOutlet UITextField *UItoken;
@property (weak, nonatomic) IBOutlet UIButton *UIpremium;
@property (weak, nonatomic) IBOutlet UITextField *UIsecret;

@property (strong, nonatomic) UIDocumentInteractionController *dic;
@property (strong, nonatomic) UIAlertView *tidAlertView;
@property (strong, nonatomic) UIAlertView *modeAlertView;
@property (strong, nonatomic) QRCodeReaderViewController *reader;

@end

@implementation SettingsTVC
static const DDLogLevel ddLogLevel = DDLogLevelError;

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.UIHost.delegate = self;
    self.UIPort.delegate = self;
    self.UIUserID.delegate = self;
    self.UIPassword.delegate = self;
    self.UIsecret.delegate = self;
    self.UItrackerid.delegate = self;
    self.UIDeviceID.delegate = self;
    self.UIuser.delegate = self;
    self.UIdevice.delegate = self;
    self.UItoken.delegate = self;
    self.UIpassphrase.delegate = self;
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate addObserver:self
               forKeyPath:@"configLoad"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:nil];
    [self updated];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    if (textField == self.UIuser ||
        textField == self.UIdevice ||
        textField == self.UItoken) {
     [self reconnect];
    }
    return TRUE;
}

- (void)viewWillDisappear:(BOOL)animated
{    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate removeObserver:self
                  forKeyPath:@"configLoad"
                     context:nil];
    [self updateValues];
    [super viewWillDisappear:animated];
}

- (void)updateValues
{
    if (self.UIDeviceID) [Settings setString:self.UIDeviceID.text forKey:@"deviceid_preference"];
    if (self.UIclientPKCS) [Settings setString:self.UIclientPKCS.text forKey:@"clientpkcs"];
    if (self.UIserverCER) [Settings setString:self.UIserverCER.text forKey:@"servercer"];
    if (self.UIpassphrase) [Settings setString:self.UIpassphrase.text forKey:@"passphrase"];
    if (self.UIpolicymode) [Settings setInt:(int)self.UIpolicymode.selectedSegmentIndex forKey:@"policymode"];
    if (self.UIusepolicy) [Settings setBool:self.UIusepolicy.on forKey:@"usepolicy"];
    if (self.UIallowinvalidcerts) [Settings setBool:self.UIallowinvalidcerts.on forKey:@"allowinvalidcerts"];
    if (self.UIvalidatedomainname) [Settings setBool:self.UIvalidatedomainname.on forKey:@"validatedomainname"];
    if (self.UIvalidatecertificatechain) [Settings setBool:self.UIvalidatecertificatechain.on forKey:@"validatecertificatechain"];
    if (self.UItrackerid) [Settings setString:self.UItrackerid.text forKey:@"trackerid_preference"];
    if (self.UIHost) [Settings setString:self.UIHost.text forKey:@"host_preference"];
    if (self.UIUserID) [Settings setString:self.UIUserID.text forKey:@"user_preference"];
    if (self.UIPassword) [Settings setString:self.UIPassword.text forKey:@"pass_preference"];
    if (self.UIsecret) [Settings setString:self.UIsecret.text forKey:@"secret_preference"];
    if (self.UImode) [Settings setInt:(int)self.UImode.selectedSegmentIndex forKey:@"mode"];
    if (self.UIPort) [Settings setString:self.UIPort.text forKey:@"port_preference"];
    if (self.UITLS) [Settings setBool:self.UITLS.on forKey:@"tls_preference"];
    if (self.UIAuth) [Settings setBool:self.UIAuth.on forKey:@"auth_preference"];
    if (self.UIuser) [Settings setString:self.UIuser.text forKey:@"user"];
    if (self.UIdevice) [Settings setString:self.UIdevice.text forKey:@"device"];
    if (self.UItoken) [Settings setString:self.UItoken.text forKey:@"token"];
    
    if (self.UIpremium) {
        if (BUY_OPTION == 1) {
            self.UIpremium.enabled = true;
        } else {
            self.UIpremium.enabled = false;
        }
    }
    [CoreData saveContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    DDLogVerbose(@"observeValueForKeyPath %@", keyPath);

    if ([keyPath isEqualToString:@"configLoad"]) {
        [self performSelectorOnMainThread:@selector(updated) withObject:nil waitUntilDone:NO];
    }
}

- (void)updated
{
    BOOL locked = [Settings boolForKey:@"locked"];
    self.title = [NSString stringWithFormat:@"Settings%@", locked ? @" (locked)" : @""];
    
    if (self.UIDeviceID) {
        self.UIDeviceID.text =  [Settings stringForKey:@"deviceid_preference"];
        self.UIDeviceID.enabled = !locked;
    }
    
    if (self.UIclientPKCS) {
        self.UIclientPKCS.text = [Settings stringForKey:@"clientpkcs"];
        self.UIclientPKCS.enabled = !locked;
        self.UIclientPKCSCell.userInteractionEnabled = !locked;
        self.UIclientPKCSCell.accessoryType = !locked ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    }

    if (self.UIpassphrase) {
        if (self.UIclientPKCS) {
            self.UIpassphrase.enabled = !locked && (self.UIclientPKCS.text.length > 0);
            self.UIpassphrase.textColor = (self.UIclientPKCS.text.length > 0) ? [UIColor blackColor] : [UIColor lightGrayColor];
        }
        self.UIpassphrase.text = [Settings stringForKey:@"passphrase"];
    }

    if (self.UIusepolicy) {
        self.UIusepolicy.on =  [Settings boolForKey:@"usepolicy"];
        self.UIusepolicy.enabled = !locked;
    }
    
    if (self.UIpolicymode) {
        if (self.UIusepolicy) {
            self.UIpolicymode.enabled = !locked && self.UIusepolicy.on;
        }
        self.UIpolicymode.selectedSegmentIndex = [Settings intForKey:@"policymode"];
    }
    if (self.UIserverCER) {
        if (self.UIusepolicy && self.UIpolicymode) {
            self.UIserverCERCell.userInteractionEnabled = !locked && self.UIusepolicy.on && self.UIpolicymode.selectedSegmentIndex != 0;
            self.UIserverCERCell.accessoryType = (!locked && self.UIusepolicy.on && self.UIpolicymode.selectedSegmentIndex != 0) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
;
        }
        self.UIserverCER.text = [Settings stringForKey:@"servercer"];
    }
    if (self.UIallowinvalidcerts) {
        if (self.UIusepolicy) {
            self.UIallowinvalidcerts.enabled = !locked && self.UIusepolicy.on;
        }
        self.UIallowinvalidcerts.on = [Settings boolForKey:@"allowinvalidcerts"];
    }
    if (self.UIvalidatedomainname) {
        if (self.UIusepolicy) {
            self.UIvalidatedomainname.enabled = !locked && self.UIusepolicy.on;
        }
        self.UIvalidatedomainname.on =  [Settings boolForKey:@"validatedomainname"];
    }
    if (self.UIvalidatecertificatechain) {
        if (self.UIusepolicy) {
            self.UIvalidatecertificatechain.enabled = !locked && self.UIusepolicy.on;
        }
        self.UIvalidatecertificatechain.on = [Settings boolForKey:@"validatecertificatechain"];
    }
    
    if (self.UItrackerid) {
        self.UItrackerid.text = [Settings stringForKey:@"trackerid_preference"];
        self.UItrackerid.enabled = !locked;
    }
    if (self.UIHost) {
        self.UIHost.text = [Settings stringForKey:@"host_preference"];
        self.UIHost.enabled = !locked;
    }
    if (self.UIUserID) {
        self.UIUserID.text = [Settings stringForKey:@"user_preference"];
        self.UIUserID.enabled = !locked;
    }
    if (self.UIPassword) {
        self.UIPassword.text = [Settings stringForKey:@"pass_preference"];
        self.UIPassword.enabled = !locked;
    }
    if (self.UIsecret) {
        self.UIsecret.text = [Settings stringForKey:@"secret_preference"];
        self.UIsecret.enabled = !locked;
    }
    if (self.UImode) {
        self.UImode.selectedSegmentIndex = [Settings intForKey:@"mode"];
        self.UImode.enabled = !locked;
    }
    if (self.UIPort) {
        self.UIPort.text = [Settings stringForKey:@"port_preference"];
        self.UIPort.enabled = !locked;
    }
    if (self.UITLS) {
        self.UITLS.on = [Settings boolForKey:@"tls_preference"];
        self.UITLS.enabled = !locked;
    }
    if (self.UIAuth) {
        self.UIAuth.on = [Settings boolForKey:@"auth_preference"];
        self.UIAuth.enabled = !locked;
    }
    if (self.UIuser) {
        self.UIuser.text = [Settings stringForKey:@"user"];
        self.UIuser.enabled = !locked;
    }
    if (self.UIdevice) {
        self.UIdevice.text = [Settings stringForKey:@"device"];
        self.UIdevice.enabled = !locked;
    }
    if (self.UItoken) {
        self.UItoken.text = [Settings stringForKey:@"token"];
        self.UItoken.enabled = !locked;
    }
    int mode = [Settings intForKey:@"mode"];

    NSMutableArray *hiddenFieldsMode12 = [[NSMutableArray alloc] init];
    NSMutableArray *hiddenIndexPathsMode12 = [[NSMutableArray alloc] init];
    
    if (self.UIDeviceID) {
        [hiddenFieldsMode12 addObject:self.UIDeviceID];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:4 inSection:0]];
    }
    if (self.UIHost) {
        [hiddenFieldsMode12 addObject:self.UIHost];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:5 inSection:0]];
    }
    if (self.UIPort) {
        [hiddenFieldsMode12 addObject:self.UIPort];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:6 inSection:0]];
    }
    if (self.UITLS) {
        [hiddenFieldsMode12 addObject:self.UITLS];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:7 inSection:0]];
    }
    if (self.UIAuth) {
        [hiddenFieldsMode12 addObject:self.UIAuth];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:8 inSection:0]];

    }
    if (self.UIUserID) {
        if (self.UIAuth) {
            self.UIUserID.enabled = !locked && self.UIAuth.on;
            self.UIUserID.textColor = self.UIAuth.on ? [UIColor blackColor] : [UIColor lightGrayColor];
        }
        [hiddenFieldsMode12 addObject:self.UIUserID];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:9 inSection:0]];
    }
    if (self.UIPassword) {
        if (self.UIAuth) {
            self.UIPassword.enabled = !locked && self.UIAuth.on;
            self.UIPassword.textColor = self.UIAuth.on ? [UIColor blackColor] : [UIColor lightGrayColor];
        }
        [hiddenFieldsMode12 addObject:self.UIPassword];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:10 inSection:0]];
    }
    
    if (self.UIsecret) {
        [hiddenFieldsMode12 addObject:self.UIsecret];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:11 inSection:0]];
    }
    
    NSMutableArray *hiddenFieldsMode02 = [[NSMutableArray alloc] init];
    NSMutableArray *hiddenIndexPathsMode02 = [[NSMutableArray alloc] init];
    if (self.UIuser) {
        [hiddenFieldsMode02 addObject:self.UIuser];
        [hiddenIndexPathsMode02 addObject:[NSIndexPath indexPathForRow:12 inSection:0]];
        [hiddenIndexPathsMode02 addObject:[NSIndexPath indexPathForRow:13 inSection:0]];
    }
    if (self.UIdevice) {
        [hiddenFieldsMode02 addObject:self.UIdevice];
        [hiddenIndexPathsMode02 addObject:[NSIndexPath indexPathForRow:14 inSection:0]];
    }
    if (self.UItoken) {
        [hiddenFieldsMode02 addObject:self.UItoken];
        [hiddenIndexPathsMode02 addObject:[NSIndexPath indexPathForRow:15 inSection:0]];
    }
    
    // hide mode row if locked
    if (self.UImode) {
        NSIndexPath *modeIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        if ([self isRowVisible:modeIndexPath] && locked) {
            [self deleteRowsAtIndexPaths:@[modeIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        } else if (![self isRowVisible:modeIndexPath] && !locked) {
            [self insertRowsAtIndexPaths:@[modeIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
    
    // hide fields and rows depending on modes
    for (UIView *view in hiddenFieldsMode12) {
        [view setHidden:(mode == 1 || mode == 2)];
    }
    
    for (NSIndexPath *indexPath in hiddenIndexPathsMode12) {
        if ([self isRowVisible:indexPath] && (mode == 1 || mode == 2)) {
            [self deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        } else if (![self isRowVisible:indexPath] && !(mode == 1 || mode == 2)) {
            [self insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
    
    for (UIView *view in hiddenFieldsMode02) {
        [view setHidden:(mode == 0 || mode == 2)];
    }
    for (NSIndexPath *indexPath in hiddenIndexPathsMode02) {
        if ([self isRowVisible:indexPath] && (mode == 0 || mode == 2)) {
            [self deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        } else if (![self isRowVisible:indexPath] && !(mode == 0 || mode == 2)) {
            [self insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
    
    if (self.UIexport) self.UIexport.hidden = (mode == 2);
    if (self.UIpublish) self.UIpublish.hidden = (mode == 2);
    
    if (self.UITLS) {
        if (self.UITLSCell) {
            self.UITLSCell.accessoryType = self.UITLS.on ? UITableViewCellAccessoryDetailDisclosureButton : UITableViewCellAccessoryNone;
        }
    }

    if ([self.tabBarController isKindOfClass:[TabBarController class]]) {
        TabBarController *tbc = (TabBarController *)self.tabBarController;
        [tbc adjust];
    }
}

- (IBAction)publishSettingsPressed:(UIButton *)sender {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate dump];
}

- (IBAction)publishWaypointsPressed:(UIButton *)sender {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate waypoints];
}

- (IBAction)exportPressed:(UIButton *)sender {
    NSError *error;
    
    NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                 inDomain:NSUserDomainMask
                                                        appropriateForURL:nil
                                                                   create:YES
                                                                    error:&error];
    NSString *fileName = [NSString stringWithFormat:@"config.otrc"];
    NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];
    
    [[NSFileManager defaultManager] createFileAtPath:[fileURL path]
                                            contents:[Settings toData]
                                          attributes:nil];
    
    self.dic = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    self.dic.delegate = self;
    
    [self.dic presentOptionsMenuFromRect:self.UIexport.frame inView:self.UIexport animated:TRUE];
}

- (IBAction)exportWaypointsPressed:(UIButton *)sender {
    NSError *error;
    
    NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                 inDomain:NSUserDomainMask
                                                        appropriateForURL:nil
                                                                   create:YES
                                                                    error:&error];
    NSString *fileName = [NSString stringWithFormat:@"config.otrw"];
    NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];
    
    [[NSFileManager defaultManager] createFileAtPath:[fileURL path]
                                            contents:[Settings waypointsToData]
                                          attributes:nil];
    
    self.dic = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    self.dic.delegate = self;
    
    [self.dic presentOptionsMenuFromRect:self.UIexport.frame inView:self.UIexport animated:TRUE];
}

- (IBAction)hostedPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:
     [NSURL URLWithString:@"https://hosted.owntracks.org"]];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.destinationViewController respondsToSelector:@selector(setSelectedFileNames:)] &&
        [segue.destinationViewController respondsToSelector:@selector(setMultiple:)] &&
        [segue.destinationViewController respondsToSelector:@selector(setFileNameIdentifier:)]) {
        if ([segue.identifier isEqualToString:@"setClientPKCS"]) {
            [segue.destinationViewController performSelector:@selector(setSelectedFileNames:)
                                                  withObject:[Settings stringForKey:@"clientpkcs"]];
            [segue.destinationViewController performSelector:@selector(setFileNameIdentifier:)
                                                  withObject:@"clientpkcs"];
            [segue.destinationViewController performSelector:@selector(setMultiple:)
                                                  withObject:[NSNumber numberWithBool:FALSE]];
            
        }
        if ([segue.identifier isEqualToString:@"setServerCER"]) {
            [segue.destinationViewController performSelector:@selector(setSelectedFileNames:)
                                                  withObject:[Settings stringForKey:@"servercer"]];
            [segue.destinationViewController performSelector:@selector(setFileNameIdentifier:)
                                                  withObject:@"servercer"];
            [segue.destinationViewController performSelector:@selector(setMultiple:)
                                                  withObject:[NSNumber numberWithBool:TRUE]];
        }
    }
}

- (IBAction)setNames:(UIStoryboardSegue *)segue {
    if ([segue.sourceViewController respondsToSelector:@selector(selectedFileNames)] &&
        [segue.sourceViewController respondsToSelector:@selector(fileNameIdentifier)]) {
        NSString *names = [segue.sourceViewController performSelector:@selector(selectedFileNames)];
        NSString *identifier = [segue.sourceViewController performSelector:@selector(fileNameIdentifier)];
        
        [Settings setString:names forKey:identifier];
        [self updated];
    }
}

- (NSString *)qosString:(int)qos
{
    switch (qos) {
        case 2:
            return @"exactly once (2)";
        case 1:
            return @"at least once (1)";
        case 0:
        default:
            return @"at most once (0)";
    }
}

- (IBAction)touchedOutsideText:(UITapGestureRecognizer *)sender {
    [self.UIHost resignFirstResponder];
    [self.UIPort resignFirstResponder];
    [self.UIUserID resignFirstResponder];
    [self.UIPassword resignFirstResponder];
    [self.UIsecret resignFirstResponder];
    [self.UItrackerid resignFirstResponder];
    [self.UIDeviceID resignFirstResponder];
}

- (IBAction)tidChanged:(UITextField *)sender {
    
    if (sender.text.length > 2) {
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:@"TrackerID invalid"
                                  message:@"TrackerID may be empty or up to 2 characters long"
                                  delegate:self
                                  cancelButtonTitle:nil
                                  otherButtonTitles:@"OK", nil];
        [alertView show];
        sender.text = [Settings stringForKey:@"trackerid_preference"];
        return;
    }
    for (int i = 0; i < sender.text.length; i++) {
        if (![[NSCharacterSet alphanumericCharacterSet] characterIsMember:[sender.text characterAtIndex:i]]) {
            self.tidAlertView = [[UIAlertView alloc]
                                 initWithTitle:@"TrackerID invalid"
                                 message:@"TrackerID may contain alphanumeric characters only"
                                 delegate:self
                                 cancelButtonTitle:nil
                                 otherButtonTitles:@"OK", nil];
            [self.tidAlertView show];
            sender.text = [Settings stringForKey:@"trackerid_preference"];
            return;
        }
    }
    [Settings setString:sender.text forKey:@"trackerid_preference"];
}

- (IBAction)modeChanged:(UISegmentedControl *)sender {
    self.modeAlertView = [[UIAlertView alloc] initWithTitle:@"Mode change"
                                                    message:@"Please be aware your stored waypoints and locations will be deleted on this device for privacy reasons. Please backup before."
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Continue", nil];
    [self.modeAlertView show];
}

- (IBAction)authChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
}

- (IBAction)tlsChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)usePolicyChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)policyModeChanged:(UISegmentedControl *)sender {
    [self updateValues];
    [self updated];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;

    if (alertView == self.tidAlertView) {
        self.UItrackerid.text = [Settings stringForKey:@"trackerid_preference"];
    } else if (alertView == self.modeAlertView) {
        if (buttonIndex > 0) {
            if (self.UImode) [Settings setInt:(int)self.UImode.selectedSegmentIndex forKey:@"mode"];
            
            [self updated];
            [delegate terminateSession];
            [self updateValues];
            [delegate reconnect];
        } else {
            if (self.UImode) self.UImode.selectedSegmentIndex = [Settings intForKey:@"mode"];
        }
    }
}

- (IBAction)checkConnection:(UIButton *)sender {
    [self reconnect];
}

- (void)reconnect {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate connectionOff];
    [[OwnTracking sharedInstance] syncProcessing];
    [self updateValues];
    [delegate reconnect];
}

- (IBAction)scan:(UIBarButtonItem *)sender {
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
    [self dismissViewControllerAnimated:YES completion:^{
        DDLogVerbose(@"result %@", result);
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        if ([delegate application:[UIApplication sharedApplication] openURL:[NSURL URLWithString:result] options:@{}]) {
            [AlertView alert:@"QRScanner" message:@"Successfully processed!"];
        } else {
            [AlertView alert:@"QRScanner" message:delegate.processingMessage];
        }
        delegate.processingMessage = nil;
    }];
}

- (void)readerDidCancel:(QRCodeReaderViewController *)reader
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

@end
