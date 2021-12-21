//
//  SettingsTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 11.09.13.
//  Copyright © 2013-2021  Christoph Krey. All rights reserved.
//

#import "SettingsTVC.h"
#import "CertificatesTVC.h"
#import "TabBarController.h"
#import "OwnTracksAppDelegate.h"
#import "Settings.h"
#import "Friend+CoreDataClass.h"
#import "CoreData.h"
#import "OwnTracking.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface SettingsTVC ()

@property (weak, nonatomic) IBOutlet UITableViewCell *UITLSCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *UIclientPKCSCell;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *UITLSTrash;
@property (weak, nonatomic) IBOutlet UITextField *UIclientPKCS;
@property (weak, nonatomic) IBOutlet UISwitch *UIallowUntrustedCertificates;
@property (weak, nonatomic) IBOutlet UITextField *UIpassphrase;
@property (weak, nonatomic) IBOutlet UITextField *UIDeviceID;
@property (weak, nonatomic) IBOutlet UITextField *UIHost;
@property (weak, nonatomic) IBOutlet UITextField *UIUserID;
@property (weak, nonatomic) IBOutlet UITextField *UIPassword;
@property (weak, nonatomic) IBOutlet UISwitch *UIUsePassword;
@property (weak, nonatomic) IBOutlet UITextField *UIPort;
@property (weak, nonatomic) IBOutlet UISwitch *UITLS;
@property (weak, nonatomic) IBOutlet UITextField *UIproto;
@property (weak, nonatomic) IBOutlet UISwitch *UIWS;
@property (weak, nonatomic) IBOutlet UISwitch *UIAuth;
@property (weak, nonatomic) IBOutlet UISwitch *UIextendedData;
@property (weak, nonatomic) IBOutlet UITextField *UItrackerid;
@property (weak, nonatomic) IBOutlet UIButton *UIexport;
@property (weak, nonatomic) IBOutlet UIButton *UIexportWaypoints;
@property (weak, nonatomic) IBOutlet UIButton *UIpublish;
@property (weak, nonatomic) IBOutlet UITextField *UIsecret;
@property (weak, nonatomic) IBOutlet UITextField *UIurl;
@property (weak, nonatomic) IBOutlet UISegmentedControl *UImodeSwitch;
@property (weak, nonatomic) IBOutlet UITextField *UIignoreStaleLocations;
@property (weak, nonatomic) IBOutlet UITextField *UIignoreInaccurateLocations;
@property (weak, nonatomic) IBOutlet UISwitch *UIranging;
@property (weak, nonatomic) IBOutlet UISwitch *UIlocked;
@property (weak, nonatomic) IBOutlet UISwitch *UIsub;
@property (weak, nonatomic) IBOutlet UISwitch *UIcmd;
@property (weak, nonatomic) IBOutlet UISwitch *UIpubRetain;
@property (weak, nonatomic) IBOutlet UISwitch *UIwillRetain;
@property (weak, nonatomic) IBOutlet UISwitch *UIallowRemoteLocation;
@property (weak, nonatomic) IBOutlet UISwitch *UIcleanSession;
@property (weak, nonatomic) IBOutlet UITextField *UIsubTopic;
@property (weak, nonatomic) IBOutlet UITextField *UIpubTopicBase;
@property (weak, nonatomic) IBOutlet UITextField *UIwillTopic;
@property (weak, nonatomic) IBOutlet UITextField *UIlocatorDisplacement;
@property (weak, nonatomic) IBOutlet UITextField *UIlocatorInterval;
@property (weak, nonatomic) IBOutlet UITextField *UIpositions;
@property (weak, nonatomic) IBOutlet UITextField *UImaxHistory;
@property (weak, nonatomic) IBOutlet UITextField *UIsubQos;
@property (weak, nonatomic) IBOutlet UITextField *UIkeepAlive;
@property (weak, nonatomic) IBOutlet UITextField *UIpubQos;
@property (weak, nonatomic) IBOutlet UITextField *UIwillQos;
@property (weak, nonatomic) IBOutlet UITextField *UImonitoring;
@property (weak, nonatomic) IBOutlet UILabel *UIeffectivePubTopic;
@property (weak, nonatomic) IBOutlet UILabel *UIeffectiveWillTopic;
@property (weak, nonatomic) IBOutlet UILabel *UIeffectiveSubTopic;
@property (weak, nonatomic) IBOutlet UILabel *UIeffectiveClientId;
@property (weak, nonatomic) IBOutlet UITextField *UIclientId;
@property (weak, nonatomic) IBOutlet UILabel *UIeffectiveTid;
@property (weak, nonatomic) IBOutlet UILabel *UIeffectiveDeviceId;

@property (strong, nonatomic) UIDocumentInteractionController *dic;

@end

