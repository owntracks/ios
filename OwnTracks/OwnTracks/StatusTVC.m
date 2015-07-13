//
//  StatusTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 11.09.13.
//  Copyright (c) 2013-2015 Christoph Krey. All rights reserved.
//

#import "StatusTVC.h"
#import "QosTVC.h"
#import "CertificatesTVC.h"
#import "TabBarController.h"
#import "OwnTracksAppDelegate.h"
#import "Settings.h"
#import "Friend+Create.h"
#import "CoreData.h"
#import "AlertView.h"
#import "OwnTracking.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

@interface StatusTVC ()
@property (weak, nonatomic) IBOutlet UISwitch *UImessaging;
@property (weak, nonatomic) IBOutlet UITextField *UIclientPKCS;
@property (weak, nonatomic) IBOutlet UISwitch *UIallowinvalidcerts;
@property (weak, nonatomic) IBOutlet UITextField *UIpassphrase;
@property (weak, nonatomic) IBOutlet UISwitch *UIvalidatecertificatechain;
@property (weak, nonatomic) IBOutlet UISwitch *UIvalidatedomainname;
@property (weak, nonatomic) IBOutlet UISegmentedControl *UIpolicymode;
@property (weak, nonatomic) IBOutlet UISwitch *UIusepolicy;
@property (weak, nonatomic) IBOutlet UITextField *UIserverCER;
@property (weak, nonatomic) IBOutlet UISegmentedControl *UImode;
@property (weak, nonatomic) IBOutlet UITextField *UIeffectivesubscriptions;
@property (weak, nonatomic) IBOutlet UITextView *UIparameters;
@property (weak, nonatomic) IBOutlet UITextField *UIstatus;
@property (weak, nonatomic) IBOutlet UITextView *UIstatusField;
@property (weak, nonatomic) IBOutlet UITextField *UIVersion;
@property (weak, nonatomic) IBOutlet UITextField *UIeffectiveTopic;
@property (weak, nonatomic) IBOutlet UITextField *UIeffectiveClientId;
@property (weak, nonatomic) IBOutlet UITextField *UIeffectiveWillTopic;
@property (weak, nonatomic) IBOutlet UITextField *UIeffectiveDeviceId;
@property (weak, nonatomic) IBOutlet UITextField *UIDeviceID;
@property (weak, nonatomic) IBOutlet UITextField *UILocatorDisplacement;
@property (weak, nonatomic) IBOutlet UITextField *UILocatorInterval;
@property (weak, nonatomic) IBOutlet UITextField *UIHost;
@property (weak, nonatomic) IBOutlet UITextField *UIUserID;
@property (weak, nonatomic) IBOutlet UITextField *UIPassword;
@property (weak, nonatomic) IBOutlet UITextField *UISubscription;
@property (weak, nonatomic) IBOutlet UISwitch *UIUpdateAddressBook;
@property (weak, nonatomic) IBOutlet UITextField *UIPositionsToKeep;
@property (weak, nonatomic) IBOutlet UITextField *UITopic;
@property (weak, nonatomic) IBOutlet UISwitch *UIRetain;
@property (weak, nonatomic) IBOutlet UISwitch *UICMD;
@property (weak, nonatomic) IBOutlet UITextField *UIClientID;
@property (weak, nonatomic) IBOutlet UITextField *UIPort;
@property (weak, nonatomic) IBOutlet UISwitch *UITLS;
@property (weak, nonatomic) IBOutlet UISwitch *UICleanSession;
@property (weak, nonatomic) IBOutlet UISwitch *UIAuth;
@property (weak, nonatomic) IBOutlet UITextField *UIKeepAlive;
@property (weak, nonatomic) IBOutlet UITextField *UIWillTopic;
@property (weak, nonatomic) IBOutlet UISwitch *UIWillRetain;
@property (weak, nonatomic) IBOutlet UITextField *UIqos;
@property (weak, nonatomic) IBOutlet UITextField *UIwillqos;
@property (weak, nonatomic) IBOutlet UITextField *UIsubscriptionqos;
@property (weak, nonatomic) IBOutlet UITextField *UItrackerid;
@property (weak, nonatomic) IBOutlet UISwitch *UIextendedData;
@property (weak, nonatomic) IBOutlet UISwitch *UIallowRemoteLocation;
@property (weak, nonatomic) IBOutlet UISwitch *UIrangeBeacons;
@property (weak, nonatomic) IBOutlet UIButton *UIexport;
@property (weak, nonatomic) IBOutlet UITextField *UIuser;
@property (weak, nonatomic) IBOutlet UITextField *UIdevice;
@property (weak, nonatomic) IBOutlet UITextField *UItoken;

