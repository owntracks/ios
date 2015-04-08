//
//  StatusTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 11.09.13.
//  Copyright (c) 2013-2015 Christoph Krey. All rights reserved.
//

#import "StatusTVC.h"
#import "QosTVC.h"
#import "OwnTracksAppDelegate.h"
#import "Friend+Create.h"
#import "CoreData.h"

@interface StatusTVC ()
@property (weak, nonatomic) IBOutlet UISwitch *UIpublicMode;
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
@property (weak, nonatomic) IBOutlet UIButton *UIexport;

@property (strong, nonatomic) UIDocumentInteractionController *dic;

@end

@implementation StatusTVC

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate addObserver:self forKeyPath:@"connectionStateOut" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    [delegate addObserver:self forKeyPath:@"connectionBufferedOut" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    
    [self updated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate removeObserver:self forKeyPath:@"connectionStateOut" context:nil];
    [delegate removeObserver:self forKeyPath:@"connectionBufferedOut" context:nil];

    [self updateValues];
}

- (void)updateValues
{
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;

    if (self.UIDeviceID) [delegate.settings setString:self.UIDeviceID.text forKey:@"deviceid_preference"];
    if (self.UItrackerid) [delegate.settings setString:self.UItrackerid.text forKey:@"trackerid_preference"];
    if (self.UILocatorDisplacement) [delegate.settings setString:self.UILocatorDisplacement.text forKey:@"mindist_preference"];
    if (self.UILocatorInterval) [delegate.settings setString:self.UILocatorInterval.text forKey:@"mintime_preference"];
    if (self.UIHost) [delegate.settings setString:self.UIHost.text forKey:@"host_preference"];
    if (self.UIUserID) [delegate.settings setString:self.UIUserID.text forKey:@"user_preference"];
    if (self.UIPassword) [delegate.settings setString:self.UIPassword.text forKey:@"pass_preference"];
    if (self.UISubscription) [delegate.settings setString:self.UISubscription.text forKey:@"subscription_preference"];
    if (self.UIUpdateAddressBook) [delegate.settings setBool:self.UIUpdateAddressBook.on forKey:@"ab_preference"];
    if (self.UIallowRemoteLocation) [delegate.settings setBool:self.UIallowRemoteLocation.on forKey:@"allowremotelocation_preference"];
    if (self.UIpublicMode) [delegate.settings setBool:self.UIpublicMode.on forKey:@"publicMode"];
    if (self.UIextendedData) [delegate.settings setBool:self.UIextendedData.on forKey:@"extendeddata_preference"];
    if (self.UIPositionsToKeep) [delegate.settings setString:self.UIPositionsToKeep.text forKey:@"positions_preference"];
    if (self.UITopic) [delegate.settings setString:self.UITopic.text forKey:@"topic_preference"];
    if (self.UIRetain) [delegate.settings setBool:self.UIRetain.on forKey:@"retain_preference"];
    if (self.UICMD) [delegate.settings setBool:self.UICMD.on forKey:@"cmd_preference"];
    if (self.UIClientID) [delegate.settings setString:self.UIClientID.text forKey:@"clientid_preference"];
    if (self.UIPort) [delegate.settings setString:self.UIPort.text forKey:@"port_preference"];
    if (self.UITLS) [delegate.settings setBool:self.UITLS.on forKey:@"tls_preference"];
    if (self.UIAuth) [delegate.settings setBool:self.UIAuth.on forKey:@"auth_preference"];
    if (self.UICleanSession) [delegate.settings setBool:self.UICleanSession.on forKey:@"clean_preference"];
    if (self.UIKeepAlive) [delegate.settings setString:self.UIKeepAlive.text forKey:@"keepalive_preference"];
    if (self.UIWillTopic) [delegate.settings setString:self.UIWillTopic.text forKey:@"willtopic_preference"];
    if (self.UIWillRetain) [delegate.settings setBool:self.UIWillRetain.on forKey:@"willretain_preference"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self updatedStatus];
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
    
    self.UIstatus.text = [NSString stringWithFormat:@"%@ %@",
                          states[delegate.connectionStateOut],
                          delegate.connectionOut.lastErrorCode ? delegate.connectionOut.lastErrorCode.localizedDescription : @""];
    self.UIstatusField.text = [NSString stringWithFormat:@"%@ %@",
                               states[delegate.connectionStateOut],
                               delegate.connectionOut.lastErrorCode ? delegate.connectionOut.lastErrorCode.localizedDescription : @""];
}

