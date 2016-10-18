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
#import "Friend.h"
#import "CoreData.h"
#import "AlertView.h"
#import "OwnTracking.h"
#import "IdPicker.h"
#import "WebVC.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

#define QRSCANNER NSLocalizedString(@"QRScanner", @"Header of an alert message regarging QR code scanning")

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
@property (weak, nonatomic) IBOutlet UITextField *UIDeviceID;
@property (weak, nonatomic) IBOutlet UITextField *UIHost;
@property (weak, nonatomic) IBOutlet UITextField *UIUserID;
@property (weak, nonatomic) IBOutlet UITextField *UIPassword;
@property (weak, nonatomic) IBOutlet UITextField *UIPort;
@property (weak, nonatomic) IBOutlet UISwitch *UITLS;
@property (weak, nonatomic) IBOutlet UISwitch *UIWS;
@property (weak, nonatomic) IBOutlet UISwitch *UIAuth;
@property (weak, nonatomic) IBOutlet UITextField *UItrackerid;
@property (weak, nonatomic) IBOutlet UIButton *UIexport;
@property (weak, nonatomic) IBOutlet UIButton *UIpublish;
@property (weak, nonatomic) IBOutlet UITextField *UIsecret;
@property (weak, nonatomic) IBOutlet UITextField *UIurl;
@property (weak, nonatomic) IBOutlet IdPicker *UImode;
@property (weak, nonatomic) IBOutlet UITextField *UIquickstartId;
@property (weak, nonatomic) IBOutlet UITextField *UIwatsonDeviceId;
@property (weak, nonatomic) IBOutlet UITextField *UIwatsonAuthToken;
@property (weak, nonatomic) IBOutlet UITextField *UIwatsonDeviceType;
@property (weak, nonatomic) IBOutlet UITextField *UIwatsonOrganization;
@property (weak, nonatomic) IBOutlet UITextField *UIignoreStaleLocations;
@property (weak, nonatomic) IBOutlet UITextField *UIignoreInaccurateLocations;
@property (weak, nonatomic) IBOutlet UISwitch *UIranging;

@property (strong, nonatomic) UIDocumentInteractionController *dic;
@property (strong, nonatomic) UIAlertView *tidAlertView;
@property (strong, nonatomic) QRCodeReaderViewController *reader;

@end

@implementation SettingsTVC