@property (strong, nonatomic) UIDocumentInteractionController *dic;
@property (strong, nonatomic) UIAlertView *tidAlertView;
@property (strong, nonatomic) UIAlertView *modeAlertView;
@property (strong, nonatomic) QRCodeReaderViewController *reader;

@end

@implementation StatusTVC
static const DDLogLevel ddLogLevel = DDLogLevelError;

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    DDLogVerbose(@"ddLogLevel %lu", (unsigned long)ddLogLevel);
    
    self.UIHost.delegate = self;
    self.UIPort.delegate = self;
    self.UIUserID.delegate = self;
    self.UIPassword.delegate = self;
    self.UIClientID.delegate = self;
    self.UIKeepAlive.delegate = self;
    self.UItrackerid.delegate = self;
    self.UIDeviceID.delegate = self;
    self.UITopic.delegate = self;
    self.UIWillTopic.delegate = self;
    self.UISubscription.delegate = self;
    self.UILocatorDisplacement.delegate = self;
    self.UILocatorInterval.delegate = self;
    self.UIPositionsToKeep.delegate = self;
    self.UIuser.delegate = self;
    self.UIdevice.delegate = self;
    self.UItoken.delegate = self;
    self.UIpassphrase.delegate = self;
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate addObserver:self
               forKeyPath:@"connectionStateOut"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:nil];
    [delegate addObserver:self
               forKeyPath:@"connectionBufferedOut"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:nil];
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
                  forKeyPath:@"connectionStateOut"
                     context:nil];
    [delegate removeObserver:self
                  forKeyPath:@"connectionBufferedOut"
                     context:nil];
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
    if (self.UILocatorDisplacement) [Settings setString:self.UILocatorDisplacement.text forKey:@"mindist_preference"];
    if (self.UILocatorInterval) [Settings setString:self.UILocatorInterval.text forKey:@"mintime_preference"];
    if (self.UIHost) [Settings setString:self.UIHost.text forKey:@"host_preference"];
    if (self.UIUserID) [Settings setString:self.UIUserID.text forKey:@"user_preference"];
    if (self.UIPassword) [Settings setString:self.UIPassword.text forKey:@"pass_preference"];
    if (self.UISubscription) [Settings setString:self.UISubscription.text forKey:@"subscription_preference"];
    if (self.UIUpdateAddressBook) [Settings setBool:self.UIUpdateAddressBook.on forKey:@"ab_preference"];
    if (self.UIallowRemoteLocation) [Settings setBool:self.UIallowRemoteLocation.on forKey:@"allowremotelocation_preference"];
    if (self.UImode) [Settings setInt:(int)self.UImode.selectedSegmentIndex forKey:@"mode"];
    if (self.UIextendedData) [Settings setBool:self.UIextendedData.on forKey:@"extendeddata_preference"];
    if (self.UIrangeBeacons) [Settings setBool:self.UIrangeBeacons.on forKey:@"ranging_preference"];
    if (self.UImessaging) [Settings setBool:self.UImessaging.on forKey:SETTINGS_MESSAGING];
    if (self.UIPositionsToKeep) [Settings setString:self.UIPositionsToKeep.text forKey:@"positions_preference"];
    if (self.UITopic) [Settings setString:self.UITopic.text forKey:@"topic_preference"];
    if (self.UIRetain) [Settings setBool:self.UIRetain.on forKey:@"retain_preference"];
    if (self.UICMD) [Settings setBool:self.UICMD.on forKey:@"cmd_preference"];
    if (self.UIClientID) [Settings setString:self.UIClientID.text forKey:@"clientid_preference"];
    if (self.UIPort) [Settings setString:self.UIPort.text forKey:@"port_preference"];
    if (self.UITLS) [Settings setBool:self.UITLS.on forKey:@"tls_preference"];
    if (self.UIAuth) [Settings setBool:self.UIAuth.on forKey:@"auth_preference"];
    if (self.UICleanSession) [Settings setBool:self.UICleanSession.on forKey:@"clean_preference"];
    if (self.UIKeepAlive) [Settings setString:self.UIKeepAlive.text forKey:@"keepalive_preference"];
    if (self.UIWillTopic) [Settings setString:self.UIWillTopic.text forKey:@"willtopic_preference"];
    if (self.UIWillRetain) [Settings setBool:self.UIWillRetain.on forKey:@"willretain_preference"];
    if (self.UIuser) [Settings setString:self.UIuser.text forKey:@"user"];
    if (self.UIdevice) [Settings setString:self.UIdevice.text forKey:@"device"];
    if (self.UItoken) [Settings setString:self.UItoken.text forKey:@"token"];
    [CoreData saveContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self updatedStatus];
    if ([keyPath isEqualToString:@"configLoad"]) {
        [self updated];
    }
}

