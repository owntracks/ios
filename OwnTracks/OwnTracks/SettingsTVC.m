//
//  SettingsTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 11.09.13.
//  Copyright © 2013-2025  Christoph Krey. All rights reserved.
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
@property (weak, nonatomic) IBOutlet UITextField *UIhttpHeaders;
@property (weak, nonatomic) IBOutlet UITextField *UIOSMTemplate;
@property (weak, nonatomic) IBOutlet UITextField *UIOSMCopyright;
@property (weak, nonatomic) IBOutlet UISegmentedControl *UImodeSwitch;
@property (weak, nonatomic) IBOutlet UITextField *UIignoreStaleLocations;
@property (weak, nonatomic) IBOutlet UITextField *UIignoreInaccurateLocations;
@property (weak, nonatomic) IBOutlet UISwitch *UIranging;
@property (weak, nonatomic) IBOutlet UISwitch *UIlocked;
@property (weak, nonatomic) IBOutlet UISwitch *UIsub;
@property (weak, nonatomic) IBOutlet UISwitch *UIcmd;
@property (weak, nonatomic) IBOutlet UISwitch *UIpubRetain;
@property (weak, nonatomic) IBOutlet UISwitch *UIallowRemoteLocation;
@property (weak, nonatomic) IBOutlet UISwitch *UIcleanSession;
@property (weak, nonatomic) IBOutlet UITextField *UIsubTopic;
@property (weak, nonatomic) IBOutlet UITextField *UIpubTopicBase;
@property (weak, nonatomic) IBOutlet UITextField *UIlocatorDisplacement;
@property (weak, nonatomic) IBOutlet UITextField *UIlocatorInterval;
@property (weak, nonatomic) IBOutlet UITextField *UIpositions;
@property (weak, nonatomic) IBOutlet UITextField *UIdays;
@property (weak, nonatomic) IBOutlet UITextField *UImaxHistory;
@property (weak, nonatomic) IBOutlet UITextField *UIsubQos;
@property (weak, nonatomic) IBOutlet UITextField *UIkeepAlive;
@property (weak, nonatomic) IBOutlet UITextField *UIpubQos;
@property (weak, nonatomic) IBOutlet UITextField *UImonitoring;
@property (weak, nonatomic) IBOutlet UILabel *UIeffectivePubTopic;
@property (weak, nonatomic) IBOutlet UILabel *UIeffectiveSubTopic;
@property (weak, nonatomic) IBOutlet UILabel *UIeffectiveClientId;
@property (weak, nonatomic) IBOutlet UITextField *UIclientId;
@property (weak, nonatomic) IBOutlet UILabel *UIeffectiveTid;
@property (weak, nonatomic) IBOutlet UILabel *UIeffectiveDeviceId;
@property (weak, nonatomic) IBOutlet UITextField *UIdowngrade;
@property (weak, nonatomic) IBOutlet UITextField *UIadapt;
@property (weak, nonatomic) IBOutlet UIButton *createCardButton;
@property (weak, nonatomic) IBOutlet UIButton *toursButton;
@property (weak, nonatomic) IBOutlet UIButton *logsButton;

@property (strong, nonatomic) UIDocumentInteractionController *dic;
@property (nonatomic) BOOL warningShown;

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
    self.UIhttpHeaders.delegate = self;
    self.UIOSMTemplate.delegate = self;
    self.UIOSMCopyright.delegate = self;
    self.UIlocatorDisplacement.delegate = self;
    self.UIsubTopic.delegate = self;
    self.UIpubTopicBase.delegate = self;
    self.UIlocatorInterval.delegate = self;
    self.UIpositions.delegate = self;
    self.UIdays.delegate = self;
    self.UImaxHistory.delegate = self;
    self.UIsubQos.delegate = self;
    self.UIkeepAlive.delegate = self;
    self.UIpubQos.delegate = self;
    self.UImonitoring.delegate = self;
    self.UIclientId.delegate = self;
    self.UIdowngrade.delegate = self;
    self.UIadapt.delegate = self;

    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [ad addObserver:self
         forKeyPath:@"configLoad"
            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
            context:nil];
    
    LocationManager *lm = [LocationManager sharedInstance];
    [lm addObserver:self
         forKeyPath:@"monitoring"
            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
            context:nil];

    [self updated];
    
    self.warningShown = FALSE;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return TRUE;
}