- (void)updated
{
    [self updatedStatus];
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        
    self.UIVersion.text =                           [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"];
    self.UIeffectiveDeviceId.text =                 [delegate.settings theDeviceId];
    self.UIeffectiveClientId.text =                 [delegate.settings theClientId];
    self.UIeffectiveTopic.text =                    [delegate.settings theGeneralTopic];
    self.UIeffectiveWillTopic.text =                [delegate.settings theWillTopic];
    self.UIeffectivesubscriptions.text =            [delegate.settings theSubscriptions];
    
    self.UIparameters.text =                        [delegate.connectionOut parameters];
    
    self.UIDeviceID.text =                          [delegate.settings stringForKey:@"deviceid_preference"];
    self.UItrackerid.text =                         [delegate.settings stringForKey:@"trackerid_preference"];
    self.UILocatorDisplacement.text =               [delegate.settings stringForKey:@"mindist_preference"];
    self.UILocatorInterval.text =                   [delegate.settings stringForKey:@"mintime_preference"];
    self.UIHost.text =                              [delegate.settings stringForKey:@"host_preference"];
    self.UIUserID.text =                            [delegate.settings stringForKey:@"user_preference"];
    self.UIPassword.text =                          [delegate.settings stringForKey:@"pass_preference"];
    self.UISubscription.text =                      [delegate.settings stringForKey:@"subscription_preference"];
    self.UIpublicMode.on =                          [delegate.settings boolForKey:@"publicMode"];
    self.UIUpdateAddressBook.on =                   [delegate.settings boolForKey:@"ab_preference"];
    self.UIallowRemoteLocation.on =                 [delegate.settings boolForKey:@"allowremotelocation_preference"];
    self.UIextendedData.on =                        [delegate.settings boolForKey:@"extendeddata_preference"];
    self.UIPositionsToKeep.text =                   [delegate.settings stringForKey:@"positions_preference"];
    self.UIsubscriptionqos.text =                   [self qosString:[delegate.settings intForKey:@"subscriptionqos_preference"]];
    self.UITopic.text =                             [delegate.settings stringForKey:@"topic_preference"];
    self.UIqos.text =                               [self qosString:[delegate.settings intForKey:@"qos_preference"]];
    self.UIRetain.on =                              [delegate.settings boolForKey:@"retain_preference"];
    self.UICMD.on =                                 [delegate.settings boolForKey:@"cmd_preference"];
    self.UIClientID.text =                          [delegate.settings stringForKey:@"clientid_preference"];
    self.UIPort.text =                              [delegate.settings stringForKey:@"port_preference"];
    self.UITLS.on =                                 [delegate.settings boolForKey:@"tls_preference"];
    self.UIAuth.on =                                [delegate.settings boolForKey:@"auth_preference"];
    self.UICleanSession.on =                        [delegate.settings boolForKey:@"clean_preference"];
    self.UIKeepAlive.text =                         [delegate.settings stringForKey:@"keepalive_preference"];
    self.UIWillTopic.text =                         [delegate.settings stringForKey:@"willtopic_preference"];
    self.UIwillqos.text =                           [self qosString:[delegate.settings intForKey:@"willqos_preference"]];
    self.UIWillRetain.on =                          [delegate.settings boolForKey:@"willretain_preference"];
    
    NSMutableArray *hiddenFields = [[NSMutableArray alloc] init];
    if (self.UIDeviceID) [hiddenFields addObject:self.UIDeviceID];
    if (self.UIparameters) [hiddenFields addObject:self.UIparameters];
    if (self.UItrackerid) [hiddenFields addObject:self.UItrackerid];
    if (self.UIHost) [hiddenFields addObject:self.UIHost];
    if (self.UIUserID) [hiddenFields addObject:self.UIUserID];
    if (self.UIPassword) [hiddenFields addObject:self.UIPassword];
    if (self.UISubscription) [hiddenFields addObject:self.UISubscription];
    if (self.UIUpdateAddressBook) [hiddenFields addObject:self.UIUpdateAddressBook];
    if (self.UIallowRemoteLocation) [hiddenFields addObject:self.UIallowRemoteLocation];
    if (self.UIextendedData) [hiddenFields addObject:self.UIextendedData];
    if (self.UIsubscriptionqos) [hiddenFields addObject:self.UIsubscriptionqos];
    if (self.UITopic) [hiddenFields addObject:self.UITopic];
    if (self.UIqos) [hiddenFields addObject:self.UIqos];
    if (self.UIRetain) [hiddenFields addObject:self.UIRetain];
    if (self.UICMD) [hiddenFields addObject:self.UICMD];
    if (self.UIClientID) [hiddenFields addObject:self.UIClientID];
    if (self.UIPort) [hiddenFields addObject:self.UIPort];
    if (self.UITLS) [hiddenFields addObject:self.UITLS];
    if (self.UIAuth) [hiddenFields addObject:self.UIAuth];
    if (self.UICleanSession) [hiddenFields addObject:self.UICleanSession];
    if (self.UIKeepAlive) [hiddenFields addObject:self.UIKeepAlive];
    if (self.UIWillTopic) [hiddenFields addObject:self.UIWillTopic];
    if (self.UIwillqos) [hiddenFields addObject:self.UIwillqos];
    if (self.UIWillRetain) [hiddenFields addObject:self.UIWillRetain];
    if (self.UIeffectiveDeviceId) [hiddenFields addObject:self.UIeffectiveDeviceId];
    if (self.UIeffectiveClientId) [hiddenFields addObject:self.UIeffectiveClientId];
    if (self.UIeffectiveTopic) [hiddenFields addObject:self.UIeffectiveTopic];
    if (self.UIeffectiveWillTopic) [hiddenFields addObject:self.UIeffectiveWillTopic];
    if (self.UIeffectivesubscriptions) [hiddenFields addObject:self.UIeffectivesubscriptions];

    for (UIView *view in hiddenFields) {
        view.hidden = [delegate.settings boolForKey:@"publicMode"];
    }
    self.UIexport.enabled = ![delegate.settings boolForKey:@"publicMode"];
}

- (IBAction)exportPressed:(UIButton *)sender {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    NSError *error;
    
    NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                 inDomain:NSUserDomainMask
                                                        appropriateForURL:nil
                                                                   create:YES
                                                                    error:&error];
    NSString *fileName = [NSString stringWithFormat:@"config.otrc"];
    NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];
    
    [[NSFileManager defaultManager] createFileAtPath:[fileURL path]
                                            contents:[delegate.settings toData]
                                          attributes:nil];
    
    self.dic = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    self.dic.delegate = self;
    [self.dic presentOptionsMenuFromRect:sender.window.frame
                                  inView:self.tableView
                                animated:YES];
}