- (void)updatedStatus
{
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    
    const NSDictionary *states = @{
                                   @(state_starting): @"idle",
                                   @(state_connecting): @"connecting",
                                   @(state_error): @"error",
                                   @(state_connected): @"connected",
                                   @(state_closing): @"closing",
                                   @(state_closed): @"closed"
                                   };
    
    self.UIstatus.text = [NSString stringWithFormat:@"%@ %@ %@",
                          states[delegate.connectionStateOut],
                          delegate.connectionOut.lastErrorCode ?
                          delegate.connectionOut.lastErrorCode.localizedDescription : @"",
                          delegate.connectionOut.lastErrorCode ?
                          delegate.connectionOut.lastErrorCode.userInfo : @""
                          ];
    self.UIstatusField.text = [NSString stringWithFormat:@"%@ %@ %@",
                               states[delegate.connectionStateOut],
                               delegate.connectionOut.lastErrorCode ?
                               delegate.connectionOut.lastErrorCode.localizedDescription : @"",
                               delegate.connectionOut.lastErrorCode ?
                               delegate.connectionOut.lastErrorCode.userInfo : @""
                               ];
}

- (void)updated
{
    [self updatedStatus];    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    
    if (self.UIVersion) self.UIVersion.text = [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"];
    if (self.UIeffectiveDeviceId) self.UIeffectiveDeviceId.text = [Settings theDeviceId];
    if (self.UIeffectiveClientId) self.UIeffectiveClientId.text = [Settings theClientId];
    if (self.UIeffectiveTopic) self.UIeffectiveTopic.text = [Settings theGeneralTopic];
    if (self.UIeffectiveWillTopic) self.UIeffectiveWillTopic.text =  [Settings theWillTopic];
    if (self.UIeffectivesubscriptions) self.UIeffectivesubscriptions.text = [Settings theSubscriptions];
    
    if (self.UIparameters) self.UIparameters.text = [delegate.connectionOut parameters];
    
    if (self.UIDeviceID) self.UIDeviceID.text =  [Settings stringForKey:@"deviceid_preference"];
    if (self.UIclientPKCS) self.UIclientPKCS.text = [Settings stringForKey:@"clientpkcs"];
    if (self.UIserverCER) self.UIserverCER.text = [Settings stringForKey:@"servercer"];
    if (self.UIpassphrase) self.UIpassphrase.text = [Settings stringForKey:@"passphrase"];
    if (self.UIpolicymode) self.UIpolicymode.selectedSegmentIndex = [Settings intForKey:@"policymode"];
    if (self.UIusepolicy) self.UIusepolicy.on =  [Settings boolForKey:@"usepolicy"];
    if (self.UIallowinvalidcerts) self.UIallowinvalidcerts.on = [Settings boolForKey:@"allowinvalidcerts"];
    if (self.UIvalidatedomainname) self.UIvalidatedomainname.on =  [Settings boolForKey:@"validatedomainname"];
    if (self.UIvalidatecertificatechain) self.UIvalidatecertificatechain.on = [Settings boolForKey:@"validatecertificatechain"];
    if (self.UItrackerid) self.UItrackerid.text =  [Settings stringForKey:@"trackerid_preference"];
    if (self.UILocatorDisplacement) self.UILocatorDisplacement.text = [Settings stringForKey:@"mindist_preference"];
    if (self.UILocatorInterval) self.UILocatorInterval.text = [Settings stringForKey:@"mintime_preference"];
    if (self.UIHost) self.UIHost.text = [Settings stringForKey:@"host_preference"];
    if (self.UIUserID) self.UIUserID.text = [Settings stringForKey:@"user_preference"];
    if (self.UIPassword) self.UIPassword.text = [Settings stringForKey:@"pass_preference"];
    if (self.UISubscription) self.UISubscription.text = [Settings stringForKey:@"subscription_preference"];
    if (self.UImode) self.UImode.selectedSegmentIndex = [Settings intForKey:@"mode"];
    if (self.UIUpdateAddressBook) self.UIUpdateAddressBook.on = [Settings boolForKey:@"ab_preference"];
    if (self.UIallowRemoteLocation) self.UIallowRemoteLocation.on = [Settings boolForKey:@"allowremotelocation_preference"];
    if (self.UImessaging) self.UImessaging.on = [Settings boolForKey:SETTINGS_MESSAGING];
    if (self.UIPositionsToKeep) self.UIPositionsToKeep.text = [Settings stringForKey:@"positions_preference"];
    if (self.UIsubscriptionqos) self.UIsubscriptionqos.text = [self qosString:[Settings intForKey:@"subscriptionqos_preference"]];
    if (self.UITopic) self.UITopic.text = [Settings stringForKey:@"topic_preference"];
    if (self.UIqos) self.UIqos.text = [self qosString:[Settings intForKey:@"qos_preference"]];
    if (self.UIRetain) self.UIRetain.on = [Settings boolForKey:@"retain_preference"];
    if (self.UICMD) self.UICMD.on = [Settings boolForKey:@"cmd_preference"];
    if (self.UIClientID) self.UIClientID.text = [Settings stringForKey:@"clientid_preference"];
    if (self.UIPort) self.UIPort.text = [Settings stringForKey:@"port_preference"];
    if (self.UITLS) self.UITLS.on = [Settings boolForKey:@"tls_preference"];
    if (self.UIAuth)self.UIAuth.on = [Settings boolForKey:@"auth_preference"];
    if (self.UICleanSession) self.UICleanSession.on = [Settings boolForKey:@"clean_preference"];
    if (self.UIKeepAlive) self.UIKeepAlive.text = [Settings stringForKey:@"keepalive_preference"];
    if (self.UIWillTopic) self.UIWillTopic.text = [Settings stringForKey:@"willtopic_preference"];
    if (self.UIwillqos) self.UIwillqos.text =[self qosString:[Settings intForKey:@"willqos_preference"]];
    if (self.UIWillRetain) self.UIWillRetain.on = [Settings boolForKey:@"willretain_preference"];
    if (self.UIextendedData) self.UIextendedData.on = [Settings boolForKey:@"extendeddata_preference"];
    if (self.UIrangeBeacons) self.UIrangeBeacons.on = [Settings boolForKey:@"ranging_preference"];
    
    if (self.UIuser) self.UIuser.text = [Settings stringForKey:@"user"];
    if (self.UIdevice) self.UIdevice.text = [Settings stringForKey:@"device"];
    if (self.UItoken) self.UItoken.text = [Settings stringForKey:@"token"];

    NSMutableArray *hiddenFieldsMode12 = [[NSMutableArray alloc] init];
    NSMutableArray *hiddenIndexPathsMode12 = [[NSMutableArray alloc] init];
    
    if (self.UIparameters) {
        [hiddenFieldsMode12 addObject:self.UIparameters];
    }
    
    if (self.UIHost) {
        [hiddenFieldsMode12 addObject:self.UIHost];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:2 inSection:0]];
    }
    if (self.UIPort) {
        [hiddenFieldsMode12 addObject:self.UIPort];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:3 inSection:0]];
    }
    if (self.UITLS) {
        [hiddenFieldsMode12 addObject:self.UITLS];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:4 inSection:0]];
    }
    if (self.UIAuth) {
        [hiddenFieldsMode12 addObject:self.UIAuth];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:5 inSection:0]];
    }
    if (self.UIClientID) {
        [hiddenFieldsMode12 addObject:self.UIClientID];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:8 inSection:0]];
    }
    if (self.UICleanSession) {
        [hiddenFieldsMode12 addObject:self.UICleanSession];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:9 inSection:0]];
    }
    if (self.UIKeepAlive) {
        [hiddenFieldsMode12 addObject:self.UIKeepAlive];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:10 inSection:0]];
    }

    if (self.UISubscription) {
        [hiddenFieldsMode12 addObject:self.UISubscription];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:0 inSection:2]];
    }
    if (self.UIsubscriptionqos) {
        [hiddenFieldsMode12 addObject:self.UIsubscriptionqos];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:1 inSection:2]];
    }
    if (self.UICMD) {
        [hiddenFieldsMode12 addObject:self.UICMD];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:5 inSection:2]];
    }
    if (self.UIallowRemoteLocation) {
        [hiddenFieldsMode12 addObject:self.UIallowRemoteLocation];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:6 inSection:2]];
    }
    if (self.UIUpdateAddressBook) {
        [hiddenFieldsMode12 addObject:self.UIUpdateAddressBook];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:7 inSection:2]];
    }
    if (self.UIextendedData) {
        [hiddenFieldsMode12 addObject:self.UIextendedData];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:8 inSection:2]];
    }
    if (self.UIrangeBeacons) {
        [hiddenFieldsMode12 addObject:self.UIrangeBeacons];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:9 inSection:2]];
    }
    
    if (self.UILocatorInterval) {
        [hiddenFieldsMode12 addObject:self.UILocatorInterval];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:2 inSection:2]];
    }
    
    if (self.UILocatorDisplacement) {
        [hiddenFieldsMode12 addObject:self.UILocatorDisplacement];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:3 inSection:2]];
    }
    
    if (self.UIPositionsToKeep) {
        [hiddenFieldsMode12 addObject:self.UIPositionsToKeep];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:4 inSection:2]];
    }
    
    if (self.UITopic) {
        [hiddenFieldsMode12 addObject:self.UITopic];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:2 inSection:1]];
    }
    if (self.UIqos) {
        [hiddenFieldsMode12 addObject:self.UIqos];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:3 inSection:1]];
    }
    if (self.UIRetain) {
        [hiddenFieldsMode12 addObject:self.UIRetain];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:4 inSection:1]];
    }
    if (self.UIWillTopic) {
        [hiddenFieldsMode12 addObject:self.UIWillTopic];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:5 inSection:1]];
    }
    if (self.UIwillqos) {
        [hiddenFieldsMode12 addObject:self.UIwillqos];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:6 inSection:1]];
    }
    if (self.UIWillRetain) {
        [hiddenFieldsMode12 addObject:self.UIWillRetain];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:7 inSection:1]];
    }
    if (self.UIeffectiveDeviceId) {
        [hiddenFieldsMode12 addObject:self.UIeffectiveDeviceId];
    }
    if (self.UIeffectiveClientId) {
        [hiddenFieldsMode12 addObject:self.UIeffectiveClientId];
    }
    if (self.UIeffectiveTopic) {
        [hiddenFieldsMode12 addObject:self.UIeffectiveTopic];
    }
    if (self.UIeffectiveWillTopic) {
        [hiddenFieldsMode12 addObject:self.UIeffectiveWillTopic];
    }
    if (self.UIeffectivesubscriptions) {
        [hiddenFieldsMode12 addObject:self.UIeffectivesubscriptions];
    }
    if (self.UIDeviceID) {
        [hiddenFieldsMode12 addObject:self.UIDeviceID];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:1 inSection:1]];
    }
    if (self.UIUserID) {
        [hiddenFieldsMode12 addObject:self.UIUserID];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:6 inSection:0]];
    }
    if (self.UIPassword) {
        [hiddenFieldsMode12 addObject:self.UIPassword];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:7 inSection:0]];
    }
    
    NSMutableArray *hiddenFieldsMode02 = [[NSMutableArray alloc] init];
    NSMutableArray *hiddenIndexPathsMode02 = [[NSMutableArray alloc] init];
    if (self.UIuser) {
        [hiddenFieldsMode02 addObject:self.UIuser];
        [hiddenIndexPathsMode02 addObject:[NSIndexPath indexPathForRow:11 inSection:0]];
        [hiddenIndexPathsMode02 addObject:[NSIndexPath indexPathForRow:12 inSection:0]];
    }
    if (self.UIdevice) {
        [hiddenFieldsMode02 addObject:self.UIdevice];
        [hiddenIndexPathsMode02 addObject:[NSIndexPath indexPathForRow:13 inSection:0]];
    }
    if (self.UItoken) {
        [hiddenFieldsMode02 addObject:self.UItoken];
        [hiddenIndexPathsMode02 addObject:[NSIndexPath indexPathForRow:14 inSection:0]];
    }
    
    int mode = [Settings intForKey:@"mode"];
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
    
    if (self.UIexport) self.UIexport.enabled = (mode == 0 || mode == 1);
    
    if ([self.tabBarController isKindOfClass:[TabBarController class]]) {
        TabBarController *tbc = (TabBarController *)self.tabBarController;
        [tbc adjust];
    }
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