@implementation SettingsTVC

static const DDLogLevel ddLogLevel = DDLogLevelInfo;

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.UIHost.delegate = self;
    self.UIPort.delegate = self;
    self.UIproto.delegate = self;
    self.UIignoreStaleLocations.delegate = self;
    self.UIignoreInaccurateLocations.delegate = self;
    self.UIUserID.delegate = self;
    self.UIPassword.delegate = self;
    self.UIsecret.delegate = self;
    self.UItrackerid.delegate = self;
    self.UIDeviceID.delegate = self;
    self.UIpassphrase.delegate = self;
    self.UIurl.delegate = self;

    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate addObserver:self
               forKeyPath:@"configLoad"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:nil];
    [self updated];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return TRUE;
}

- (void)viewWillDisappear:(BOOL)animated {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate removeObserver:self
                  forKeyPath:@"configLoad"
                     context:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"reload" object:nil];
    [self reconnect];
    [super viewWillDisappear:animated];
}

- (void)updateValues {
    if (self.UIDeviceID)
        [Settings setString:self.UIDeviceID.text
                     forKey:@"deviceid_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIclientPKCS)
        [Settings setString:self.UIclientPKCS.text
                     forKey:@"clientpkcs"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIpassphrase)
        [Settings setString:self.UIpassphrase.text
                     forKey:@"passphrase"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIallowUntrustedCertificates)
        [Settings setBool:self.UIallowUntrustedCertificates.on
                   forKey:@"allowinvalidcerts"
                    inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UItrackerid)
        [Settings setString:self.UItrackerid.text
                     forKey:@"trackerid_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIHost)
        [Settings setString:self.UIHost.text
                     forKey:@"host_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIwillTopic)
        [Settings setString:self.UIwillTopic.text
                     forKey:@"willtopic_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIclientId)
        [Settings setString:self.UIclientId.text
                     forKey:@"clientid_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIpubTopicBase)
        [Settings setString:self.UIpubTopicBase.text
                     forKey:@"topic_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIsubTopic)
        [Settings setString:self.UIsubTopic.text
                     forKey:@"subscription_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIUserID)
        [Settings setString:self.UIUserID.text
                     forKey:@"user_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIPassword)
        [Settings setString:self.UIPassword.text
                     forKey:@"pass_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIUsePassword)
        [Settings setBool:self.UIUsePassword.on
                   forKey:@"usepassword_preference"
                    inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIsecret)
        [Settings setString:self.UIsecret.text
                     forKey:@"secret_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIPort)
        [Settings setString:self.UIPort.text
                     forKey:@"port_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIignoreStaleLocations)
        [Settings setString:self.UIignoreStaleLocations.text
                     forKey:@"ignorestalelocations_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIlocatorDisplacement) {
        [Settings setString:self.UIlocatorDisplacement.text
                     forKey:@"mindist_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];
        [LocationManager sharedInstance].minDist =
        [Settings doubleForKey:@"mindist_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
    }
    if (self.UIlocatorInterval) {
        [Settings setString:self.UIlocatorInterval.text
                     forKey:@"mintime_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];
        [LocationManager sharedInstance].minTime =
        [Settings doubleForKey:@"mintime_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
    }

    if (self.UIpositions)
        [Settings setString:self.UIpositions.text
                     forKey:@"positions_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UImaxHistory)
        [Settings setString:self.UImaxHistory.text
                     forKey:@"maxhistory_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIsubQos)
        [Settings setString:self.UIsubQos.text
                     forKey:@"subscriptionqos_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIpubQos)
        [Settings setString:self.UIpubQos.text
                     forKey:@"qos_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIwillQos)
        [Settings setString:self.UIwillQos.text
                     forKey:@"willqos_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIkeepAlive)
        [Settings setString:self.UIkeepAlive.text
                     forKey:@"keepalive_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UImonitoring) {
        [LocationManager sharedInstance].monitoring = (self.UImonitoring.text).intValue;
        [Settings setString:self.UImonitoring.text
                     forKey:@"monitoring_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];
    }
    if (self.UIignoreInaccurateLocations)
        [Settings setString:self.UIignoreInaccurateLocations.text
                     forKey:@"ignoreinaccuratelocations_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UITLS)
        [Settings setBool:self.UITLS.on
                   forKey:@"tls_preference"
                    inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIWS)
        [Settings setBool:self.UIWS.on
                   forKey:@"ws_preference"
                    inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIAuth)
        [Settings setBool:self.UIAuth.on
                   forKey:@"auth_preference"
                    inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIranging)
        [Settings setBool:self.UIranging.on
                   forKey:@"ranging_preference"
                    inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIextendedData)
        [Settings setBool:self.UIextendedData.on
                   forKey:@"extendeddata_preference"
                    inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIlocked)
        [Settings setBool:self.UIlocked.on
                   forKey:@"locked"
                    inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIsub)
        [Settings setBool:self.UIsub.on
                   forKey:@"sub_preference"
                    inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIcmd)
        [Settings setBool:self.UIcmd.on
                   forKey:@"cmd_preference"
                    inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIpubRetain)
        [Settings setBool:self.UIpubRetain.on
                   forKey:@"retain_preference"
                    inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIwillRetain)
        [Settings setBool:self.UIwillRetain.on
                   forKey:@"willretain_preference"
                    inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIcleanSession)
        [Settings setBool:self.UIcleanSession.on
                   forKey:@"clean_preference"
                    inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIallowRemoteLocation)
        [Settings setBool:self.UIallowRemoteLocation.on
                   forKey:@"allowremotelocation_preference"
                    inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UIurl)
        [Settings setString:self.UIurl.text
                     forKey:@"url_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    // important to save UImode last. Otherwise parameters not valid in the old mode may get persisted
    if (self.UImodeSwitch) {
        switch (self.UImodeSwitch.selectedSegmentIndex) {
            case 1:
                [Settings setInt:CONNECTION_MODE_HTTP
                          forKey:@"mode"
                           inMOC:CoreData.sharedInstance.mainMOC];
                break;
            case 0:
            default:
                [Settings setInt:CONNECTION_MODE_MQTT
                          forKey:@"mode"
                           inMOC:CoreData.sharedInstance.mainMOC];
                break;
        }
    }

    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
    int mode = [Settings intForKey:@"mode"
                             inMOC:CoreData.sharedInstance.mainMOC];
    DDLogVerbose(@"[Settings] mode set to %d", mode);
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    DDLogVerbose(@"observeValueForKeyPath %@", keyPath);

    if ([keyPath isEqualToString:@"configLoad"]) {
        [self performSelectorOnMainThread:@selector(updated) withObject:nil waitUntilDone:NO];
    }
}

- (void)updated {
    BOOL locked = [Settings boolForKey:@"locked"
                                 inMOC:CoreData.sharedInstance.mainMOC];
    self.title = [NSString stringWithFormat:@"%@%@",
                  NSLocalizedString(@"Settings",
                                    @"Settings screen title"),
                  locked ?
                  [NSString stringWithFormat:@" (%@)", NSLocalizedString(@"locked",
                                                                         @"indicates a locked configuration")] :
                  @""];

    if (self.UIDeviceID) {
        self.UIDeviceID.text =
        [Settings stringForKey:@"deviceid_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIDeviceID.enabled = !locked;
    }
    if (self.UIeffectiveDeviceId) {
        self.UIeffectiveDeviceId.text =
        [Settings theDeviceIdInMOC:CoreData.sharedInstance.mainMOC];
    }

    if (self.UIclientPKCS) {
        self.UIclientPKCS.text =
        [Settings stringForKey:@"clientpkcs"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIclientPKCS.enabled = !locked;
        self.UIclientPKCSCell.userInteractionEnabled = !locked;
        self.UIclientPKCSCell.accessoryType = !locked ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    }

    if (self.UIpassphrase) {
        if (self.UIclientPKCS) {
            self.UIpassphrase.enabled = !locked && (self.UIclientPKCS.text.length > 0);
        }
        self.UIpassphrase.text =
        [Settings stringForKey:@"passphrase"
                         inMOC:CoreData.sharedInstance.mainMOC];
    }

    if (self.UIallowUntrustedCertificates) {
        self.UIallowUntrustedCertificates.enabled = !locked;
        self.UIallowUntrustedCertificates.on =
        [Settings boolForKey:@"allowinvalidcerts"
                       inMOC:CoreData.sharedInstance.mainMOC];
    }

    if (self.UItrackerid) {
        self.UItrackerid.text =
        [Settings stringForKey:@"trackerid_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UItrackerid.enabled = !locked;
    }
    if (self.UIeffectiveTid) {
        self.UIeffectiveTid.text =
        [Friend effectiveTid:[Settings stringForKey:@"trackerid_preference"
                                              inMOC:CoreData.sharedInstance.mainMOC]
                      device:[Settings theDeviceIdInMOC:CoreData.sharedInstance.mainMOC]];
    }

    if (self.UIHost) {
        self.UIHost.text =
        [Settings stringForKey:@"host_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIHost.enabled = !locked;
    }
    if (self.UIwillTopic) {
        self.UIwillTopic.text =
        [Settings stringForKey:@"willtopic_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIwillTopic.enabled = !locked;
    }
    if (self.UIeffectiveWillTopic) {
        self.UIeffectiveWillTopic.text =
        [Settings theWillTopicInMOC:CoreData.sharedInstance.mainMOC];
    }

    if (self.UIclientId) {
        self.UIclientId.text =
        [Settings stringForKey:@"clientid_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIclientId.enabled = !locked;
    }
    if (self.UIeffectiveClientId) {
        self.UIeffectiveClientId.text =
        [Settings theClientIdInMOC:CoreData.sharedInstance.mainMOC];
    }

    if (self.UIpubTopicBase) {
        self.UIpubTopicBase.text =
        [Settings stringForKey:@"topic_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIpubTopicBase.enabled = !locked;
    }
    if (self.UIeffectivePubTopic) {
        self.UIeffectivePubTopic.text =
        [Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC];
    }

    if (self.UIsubTopic) {
        self.UIsubTopic.text =
        [Settings stringForKey:@"subscription_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIsubTopic.enabled = !locked;
    }
    if (self.UIeffectiveSubTopic) {
        self.UIeffectiveSubTopic.text =
        [Settings theSubscriptionsInMOC:CoreData.sharedInstance.mainMOC];
    }

    if (self.UIUserID) {
        self.UIUserID.text =
        [Settings stringForKey:@"user_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIUserID.enabled = !locked;
    }
    if (self.UIPassword) {
        self.UIPassword.text =
        [Settings stringForKey:@"pass_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIPassword.enabled = !locked;
    }
    if (self.UIUsePassword) {
        self.UIUsePassword.on =
        [Settings boolForKey:@"usepassword_preference"
                       inMOC:CoreData.sharedInstance.mainMOC];
        self.UIUsePassword.enabled = !locked;
    }
    if (self.UIsecret) {
        self.UIsecret.text =
        [Settings stringForKey:@"secret_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIsecret.enabled = !locked;
    }
    if (self.UImodeSwitch) {
        int mode =
        [Settings intForKey:@"mode"
                      inMOC:CoreData.sharedInstance.mainMOC];
        DDLogVerbose(@"[Settings] mode is %d", mode);
        switch (mode) {
            case CONNECTION_MODE_HTTP:
                self.UImodeSwitch.selectedSegmentIndex =1;
                break;
            case CONNECTION_MODE_MQTT:
            default:
                self.UImodeSwitch.selectedSegmentIndex = 0;
                break;
        }
        self.UImodeSwitch.enabled = !locked;
    }
    if (self.UIPort) {
        self.UIPort.text =
        [Settings stringForKey:@"port_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIPort.enabled = !locked;
    }
    if (self.UIproto) {
        self.UIproto.text = [NSString stringWithFormat:@"%d",
                             [Settings intForKey:SETTINGS_PROTOCOL
                                           inMOC:CoreData.sharedInstance.mainMOC]];
        self.UIproto.enabled = !locked;
    }
    if (self.UIignoreStaleLocations) {
        self.UIignoreStaleLocations.text =
        [Settings stringForKey:@"ignorestalelocations_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIignoreStaleLocations.enabled = !locked;
    }
    if (self.UIkeepAlive) {
        self.UIkeepAlive.text =
        [Settings stringForKey:@"keepalive_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIkeepAlive.enabled = !locked;
    }
    if (self.UIpubQos) {
        self.UIpubQos.text =
        [Settings stringForKey:@"qos_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIpubQos.enabled = !locked;
    }
    if (self.UIsubQos) {
        self.UIsubQos.text =
        [Settings stringForKey:@"subscriptionqos_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIsubQos.enabled = !locked;
    }
    if (self.UIwillQos) {
        self.UIwillQos.text =
        [Settings stringForKey:@"willqos_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIwillQos.enabled = !locked;
    }
    if (self.UIpositions) {
        self.UIpositions.text =
        [Settings stringForKey:@"positions_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIpositions.enabled = !locked;
    }
    if (self.UImaxHistory) {
        self.UImaxHistory.text =
        [Settings stringForKey:@"maxhistory_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UImaxHistory.enabled = !locked;
    }
    if (self.UIlocatorInterval) {
        self.UIlocatorInterval.text =
        [Settings stringForKey:@"mintime_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIlocatorInterval.enabled = !locked;
    }
    if (self.UIlocatorDisplacement) {
        self.UIlocatorDisplacement.text =
        [Settings stringForKey:@"mindist_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIlocatorDisplacement.enabled = !locked;
    }
    if (self.UImonitoring) {
        self.UImonitoring.text =
        [Settings stringForKey:@"monitoring_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UImonitoring.enabled = !locked;
    }
    if (self.UIignoreInaccurateLocations) {
        self.UIignoreInaccurateLocations.text =
        [Settings stringForKey:@"ignoreinaccuratelocations_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIignoreInaccurateLocations.enabled = !locked;
    }
    if (self.UITLS) {
        self.UITLS.on =
        [Settings boolForKey:@"tls_preference"
                       inMOC:CoreData.sharedInstance.mainMOC];
        self.UITLS.enabled = !locked;
    }
    if (self.UIWS) {
        self.UIWS.on =
        [Settings boolForKey:@"ws_preference"
                       inMOC:CoreData.sharedInstance.mainMOC];
        self.UIWS.enabled = !locked;
    }
    if (self.UIAuth) {
        self.UIAuth.on =
        [Settings boolForKey:@"auth_preference"
                       inMOC:CoreData.sharedInstance.mainMOC];
        self.UIAuth.enabled = !locked;
    }
    if (self.UIranging) {
        self.UIranging.on =
        [Settings boolForKey:@"ranging_preference"
                       inMOC:CoreData.sharedInstance.mainMOC];
        self.UIranging.enabled = !locked;
    }
    if (self.UIextendedData) {
        self.UIextendedData.on =
        [Settings boolForKey:@"extendeddata_preference"
                       inMOC:CoreData.sharedInstance.mainMOC];
        self.UIextendedData.enabled = !locked;
    }
    if (self.self.UIlocked) {
        self.self.UIlocked.on =
        [Settings boolForKey:@"locked"
                       inMOC:CoreData.sharedInstance.mainMOC];
        self.self.UIlocked.enabled = false;
    }
    if (self.self.UIsub) {
        self.self.UIsub.on =
        [Settings boolForKey:@"sub_preference"
                       inMOC:CoreData.sharedInstance.mainMOC];
        self.self.UIsub.enabled = !locked;
    }
    if (self.UIcmd) {
        self.UIcmd.on =
        [Settings boolForKey:@"cmd_preference"
                       inMOC:CoreData.sharedInstance.mainMOC];
        self.UIcmd.enabled = !locked;
    }
    if (self.self.UIpubRetain) {
        self.self.UIpubRetain.on =
        [Settings boolForKey:@"retain_preference"
                       inMOC:CoreData.sharedInstance.mainMOC];
        self.self.UIpubRetain.enabled = !locked;
    }
    if (self.UIwillRetain) {
        self.UIwillRetain.on =
        [Settings boolForKey:@"willretain_preference"
                       inMOC:CoreData.sharedInstance.mainMOC];
        self.UIwillRetain.enabled = !locked;
    }
    if (self.UIcleanSession) {
        self.UIcleanSession.on =
        [Settings boolForKey:@"clean_preference"
                       inMOC:CoreData.sharedInstance.mainMOC];
        self.UIcleanSession.enabled = !locked;
    }
    if (self.UIallowRemoteLocation) {
        self.UIallowRemoteLocation.on =
        [Settings boolForKey:@"allowremotelocation_preference"
                       inMOC:CoreData.sharedInstance.mainMOC];
        self.UIallowRemoteLocation.enabled = !locked;
    }
    if (self.UIurl) {
        self.UIurl.text =
        [Settings stringForKey:@"url_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIurl.enabled = !locked;
    }

    //    if (!self.UIusepolicy) {
    if (self.UImodeSwitch) {

        int mode =
        [Settings intForKey:@"mode"
                      inMOC:CoreData.sharedInstance.mainMOC];

        NSArray <NSIndexPath *> *publishPaths = @[
            [NSIndexPath indexPathForRow:3 inSection:0]
        ];
        
        for (NSIndexPath *indexPath in publishPaths) {
            if ([self isRowVisible:indexPath] && (mode != CONNECTION_MODE_MQTT && mode != CONNECTION_MODE_HTTP)) {
                [self deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else if (![self isRowVisible:indexPath] && (mode == CONNECTION_MODE_MQTT || mode == CONNECTION_MODE_HTTP)) {
                [self insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }

        NSArray <NSIndexPath *> *privatePaths = @[
            [NSIndexPath indexPathForRow:5 inSection:0],
            [NSIndexPath indexPathForRow:6 inSection:0],
            [NSIndexPath indexPathForRow:7 inSection:0]
        ];

        for (NSIndexPath *indexPath in privatePaths) {
            if ([self isRowVisible:indexPath] && mode != CONNECTION_MODE_MQTT) {
                [self deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else if (![self isRowVisible:indexPath] && mode == CONNECTION_MODE_MQTT) {
                [self insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }

        if (self.UIUserID) {
            if (self.UIAuth) {
                self.UIUserID.enabled = !locked;
            }
        }
        if (self.UIUsePassword) {
            if (self.UIAuth) {
                self.UIUsePassword.enabled = !locked && self.UIAuth.on;
            }
        }
        if (self.UIPassword) {
            if (self.UIAuth) {
                self.UIPassword.enabled = !locked && self.UIAuth.on && self.UIUsePassword.on;
            }
        }

        NSArray <NSIndexPath *> *secretPaths = @[
            [NSIndexPath indexPathForRow:11 inSection:0]
        ];
        for (NSIndexPath *indexPath in secretPaths) {
            if ([self isRowVisible:indexPath] && (mode != CONNECTION_MODE_MQTT && mode != CONNECTION_MODE_HTTP)) {
                [self deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else if (![self isRowVisible:indexPath] && (mode == CONNECTION_MODE_MQTT || mode == CONNECTION_MODE_HTTP)) {
                [self insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }

        NSArray <NSIndexPath *> *authPaths = @[
            [NSIndexPath indexPathForRow:8 inSection:0],
            [NSIndexPath indexPathForRow:9 inSection:0],
            [NSIndexPath indexPathForRow:10 inSection:0]
        ];

        for (NSIndexPath *indexPath in authPaths) {
            if ([self isRowVisible:indexPath] && (mode != CONNECTION_MODE_MQTT && mode != CONNECTION_MODE_HTTP)) {
                [self deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else if (![self isRowVisible:indexPath] && (mode == CONNECTION_MODE_MQTT || mode == CONNECTION_MODE_HTTP)) {
                [self insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }

        NSArray <NSIndexPath *> *httpPaths = @[
            [NSIndexPath indexPathForRow:12 inSection:0]
        ];

        for (NSIndexPath *indexPath in httpPaths) {
            if ([self isRowVisible:indexPath] && mode != CONNECTION_MODE_HTTP) {
                [self deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else if (![self isRowVisible:indexPath] && mode == CONNECTION_MODE_HTTP) {
                [self insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }

        // hide mode row if locked
        if (self.UImodeSwitch) {
            NSIndexPath *modeIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
            if ([self isRowVisible:modeIndexPath] && locked) {
                [self deleteRowsAtIndexPaths:@[modeIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else if (![self isRowVisible:modeIndexPath] && !locked) {
                [self insertRowsAtIndexPaths:@[modeIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
    }

    if (self.UITLS) {
        if (self.UITLSCell) {
            self.UITLSCell.accessoryType = self.UITLS.on ? UITableViewCellAccessoryDetailDisclosureButton : UITableViewCellAccessoryNone;
        }
    }

    if (self.UITLSTrash) {
        self.UITLSTrash.enabled = !locked;
    }

    if ([self.tabBarController isKindOfClass:[TabBarController class]]) {
        TabBarController *tbc = (TabBarController *)self.tabBarController;
        [tbc adjust];
    }
}

- (IBAction)publishSettingsPressed:(UIButton *)sender {
    [self updateValues];
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate dump];
}

- (IBAction)publishWaypointsPressed:(UIButton *)sender {
    [self updateValues];
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate waypoints];
}

- (IBAction)exportPressed:(UIButton *)sender {
#if TARGET_OS_MACCATALYST
    UIAlertController *ac = [UIAlertController
                             alertControllerWithTitle:NSLocalizedString(@"Export", @"Export")
                             message:NSLocalizedString(@"Mac Catalyst does not support export yet",
                                                       @"content of an alert message regarging missing Mac Catalyst Export")
                             preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction
                         actionWithTitle:NSLocalizedString(@"Continue",
                                                           @"Continue button title")
                         
                         style:UIAlertActionStyleDefault
                         handler:nil];
    [ac addAction:ok];
    [self presentViewController:ac animated:TRUE completion:nil];
    return;
#else
    [self updateValues];
    NSError *error;

    NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                 inDomain:NSUserDomainMask
                                                        appropriateForURL:nil
                                                                   create:YES
                                                                    error:&error];
    NSString *fileName = [NSString stringWithFormat:@"config.otrc"];
    NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];

    [[NSFileManager defaultManager] createFileAtPath:fileURL.path
                                            contents:[Settings toDataInMOC:CoreData.sharedInstance.mainMOC]
                                          attributes:nil];

    self.dic = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    self.dic.delegate = self;

    [self.dic presentOptionsMenuFromRect:self.UIexport.frame inView:self.UIexport animated:TRUE];
#endif
}

- (IBAction)exportWaypointsPressed:(UIButton *)sender {
#if TARGET_OS_MACCATALYST
    UIAlertController *ac = [UIAlertController
                             alertControllerWithTitle:NSLocalizedString(@"Export", @"Export")
                             message:NSLocalizedString(@"Mac Catalyst does not support export yet",
                                                       @"content of an alert message regarging missing Mac Catalyst Export")
                             preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction
                         actionWithTitle:NSLocalizedString(@"Continue",
                                                           @"Continue button title")

                         style:UIAlertActionStyleDefault
                         handler:nil];
    [ac addAction:ok];
    [self presentViewController:ac animated:TRUE completion:nil];
    return;
#else
    [self updateValues];
    NSError *error;

    NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                 inDomain:NSUserDomainMask
                                                        appropriateForURL:nil
                                                                   create:YES
                                                                    error:&error];
    NSString *fileName = [NSString stringWithFormat:@"config.otrw"];
    NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];

    [[NSFileManager defaultManager] createFileAtPath:fileURL.path
                                            contents:[Settings waypointsToDataInMOC:CoreData.sharedInstance.mainMOC]
                                          attributes:nil];

    self.dic = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    self.dic.delegate = self;

    [self.dic presentOptionsMenuFromRect:self.UIexportWaypoints.frame inView:self.UIexportWaypoints animated:TRUE];
#endif
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController respondsToSelector:@selector(setSelectedFileNames:)] &&
        [segue.destinationViewController respondsToSelector:@selector(setMultiple:)] &&
        [segue.destinationViewController respondsToSelector:@selector(setFileNameIdentifier:)]) {
        if ([segue.identifier isEqualToString:@"setClientPKCS"]) {
            [segue.destinationViewController performSelector:@selector(setSelectedFileNames:)
                                                  withObject:[Settings stringForKey:@"clientpkcs"
                                                                              inMOC:CoreData.sharedInstance.mainMOC]];
            [segue.destinationViewController performSelector:@selector(setFileNameIdentifier:)
                                                  withObject:@"clientpkcs"];
            [segue.destinationViewController performSelector:@selector(setMultiple:)
                                                  withObject:[NSNumber numberWithBool:FALSE]];

        }
        if ([segue.identifier isEqualToString:@"setServerCER"]) {
            [segue.destinationViewController performSelector:@selector(setSelectedFileNames:)
                                                  withObject:[Settings stringForKey:@"servercer"
                                                                              inMOC:CoreData.sharedInstance.mainMOC]];
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

        [Settings setString:names forKey:identifier
                      inMOC:CoreData.sharedInstance.mainMOC];
        [self updated];
    }
}

- (IBAction)touchedOutsideText:(UITapGestureRecognizer *)sender {
    [self.UIHost resignFirstResponder];
    [self.UIPort resignFirstResponder];
    [self.UIproto resignFirstResponder];
    [self.UIignoreStaleLocations resignFirstResponder];
    [self.UIignoreInaccurateLocations resignFirstResponder];
    [self.UIUserID resignFirstResponder];
    [self.UIPassword resignFirstResponder];
    [self.UIsecret resignFirstResponder];
    [self.UItrackerid resignFirstResponder];
    [self.UIDeviceID resignFirstResponder];
    [self.UIclientId resignFirstResponder];
    [self.UIpubTopicBase resignFirstResponder];
    [self.UIsubTopic resignFirstResponder];
    [self.UIwillTopic resignFirstResponder];
    [self.UImonitoring resignFirstResponder];
    [self.UIwillQos resignFirstResponder];
    [self.UIpubQos resignFirstResponder];
    [self.UIsubQos resignFirstResponder];
    [self.UIkeepAlive resignFirstResponder];
    [self.UIlocatorDisplacement resignFirstResponder];
    [self.UIlocatorInterval resignFirstResponder];
    [self.UIpositions resignFirstResponder];
    [self.UImaxHistory resignFirstResponder];
}

- (IBAction)protocolChanged:(UITextField *)sender {
    if (sender.text.length) {
        int protocol = (sender.text).intValue;
        if (protocol != MQTTProtocolVersion31 &&
            protocol != MQTTProtocolVersion311 &&
            protocol != MQTTProtocolVersion50) {
            UIAlertController *ac = [UIAlertController
                                     alertControllerWithTitle:NSLocalizedString(@"Protocol invalid",
                                                                                @"Alert header regarding protocol input")
                                     message:NSLocalizedString(@"Protocol may be 3 for MQTT V3.1 or 4 for MQTT V3.1.1 or 5 for MQTT V5",
                                                               @"Alert content regarding protocol input")
                                     preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *ok = [UIAlertAction
                                 actionWithTitle:NSLocalizedString(@"Continue",
                                                                   @"Continue button title")
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction *action) {
                sender.text = [NSString stringWithFormat:@"%d",
                               [Settings intForKey:SETTINGS_PROTOCOL
                                             inMOC:CoreData.sharedInstance.mainMOC]];
            }];

            [ac addAction:ok];
            [self presentViewController:ac animated:TRUE completion:nil];
            return;

        }
        [Settings setInt:protocol forKey:SETTINGS_PROTOCOL inMOC:CoreData.sharedInstance.mainMOC];
        [self updated];
    }
}

- (IBAction)modeSwitchChanged:(UISegmentedControl *)sender {
    UIAlertController *ac = [UIAlertController
                             alertControllerWithTitle:NSLocalizedString(@"Mode change",
                                                                        @"Alert header for mode change warning")
                             message:NSLocalizedString(@"Please be aware your stored waypoints and locations will be deleted on this device for privacy reasons. Please backup before.",
                                                       @"Alert content for mode change warning")
                             preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancel = [UIAlertAction
                             actionWithTitle:NSLocalizedString(@"Cancel",
                                                               @"Cancel button title")
                             
                             style:UIAlertActionStyleCancel
                             handler:^(UIAlertAction *action){
        [self updated];
    }];
    UIAlertAction *ok = [UIAlertAction
                         actionWithTitle:NSLocalizedString(@"Continue",
                                                           @"Continue button title")
                         
                         style:UIAlertActionStyleDestructive
                         handler:^(UIAlertAction *action) {
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [delegate terminateSession];
        [self updateValues];
        [self updated];
        [delegate reconnect];
    }];
    
    [ac addAction:cancel];
    [ac addAction:ok];
    [self presentViewController:ac animated:TRUE completion:nil];
}


#define INVALIDTRACKERID NSLocalizedString(@"TrackerID invalid", @"Alert header regarding TrackerID input")

- (IBAction)tidChanged:(UITextField *)sender {

    if (sender.text.length > 2) {
        UIAlertController *ac = [UIAlertController
                                 alertControllerWithTitle:INVALIDTRACKERID
                                 message:NSLocalizedString(@"TrackerID may be empty or up to 2 characters long",
                                                           @"Alert content regarding TrackerID input")
                                 preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *ok = [UIAlertAction
                             actionWithTitle:NSLocalizedString(@"Continue",
                                                               @"Continue button title")
                             style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction *action) {
            sender.text = [Settings stringForKey:@"trackerid_preference"
                                           inMOC:CoreData.sharedInstance.mainMOC];
        }];

        [ac addAction:ok];
        [self presentViewController:ac animated:TRUE completion:nil];
        return;
    }
    for (int i = 0; i < sender.text.length; i++) {
        if (![[NSCharacterSet alphanumericCharacterSet] characterIsMember:[sender.text characterAtIndex:i]]) {
            UIAlertController *ac = [UIAlertController
                                     alertControllerWithTitle:INVALIDTRACKERID
                                     message:NSLocalizedString(@"TrackerID may contain alphanumeric characters only",
                                                               @"Alert content regarding TrackerID input")
                                     preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *ok = [UIAlertAction
                                 actionWithTitle:NSLocalizedString(@"Continue",
                                                                   @"Continue button title")
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction *action) {
                sender.text = [Settings stringForKey:@"trackerid_preference"
                                               inMOC:CoreData.sharedInstance.mainMOC];
            }];

            [ac addAction:ok];
            [self presentViewController:ac animated:TRUE completion:nil];
            return;
        }
    }
    [Settings setString:sender.text
                 forKey:@"trackerid_preference"
                  inMOC:CoreData.sharedInstance.mainMOC];
    [self updateValues];
    [self updated];
}

- (IBAction)modeChanged:(UITextField *)sender {
    UIAlertController *ac = [UIAlertController
                             alertControllerWithTitle:NSLocalizedString(@"Mode change",
                                                                        @"Alert header for mode change warning")
                             message:NSLocalizedString(@"Please be aware your stored waypoints and locations will be deleted on this device for privacy reasons. Please backup before.",
                                                       @"Alert content for mode change warning")
                             preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cancel = [UIAlertAction
                             actionWithTitle:NSLocalizedString(@"Cancel",
                                                               @"Cancel button title")

                             style:UIAlertActionStyleCancel
                             handler:^(UIAlertAction *action){
        [self updated];
    }];
    UIAlertAction *ok = [UIAlertAction
                         actionWithTitle:NSLocalizedString(@"Continue",
                                                           @"Continue button title")

                         style:UIAlertActionStyleDestructive
                         handler:^(UIAlertAction *action) {
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [delegate terminateSession];
        [self updateValues];

        [self updated];
        [delegate reconnect];
    }];

    [ac addAction:cancel];
    [ac addAction:ok];
    [self presentViewController:ac animated:TRUE completion:nil];
}

- (IBAction)changed:(id)sender {
    [self updateValues];
    [self updated];
}

- (IBAction)trashPressed:(UIBarButtonItem *)sender {
    if (self.UIclientPKCS) {
        self.UIclientPKCS.text = @"";
    }

    if (self.UIpassphrase) {
        self.UIpassphrase.text = @"";
    }
    [self updateValues];
}

- (void)reconnect {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate connectionOff];
    [[OwnTracking sharedInstance] syncProcessing];
    [self updateValues];
    [delegate reconnect];
}

@end