static const DDLogLevel ddLogLevel = DDLogLevelError;

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.UImode.delegate = self;
    self.UIHost.delegate = self;
    self.UIPort.delegate = self;
    self.UIignoreStaleLocations.delegate = self;
    self.UIignoreInaccurateLocations.delegate = self;
    self.UIUserID.delegate = self;
    self.UIPassword.delegate = self;
    self.UIsecret.delegate = self;
    self.UItrackerid.delegate = self;
    self.UIDeviceID.delegate = self;
    self.UIpassphrase.delegate = self;
    self.UIurl.delegate = self;
    self.UIquickstartId.delegate = self;
    self.UIwatsonOrganization.delegate = self;
    self.UIwatsonDeviceType.delegate = self;
    self.UIwatsonDeviceId.delegate = self;
    self.UIwatsonAuthToken.delegate = self;

    self.UImode.array = @[@{@"identifier":@0, @"name": @"Private"},
                          @{@"identifier":@2, @"name": @"Public"},
                          @{@"identifier":@3, @"name": @"HTTP"},
                          @{@"identifier":@4, @"name": @"Watson quickstart", @"hidden":@(!self.privileged)},
                          @{@"identifier":@5, @"name": @"Watson registered", @"hidden":@(!self.privileged)}
                          ];

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
    if (self.UImode) {
        switch ([self.UImode arrayId]) {
            case 5:
                [Settings setInt:CONNECTION_MODE_WATSONREGISTERED forKey:@"mode"];
                break;
            case 4:
                [Settings setInt:CONNECTION_MODE_WATSON forKey:@"mode"];
                break;
            case 3:
                [Settings setInt:CONNECTION_MODE_HTTP forKey:@"mode"];
                break;
            case 2:
                [Settings setInt:CONNECTION_MODE_PUBLIC forKey:@"mode"];
                break;
            case 0:
            default:
                [Settings setInt:CONNECTION_MODE_PRIVATE forKey:@"mode"];
                break;
        }
    }
    if (self.UIPort) [Settings setString:self.UIPort.text forKey:@"port_preference"];
    if (self.UIignoreStaleLocations) [Settings setString:self.UIignoreStaleLocations.text forKey:@"ignorestalelocations_preference"];
    if (self.UIignoreInaccurateLocations) [Settings setString:self.UIignoreInaccurateLocations.text forKey:@"ignoreinaccuratelocations_preference"];
    if (self.UITLS) [Settings setBool:self.UITLS.on forKey:@"tls_preference"];
    if (self.UIWS) [Settings setBool:self.UIWS.on forKey:@"ws_preference"];
    if (self.UIAuth) [Settings setBool:self.UIAuth.on forKey:@"auth_preference"];
    if (self.UIranging) [Settings setBool:self.UIranging.on forKey:@"ranging_preference"];
    if (self.UIurl) [Settings setString:self.UIurl.text forKey:@"url_preference"];
    if (self.UIquickstartId) [Settings setString:self.UIquickstartId.text forKey:@"quickstartid_preference"];
    if (self.UIwatsonOrganization) [Settings setString:self.UIwatsonOrganization.text forKey:@"watsonorganization_preference"];
    if (self.UIwatsonDeviceType) [Settings setString:self.UIwatsonDeviceType.text forKey:@"watsondevicetype_preference"];
    if (self.UIwatsonDeviceId) [Settings setString:self.UIwatsonDeviceId.text forKey:@"watsondeviceid_preference"];
    if (self.UIwatsonAuthToken) [Settings setString:self.UIwatsonAuthToken.text forKey:@"watsonauthtoken_preference"];

    [CoreData saveContext];
    int mode = [Settings intForKey:@"mode"];
    DDLogVerbose(@"[Settings] mode set to %d", mode);
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
    self.title = [NSString stringWithFormat:@"%@%@",
                  NSLocalizedString(@"Settings",
                                    @"Settings screen title"),
                  locked ?
                  [NSString stringWithFormat:@" (%@)", NSLocalizedString(@"locked",
                                                                         @"indicates a locked configuration")] :
                  @""];

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
        int mode = [Settings intForKey:@"mode"];
        DDLogVerbose(@"[Settings] mode is %d", mode);
        self.UImode.arrayId = [Settings intForKey:@"mode"];
        self.UImode.enabled = !locked;
    }
    if (self.UIPort) {
        self.UIPort.text = [Settings stringForKey:@"port_preference"];
        self.UIPort.enabled = !locked;
    }
    if (self.UIignoreStaleLocations) {
        self.UIignoreStaleLocations.text = [Settings stringForKey:@"ignorestalelocations_preference"];
        self.UIignoreStaleLocations.enabled = !locked;
    }
    if (self.UIignoreInaccurateLocations) {
        self.UIignoreInaccurateLocations.text = [Settings stringForKey:@"ignoreinaccuratelocations_preference"];
        self.UIignoreInaccurateLocations.enabled = !locked;
    }
    if (self.UITLS) {
        self.UITLS.on = [Settings boolForKey:@"tls_preference"];
        self.UITLS.enabled = !locked;
    }
    if (self.UIWS) {
        self.UIWS.on = [Settings boolForKey:@"ws_preference"];
        self.UIWS.enabled = !locked;
    }
    if (self.UIAuth) {
        self.UIAuth.on = [Settings boolForKey:@"auth_preference"];
        self.UIAuth.enabled = !locked;
    }
    if (self.UIranging) {
        self.UIranging.on = [Settings boolForKey:@"ranging_preference"];
        self.UIranging.enabled = !locked;
    }
    if (self.UIurl) {
        self.UIurl.text = [Settings stringForKey:@"url_preference"];
        self.UIurl.enabled = !locked;
    }
    if (self.UIquickstartId) {
        self.UIquickstartId.text = [Settings stringForKey:@"quickstartid_preference"];
        self.UIquickstartId.enabled = !locked;
    }
    if (self.UIwatsonOrganization) {
        self.UIwatsonOrganization.text = [Settings stringForKey:@"watsonorganization_preference"];
        self.UIwatsonOrganization.enabled = !locked;
    }
    if (self.UIwatsonDeviceType) {
        self.UIwatsonDeviceType.text = [Settings stringForKey:@"watsondevicetype_preference"];
        self.UIwatsonDeviceType.enabled = !locked;
    }
    if (self.UIwatsonDeviceId) {
        self.UIwatsonDeviceId.text = [Settings stringForKey:@"watsondeviceid_preference"];
        self.UIwatsonDeviceId.enabled = !locked;
    }
    if (self.UIwatsonAuthToken) {
        self.UIwatsonAuthToken.text = [Settings stringForKey:@"watsonauthtoken_preference"];
        self.UIwatsonAuthToken.enabled = !locked;
    }

    if (!self.UIusepolicy) {

        int mode = [Settings intForKey:@"mode"];

        NSArray <NSIndexPath *> *publishPaths = @[[NSIndexPath indexPathForRow:3 inSection:0]];
        for (NSIndexPath *indexPath in publishPaths) {
            if ([self isRowVisible:indexPath] && (mode != CONNECTION_MODE_PRIVATE && mode != CONNECTION_MODE_HTTP)) {
                [self deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else if (![self isRowVisible:indexPath] && (mode == CONNECTION_MODE_PRIVATE || mode == CONNECTION_MODE_HTTP)) {
                [self insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }

        NSArray <NSIndexPath *> *privatePaths = @[[NSIndexPath indexPathForRow:4 inSection:0],
                                                  [NSIndexPath indexPathForRow:5 inSection:0],
                                                  [NSIndexPath indexPathForRow:6 inSection:0],
                                                  [NSIndexPath indexPathForRow:7 inSection:0],
                                                  [NSIndexPath indexPathForRow:8 inSection:0],
                                                  [NSIndexPath indexPathForRow:9 inSection:0],
                                                  [NSIndexPath indexPathForRow:10 inSection:0]
                                                  ];
        for (NSIndexPath *indexPath in privatePaths) {
            if ([self isRowVisible:indexPath] && mode != CONNECTION_MODE_PRIVATE) {
                [self deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else if (![self isRowVisible:indexPath] && mode == CONNECTION_MODE_PRIVATE) {
                [self insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }

        if (self.UIUserID) {
            if (self.UIAuth) {
                self.UIUserID.enabled = !locked && self.UIAuth.on;
                self.UIUserID.textColor = self.UIAuth.on ? [UIColor blackColor] : [UIColor lightGrayColor];
            }
        }
        if (self.UIPassword) {
            if (self.UIAuth) {
                self.UIPassword.enabled = !locked && self.UIAuth.on;
                self.UIPassword.textColor = self.UIAuth.on ? [UIColor blackColor] : [UIColor lightGrayColor];
            }
        }

        NSArray <NSIndexPath *> *secretPaths = @[[NSIndexPath indexPathForRow:11 inSection:0]
                                                 ];
        for (NSIndexPath *indexPath in secretPaths) {
            if ([self isRowVisible:indexPath] && (mode != CONNECTION_MODE_PRIVATE && mode != CONNECTION_MODE_HTTP)) {
                [self deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else if (![self isRowVisible:indexPath] && (mode == CONNECTION_MODE_PRIVATE || mode == CONNECTION_MODE_HTTP)) {
                [self insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }

        NSArray <NSIndexPath *> *httpPaths = @[[NSIndexPath indexPathForRow:12 inSection:0]
                                               ];
        for (NSIndexPath *indexPath in httpPaths) {
            if ([self isRowVisible:indexPath] && mode != CONNECTION_MODE_HTTP) {
                [self deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else if (![self isRowVisible:indexPath] && mode == CONNECTION_MODE_HTTP) {
                [self insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
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

        NSArray <NSIndexPath *> *watsonQuickstartPaths = @[[NSIndexPath indexPathForRow:13 inSection:0]];
        for (NSIndexPath *indexPath in watsonQuickstartPaths) {
            if ([self isRowVisible:indexPath] && mode != CONNECTION_MODE_WATSON) {
                [self deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else if (![self isRowVisible:indexPath] && mode == CONNECTION_MODE_WATSON) {
                [self insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }

        NSArray <NSIndexPath *> *watsonRegisteredPaths = @[[NSIndexPath indexPathForRow:14 inSection:0],
                                                           [NSIndexPath indexPathForRow:15 inSection:0],
                                                           [NSIndexPath indexPathForRow:16 inSection:0],
                                                           [NSIndexPath indexPathForRow:17 inSection:0]
                                                           ];
        for (NSIndexPath *indexPath in watsonRegisteredPaths) {
            if ([self isRowVisible:indexPath] && mode != CONNECTION_MODE_WATSONREGISTERED) {
                [self deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else if (![self isRowVisible:indexPath] && mode == CONNECTION_MODE_WATSONREGISTERED) {
                [self insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }

        if ([self isSectionVisible:1] && !self.privileged) {
            [self deleteSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
        } else if (![self isSectionVisible:1] && self.privileged) {
            [self insertSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
        }


        if (self.UIexport) self.UIexport.hidden = (mode == CONNECTION_MODE_PUBLIC);
        if (self.UIpublish) self.UIpublish.hidden = (mode == CONNECTION_MODE_PUBLIC);

    }

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
    [self updateValues];
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
    [self updateValues];
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

- (IBAction)dataPressed:(UIButton *)sender {
    NSString *urlString = [NSString
                           stringWithFormat:@"https://quickstart.internetofthings.ibmcloud.com/#/device/%@/sensor/",
                           self.UIquickstartId.text];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
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
            return NSLocalizedString(@"exactly once (2)",
                                     @"description of MQTT QoS level 2");
        case 1:
            return NSLocalizedString(@"at least once (1)",
                                     @"description of MQTT QoS level 1");
        case 0:
        default:
            return NSLocalizedString(@"at most once (0)",
                                     @"description of MQTT QoS level 0");
    }
}

- (IBAction)touchedOutsideText:(UITapGestureRecognizer *)sender {
    [self.UIHost resignFirstResponder];
    [self.UIPort resignFirstResponder];
    [self.UIignoreStaleLocations resignFirstResponder];
    [self.UIignoreInaccurateLocations resignFirstResponder];
    [self.UIUserID resignFirstResponder];
    [self.UIPassword resignFirstResponder];
    [self.UIsecret resignFirstResponder];
    [self.UItrackerid resignFirstResponder];
    [self.UIDeviceID resignFirstResponder];
    [self.UIquickstartId resignFirstResponder];
    [self.UIwatsonOrganization resignFirstResponder];
    [self.UIwatsonDeviceType resignFirstResponder];
    [self.UIwatsonDeviceId resignFirstResponder];
    [self.UIwatsonAuthToken resignFirstResponder];
    [self.UImode resignFirstResponder];
}

#define INVALIDTRACKERID NSLocalizedString(@"TrackerID invalid", @"Alert header regarding TrackerID input")

- (IBAction)tidChanged:(UITextField *)sender {

    if (sender.text.length > 2) {
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:INVALIDTRACKERID
                                  message:NSLocalizedString(@"TrackerID may be empty or up to 2 characters long",
                                                            @"Alert content regarding TrackerID input")
                                  delegate:self
                                  cancelButtonTitle:nil
                                  otherButtonTitles:NSLocalizedString(@"OK",
                                                                      @"OK button title"),
                                  nil
                                  ];
        [alertView show];
        sender.text = [Settings stringForKey:@"trackerid_preference"];
        return;
    }
    for (int i = 0; i < sender.text.length; i++) {
        if (![[NSCharacterSet alphanumericCharacterSet] characterIsMember:[sender.text characterAtIndex:i]]) {
            self.tidAlertView = [[UIAlertView alloc]
                                 initWithTitle:INVALIDTRACKERID
                                 message:NSLocalizedString(@"TrackerID may contain alphanumeric characters only",
                                                           @"Alert content regarding TrackerID input")
                                 delegate:self
                                 cancelButtonTitle:nil
                                 otherButtonTitles:NSLocalizedString(@"OK",
                                                                     @"OK button title"),
                                 nil
                                 ];
            [self.tidAlertView show];
            sender.text = [Settings stringForKey:@"trackerid_preference"];
            return;
        }
    }
    [Settings setString:sender.text forKey:@"trackerid_preference"];
}

- (IBAction)modeChanged:(UITextField *)sender {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Mode change",
                                                                                          @"Alert header for mode change warning")
                                                                message:NSLocalizedString(@"Please be aware your stored waypoints and locations will be deleted on this device for privacy reasons. Please backup before.",
                                                                                          @"Alert content for mode change warning")
                                                         preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",
                                                                             @"Cancel button title")

                                                     style:UIAlertActionStyleCancel
                                                   handler:^(UIAlertAction *action){
                                                       [self updated];
                                                   }];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"Continue",
                                                                         @"Continue button title")

                                                 style:UIAlertActionStyleDestructive
                                               handler:^(UIAlertAction *action) {
                                                   OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
                                                   [delegate terminateSession];
                                                   [self updateValues];
                                                   [self updated];
                                                   [delegate reconnect];
                                                   [self.UImode resignFirstResponder];
                                               }];

    [ac addAction:cancel];
    [ac addAction:ok];
    [self presentViewController:ac animated:TRUE completion:nil];
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
    if (alertView == self.tidAlertView) {
        self.UItrackerid.text = [Settings stringForKey:@"trackerid_preference"];
    }
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
        [AlertView alert:QRSCANNER
                 message:NSLocalizedString(@"App does not have access to camera",
                                           @"content of an alert message regarging QR code scanning")
         ];
    }
}


#pragma mark - QRCodeReader Delegate Methods

- (void)reader:(QRCodeReaderViewController *)reader didScanResult:(NSString *)result
{
    [self dismissViewControllerAnimated:YES completion:^{
        DDLogVerbose(@"result %@", result);
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        if ([delegate application:[UIApplication sharedApplication] openURL:[NSURL URLWithString:result] options:@{}]) {
            [AlertView alert:QRSCANNER
                     message:NSLocalizedString(@"QR code successfully processed!",
                                               @"content of an alert message regarging QR code scanning")
             ];
        } else {
            [AlertView alert:QRSCANNER
                     message:delegate.processingMessage
             ];
        }
        delegate.processingMessage = nil;
    }];
}

- (void)readerDidCancel:(QRCodeReaderViewController *)reader
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}


@end