- (IBAction)documentationPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:
     [NSURL URLWithString:@"https://github.com/owntracks/owntracks/wiki"]];
}

- (IBAction)hostedPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:
     [NSURL URLWithString:@"https://hosted.owntracks.org"]];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.destinationViewController respondsToSelector:@selector(setEditQos:)] &&
        [segue.destinationViewController respondsToSelector:@selector(setEditIdentifier:)]) {
        if ([segue.identifier isEqualToString:@"setQos:"]) {
            [segue.destinationViewController performSelector:@selector(setEditQos:)
                                                  withObject:@([Settings intForKey:@"qos_preference"])];
            [segue.destinationViewController performSelector:@selector(setEditIdentifier:)
                                                  withObject:@"qos_preference"];
        }
        if ([segue.identifier isEqualToString:@"setWillQos:"]) {
            [segue.destinationViewController performSelector:@selector(setEditQos:)
                                                  withObject:@([Settings intForKey:@"willqos_preference"])];
            [segue.destinationViewController performSelector:@selector(setEditIdentifier:)
                                                  withObject:@"willqos_preference"];
        }
        if ([segue.identifier isEqualToString:@"setSubscriptionQos:"]) {
            [segue.destinationViewController performSelector:@selector(setEditQos:)
                                                  withObject:@([Settings intForKey:@"subscriptionqos_preference"])];
            [segue.destinationViewController performSelector:@selector(setEditIdentifier:)
                                                  withObject:@"subscriptionqos_preference"];
        }
    }
    if ([segue.destinationViewController respondsToSelector:@selector(setSelectedFileName:)] &&
        [segue.destinationViewController respondsToSelector:@selector(setFileNameIdentifier:)]) {
        if ([segue.identifier isEqualToString:@"setClientPKCS"]) {
            [segue.destinationViewController performSelector:@selector(setSelectedFileName:)
                                                  withObject:[Settings stringForKey:@"clientpkcs"]];
            [segue.destinationViewController performSelector:@selector(setFileNameIdentifier:)
                                                  withObject:@"clientpkcs"];
        }
        if ([segue.identifier isEqualToString:@"setServerCER"]) {
            [segue.destinationViewController performSelector:@selector(setSelectedFileName:)
                                                  withObject:[Settings stringForKey:@"servercer"]];
            [segue.destinationViewController performSelector:@selector(setFileNameIdentifier:)
                                                  withObject:@"servercer"];
        }
    }
}