- (void)viewWillDisappear:(BOOL)animated {
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [ad removeObserver:self
            forKeyPath:@"configLoad"
               context:nil];
    LocationManager *lm = [LocationManager sharedInstance];
    [lm removeObserver:self
            forKeyPath:@"monitoring"
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

    if (self.UIdays)
        [Settings setString:self.UIdays.text
                     forKey:@"days_preference"
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

    if (self.UIkeepAlive)
        [Settings setString:self.UIkeepAlive.text
                     forKey:@"keepalive_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];

    if (self.UImonitoring) {
        [LocationManager sharedInstance].monitoring = (self.UImonitoring.text).intValue;
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"adapted"];
        [Settings setString:self.UImonitoring.text
                     forKey:@"monitoring_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];
    }
    
    if (self.UIdowngrade) {
        [Settings setString:self.UIdowngrade.text
                     forKey:@"downgrade_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];
    }
    
    if (self.UIadapt)
        [Settings setString:self.UIadapt.text
                   forKey:@"adapt_preference"
                    inMOC:CoreData.sharedInstance.mainMOC];


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

    if (self.UIhttpHeaders)
        [Settings setString:self.UIhttpHeaders.text
                     forKey:@"httpheaders_preference"
                      inMOC:CoreData.sharedInstance.mainMOC];
    
    if (self.UIOSMTemplate)
        [Settings setOSMTemplate:self.UIOSMTemplate.text
                           inMOC:CoreData.sharedInstance.mainMOC];
    
    if (self.UIOSMCopyright)
        [Settings setOSMCopyright:self.UIOSMCopyright.text
                            inMOC:CoreData.sharedInstance.mainMOC];

    // important to save UImode last. Otherwise parameters not valid in the old mode may get persisted
    if (self.UImodeSwitch) {
        switch (self.UImodeSwitch.selectedSegmentIndex) {
            case 1:
                [Settings setInt:CONNECTION_MODE_HTTP
                          forKey:@"mode"
                           inMOC:CoreData.sharedInstance.mainMOC];
                DDLogVerbose(@"[Settings] mode set to %d", CONNECTION_MODE_HTTP);

                break;
            case 0:
            default:
                [Settings setInt:CONNECTION_MODE_MQTT
                          forKey:@"mode"
                           inMOC:CoreData.sharedInstance.mainMOC];
                DDLogVerbose(@"[Settings] mode set to %d", CONNECTION_MODE_MQTT);
                break;
        }
    }

    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    DDLogVerbose(@"observeValueForKeyPath %@", keyPath);

    if ([keyPath isEqualToString:@"configLoad"]) {
        [self performSelectorOnMainThread:@selector(updated) withObject:nil waitUntilDone:NO];
    }
    if ([keyPath isEqualToString:@"monitoring"]) {
        [self performSelectorOnMainThread:@selector(updated) withObject:nil waitUntilDone:NO];
    }
}

- (void)updated {
    BOOL locked = [Settings theLockedInMOC:CoreData.sharedInstance.mainMOC];
    self.title = [NSString stringWithFormat:@"%@%@",
                  NSLocalizedString(@"Settings",
                                    @"Settings screen title"),
                  locked ?
                  [NSString stringWithFormat:@" (%@)", NSLocalizedString(@"locked",
                                                                         @"indicates a locked configuration")] :
                  @""];

    self.createCardButton.enabled = !locked;
    self.toursButton.enabled = !locked;

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
                self.UImodeSwitch.selectedSegmentIndex = 1;
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

    if (self.UIpositions) {
        self.UIpositions.text =
        [Settings stringForKey:@"positions_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIpositions.enabled = !locked;
    }
    if (self.UIdays) {
        self.UIdays.text =
        [Settings stringForKey:@"days_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIdays.enabled = !locked;
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
    
    if (self.UIdowngrade) {
        self.UIdowngrade.text =
        [Settings stringForKey:@"downgrade_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIdowngrade.enabled = !locked;
    }
    
    if (self.UIadapt) {
        self.UIadapt.text =
        [Settings stringForKey:@"adapt_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIadapt.enabled = !locked;
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
        [Settings theLockedInMOC:CoreData.sharedInstance.mainMOC];
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

    if (self.UIhttpHeaders) {
        self.UIhttpHeaders.text =
        [Settings stringForKey:@"httpheaders_preference"
                         inMOC:CoreData.sharedInstance.mainMOC];
        self.UIhttpHeaders.enabled = !locked;
    }

    if (self.UIOSMTemplate) {
        self.UIOSMTemplate.text =
        [Settings theOSMTemplate:CoreData.sharedInstance.mainMOC];
        self.UIOSMTemplate.enabled = !locked;
    }

    if (self.UIOSMCopyright) {
        self.UIOSMCopyright.text =
        [Settings theOSMCopyrightInMOC:CoreData.sharedInstance.mainMOC];
        self.UIOSMCopyright.enabled = !locked;
    }

    if (self.UImodeSwitch) {

        int mode =
        [Settings intForKey:@"mode"
                      inMOC:CoreData.sharedInstance.mainMOC];

        // hide MQTT related rows if not MQTT mode
        NSArray <NSIndexPath *> *mqttPaths = @[
            [NSIndexPath indexPathForRow:6 inSection:0], // host
            [NSIndexPath indexPathForRow:7 inSection:0], // port / websockets
            [NSIndexPath indexPathForRow:8 inSection:0], // protocol / tls
            [NSIndexPath indexPathForRow:0 inSection:1], // subTopic
            [NSIndexPath indexPathForRow:1 inSection:1], // clientId
            [NSIndexPath indexPathForRow:9 inSection:1], // subQos
            [NSIndexPath indexPathForRow:10 inSection:1], // keepAlive
            [NSIndexPath indexPathForRow:11 inSection:1], // pubQos
            [NSIndexPath indexPathForRow:17 inSection:1], // sub
            [NSIndexPath indexPathForRow:19 inSection:1], // pubRetain
            [NSIndexPath indexPathForRow:20 inSection:1] // cleanSession
        ];

        for (NSIndexPath *indexPath in mqttPaths) {
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

        // hide HTTP related rows if not in HTTP mode
        NSArray <NSIndexPath *> *httpPaths = @[
            [NSIndexPath indexPathForRow:13 inSection:0], // url
            [NSIndexPath indexPathForRow:22 inSection:1] // httpHeaders
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
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [ad dump];
}

- (IBAction)publishWaypointsPressed:(UIButton *)sender {
    [self updateValues];
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [ad waypoints];
}

- (IBAction)exportPressed:(UIButton *)sender {
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
}

- (IBAction)exportWaypointsPressed:(UIButton *)sender {
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
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController respondsToSelector:@selector(setSelectedFileName:)]) {
        if ([segue.identifier isEqualToString:@"setClientPKCS"]) {
            [segue.destinationViewController performSelector:@selector(setSelectedFileName:)
                                                  withObject:[Settings stringForKey:@"clientpkcs"
                                                                              inMOC:CoreData.sharedInstance.mainMOC]];
        }
    }
}

- (IBAction)setNames:(UIStoryboardSegue *)segue {
    if ([segue.sourceViewController respondsToSelector:@selector(selectedFileName)]) {
        NSString *name = [segue.sourceViewController performSelector:@selector(selectedFileName)];

        [Settings setString:name forKey:@"clientpkcs"
                      inMOC:CoreData.sharedInstance.mainMOC];
        [self updated];
    }
}

- (IBAction)setCard:(UIStoryboardSegue *)segue {
    if ([segue.sourceViewController respondsToSelector:@selector(cardImage)] &&
        [segue.sourceViewController respondsToSelector:@selector(name)]) {
        UITextField *name = [segue.sourceViewController performSelector:@selector(name)];
        UIImageView *cardImage = [segue.sourceViewController performSelector:@selector(cardImage)];

    NSLog(@"image %f, %f, %f",
          cardImage.image.size.width,
          cardImage.image.size.height,
          cardImage.image.scale);
    
    NSData *png = UIImagePNGRepresentation(cardImage.image);
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    NSString *topic = [Settings theGeneralTopicInMOC:moc];
    Friend *myself = [Friend existsFriendWithTopic:topic
                            inManagedObjectContext:moc];
    
    
    myself.cardName = name.text;
    myself.cardImage = UIImagePNGRepresentation(cardImage.image);
    NSString *b64String = [png base64EncodedStringWithOptions:0];

    NSDictionary *json = @{
        @"_type": @"card",
        @"face": b64String,
        @"name": name.text,
    };

    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.connection sendData:[NSJSONSerialization dataWithJSONObject:json
                                                            options:NSJSONWritingSortedKeys
                                                              error:nil]
                        topic:[[Settings theGeneralTopicInMOC:moc] stringByAppendingString:@"/info"]
                   topicAlias:@(0)
                          qos:[Settings intForKey:@"qos_preference"
                                            inMOC:moc]
                       retain:YES];
        
        [NavigationController alert:
         NSLocalizedString(@"Card",
                           @"Header of an alert message regarding a card")
                            message:
         NSLocalizedString(@"set and sent to backend",
                           @"content of an alert message regarding card")];
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
    [self.UImonitoring resignFirstResponder];
    [self.UIdowngrade resignFirstResponder];
    [self.UIadapt resignFirstResponder];
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

- (void)changeWarning {
    if (!self.warningShown) {
        UIAlertController *ac = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"Connection change",
                                                                            @"Alert header for connection change warning")
                                 message:NSLocalizedString(@"Please be aware your stored waypoints and locations will be deleted on this device for privacy reasons. Please backup before.",
                                                           @"Alert content for connection change warning")
                                 preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *cancel = [UIAlertAction
                                 actionWithTitle:NSLocalizedString(@"Cancel",
                                                                   @"Cancel button title")
                                 
                                 style:UIAlertActionStyleCancel
                                 handler:^(UIAlertAction *action){
            [self updated];
            self.warningShown = FALSE;
        }];
        UIAlertAction *ok = [UIAlertAction
                             actionWithTitle:NSLocalizedString(@"Continue",
                                                               @"Continue button title")
                             
                             style:UIAlertActionStyleDestructive
                             handler:^(UIAlertAction *action) {
            OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
            [ad terminateSession];
            [self updateValues];
            [self updated];
            self.warningShown = TRUE;
        }];
        
        [ac addAction:cancel];
        [ac addAction:ok];
        [self presentViewController:ac animated:TRUE completion:nil];
    } else {
        OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [ad terminateSession];
        [self updateValues];
        [self updated];
    }
}

- (IBAction)modeSwitchChanged:(UISegmentedControl *)sender {
    [self changeWarning];
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
- (IBAction)deviceIdChanged:(UITextField *)sender {
    [self changeWarning];
}
- (IBAction)hostChanged:(UITextField *)sender {
    [self changeWarning];
}
- (IBAction)portChanged:(UITextField *)sender {
    [self changeWarning];
}
- (IBAction)wsChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)tlsChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)useridChanged:(UITextField *)sender {
    [self changeWarning];
}
- (IBAction)authChanged:(UISwitch *)sender {
    [self changeWarning];
}
- (IBAction)passwordChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)usePasswordChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)secretChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)urlChanged:(UITextField *)sender {
    [self changeWarning];
}
- (IBAction)subTopicChanged:(UITextField *)sender {
    [self changeWarning];
}
- (IBAction)clientIdChanged:(UITextField *)sender {
    [self changeWarning];
}
- (IBAction)pubTopicChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)willTopicChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)ignoreStaleLocationsChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)ignoreInaccurateLocationsChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)locatorDisplacementChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)locatorIntervalChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)positionsChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)daysChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)maxHistoryChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)subQosChanged:(UITextField *)sender {
    [self changeWarning];
}
- (IBAction)keepAliveChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)pubQosChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)willQosChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)monitoringChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)downgradeChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)adaptChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)rangingChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)extendedDataChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)lockedChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)subChanged:(UISwitch *)sender {
    [self changeWarning];
}
- (IBAction)cmdChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)pubRetainChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)willRetainChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)cleanSessionChanged:(UISwitch *)sender {
    [self changeWarning];
}
- (IBAction)allowRemoteLocationChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)httpHeadersChanged:(UITextField *)sender {
    [self changeWarning];
}
- (IBAction)osmTemplateChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)osmCopyrightChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)clientPKCSChanged:(UITextField *)sender {
    [self changeWarning];
}
- (IBAction)passphraseChanged:(UITextField *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)allowUntrustedCertificatesChanged:(UISwitch *)sender {
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
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [ad connectionOff];
    [ad syncProcessing];
    [self updateValues];
    [ad reconnect];
}

@end