- (IBAction)documentationPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:
     [NSURL URLWithString:@"https://github.com/owntracks/owntracks/wiki"]];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;

    if ([segue.destinationViewController respondsToSelector:@selector(setEditQos:)] &&
        [segue.destinationViewController respondsToSelector:@selector(setEditIdentifier:)]) {
        if ([segue.identifier isEqualToString:@"setQos:"]) {
            [segue.destinationViewController performSelector:@selector(setEditQos:)
                                                  withObject:@([delegate.settings intForKey:@"qos_preference"])];
            [segue.destinationViewController performSelector:@selector(setEditIdentifier:)
                                                  withObject:@"qos_preference"];
        }
        if ([segue.identifier isEqualToString:@"setWillQos:"]) {
            [segue.destinationViewController performSelector:@selector(setEditQos:)
                                                  withObject:@([delegate.settings intForKey:@"willqos_preference"])];
            [segue.destinationViewController performSelector:@selector(setEditIdentifier:)
                                                  withObject:@"willqos_preference"];
        }
        if ([segue.identifier isEqualToString:@"setSubscriptionQos:"]) {
            [segue.destinationViewController performSelector:@selector(setEditQos:)
                                                  withObject:@([delegate.settings intForKey:@"subscriptionqos_preference"])];
            [segue.destinationViewController performSelector:@selector(setEditIdentifier:)
                                                  withObject:@"subscriptionqos_preference"];
        }
    }
}

- (IBAction)setQoS:(UIStoryboardSegue *)segue {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;

    if ([segue.sourceViewController respondsToSelector:@selector(editQos)] &&
        [segue.sourceViewController respondsToSelector:@selector(editIdentifier)]) {
        NSNumber *qos = [segue.sourceViewController performSelector:@selector(editQos)];
        NSString *identifier = [segue.sourceViewController performSelector:@selector(editIdentifier)];
        
        [delegate.settings setInt:[qos intValue] forKey:identifier];
        [self updated];
    }
}

- (NSString *)qosString:(int)qos
{
    switch (qos) {
        case 2:
            return @"exactly once";
        case 1:
            return @"at least once";
        case 0:
        default:
            return @"at most once";
    }
}
- (IBAction)touchedOutsideText:(UITapGestureRecognizer *)sender {
#ifdef DEBUG
    NSLog(@"touchedOutsideText");
#endif
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

- (IBAction)checkConnection:(UIButton *)sender {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    
    [delegate connectionOff];
    [self updateValues];
    [delegate reconnect];
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
                UIAlertView *alertView = [[UIAlertView alloc]
                                          initWithTitle:@"TrackerID invalid"
                                          message:@"TrackerID may contain alphanumeric characters only"
                                          delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:@"OK", nil];
                [alertView show];
                break;
            }
        }
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [delegate.settings setString:sender.text forKey:@"trackerid_preference"];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    self.UItrackerid.text = [delegate.settings stringForKey:@"trackerid_preference"];
}

- (IBAction)publicModeChanged:(UISwitch *)sender {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    if (self.UIpublicMode) [delegate.settings setBool:self.UIpublicMode.on forKey:@"publicMode"];

    [self updated];
    [delegate connectionOff];
    NSArray *friends = [Friend allFriendsInManagedObjectContext:[CoreData theManagedObjectContext]];
    for (Friend *friend in friends) {
        [[CoreData theManagedObjectContext] deleteObject:friend];        
    }
    [CoreData saveContext];
    
    [self updateValues];
    [delegate reconnect];

}

@end