- (IBAction)setQoS:(UIStoryboardSegue *)segue {
    if ([segue.sourceViewController respondsToSelector:@selector(editQos)] &&
        [segue.sourceViewController respondsToSelector:@selector(editIdentifier)]) {
        NSNumber *qos = [segue.sourceViewController performSelector:@selector(editQos)];
        NSString *identifier = [segue.sourceViewController performSelector:@selector(editIdentifier)];
        
        [Settings setInt:[qos intValue] forKey:identifier];
        [self updated];
    }
}

- (IBAction)setPath:(UIStoryboardSegue *)segue {
    if ([segue.sourceViewController respondsToSelector:@selector(selectedFileName)] &&
        [segue.sourceViewController respondsToSelector:@selector(fileNameIdentifier)]) {
        NSString *path = [segue.sourceViewController performSelector:@selector(selectedFileName)];
        NSString *identifier = [segue.sourceViewController performSelector:@selector(fileNameIdentifier)];
        
        [Settings setString:path forKey:identifier];
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
    [self.UIClientID resignFirstResponder];
    [self.UItrackerid resignFirstResponder];
    [self.UIKeepAlive resignFirstResponder];
    [self.UIDeviceID resignFirstResponder];
    [self.UITopic resignFirstResponder];
    [self.UIWillTopic resignFirstResponder];
    [self.UISubscription resignFirstResponder];
    [self.UILocatorDisplacement resignFirstResponder];
    [self.UILocatorInterval resignFirstResponder];
    [self.UIPositionsToKeep resignFirstResponder];
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
    } else {
        for (int i = 0; i < sender.text.length; i++) {
            if (![[NSCharacterSet alphanumericCharacterSet] characterIsMember:[sender.text characterAtIndex:i]]) {
                self.tidAlertView = [[UIAlertView alloc]
                                     initWithTitle:@"TrackerID invalid"
                                     message:@"TrackerID may contain alphanumeric characters only"
                                     delegate:self
                                     cancelButtonTitle:nil
                                     otherButtonTitles:@"OK", nil];
                [self.tidAlertView show];
                break;
            }
        }
        [Settings setString:sender.text forKey:@"trackerid_preference"];
    }
}

- (IBAction)modeChanged:(UISegmentedControl *)sender {
    self.modeAlertView = [[UIAlertView alloc] initWithTitle:@"Mode change"
                                                    message:@"Please be aware your stored waypoints and locations will be deleted on this device for privacy reasons. Please backup before."
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Continue", nil];
    [self.modeAlertView show];
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

- (IBAction)crash:(UIButton *)sender {
    [[Crashlytics sharedInstance] setObjectValue:@"Manual" forKey:@"CrashType"];
    [[Crashlytics sharedInstance] crash];
}

- (IBAction)messagingChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
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
        if ([delegate application:[UIApplication sharedApplication]
                      openURL:[NSURL URLWithString:result]
            sourceApplication:@"OwnTracks"
                        annotation:nil]) {
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
