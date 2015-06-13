//
//  EditLocationTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.10.13.
//  Copyright (c) 2013-2015 Christoph Krey. All rights reserved.
//

#import "EditLocationTVC.h"
#import "Friend+Create.h"
#import "OwnTracksAppDelegate.h"
#import "CoreData.h"
#import "AlertView.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface EditLocationTVC ()
@property (weak, nonatomic) IBOutlet UIButton *UIscan;
@property (weak, nonatomic) IBOutlet UITableViewCell *remarkCell;
@property (weak, nonatomic) IBOutlet UITextField *UItimestamp;
@property (weak, nonatomic) IBOutlet UITextField *UIlatitude;
@property (weak, nonatomic) IBOutlet UITextField *UIlongitude;
@property (weak, nonatomic) IBOutlet UITextView *UIplace;
@property (weak, nonatomic) IBOutlet UITextField *UIremark;
@property (weak, nonatomic) IBOutlet UITextField *UIradius;
@property (weak, nonatomic) IBOutlet UISwitch *UIshare;
@property (weak, nonatomic) IBOutlet UITextField *UItopic;
@property (weak, nonatomic) IBOutlet UITextField *UIinfo;

@property (nonatomic) BOOL needsUpdate;
@property (strong, nonatomic) CLRegion *oldRegion;
@property (strong, nonatomic) QRCodeReaderViewController *reader;
@end

@implementation EditLocationTVC
static const DDLogLevel ddLogLevel = DDLogLevelError;

- (void)setLocation:(Location *)location
{
    _location = location;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    DDLogVerbose(@"ddLogLevel %lu", (unsigned long)ddLogLevel);

    self.UIlatitude.delegate = self;
    self.UIlongitude.delegate = self;
    self.UIremark.delegate = self;
    self.UIradius.delegate = self;
    
    self.title = [self.location nameText];
    
    [self.location getReverseGeoCode];
    [self setup];
    self.oldRegion = [self.location region];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return TRUE;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.location removeObserver:self forKeyPath:@"placemark"];
    if (self.needsUpdate) {
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        if ([self.location sharedWaypoint]) {
            [delegate sendWayPoint:self.location];
        }
        if (self.oldRegion) {
            DDLogVerbose(@"stopMonitoringForRegion %@", self.oldRegion.identifier);
            [[LocationManager sharedInstance] stopRegion:self.oldRegion];
        }
        if ([self.location region]) {
            DDLogVerbose(@"startMonitoringForRegion %@", self.location.region.identifier);
            [[LocationManager sharedInstance] startRegion:[self.location region]];
        }
    }
}

- (void)setup
{
    self.UIlatitude.text = [NSString stringWithFormat:@"%g", [self.location.latitude doubleValue]];
    self.UIlongitude.text = [NSString stringWithFormat:@"%g", [self.location.longitude doubleValue]];
    
    self.UItimestamp.text = [self.location timestampText];
    self.UIinfo.text = [self.location infoText];
    self.UItopic.text = self.location.belongsTo.topic;
    
    [self.location addObserver:self forKeyPath:@"placemark" options:NSKeyValueObservingOptionNew context:nil];
    self.UIplace.text = self.location.placemark;
    
    self.UIremark.text = self.location.remark;
    self.UIradius.text = [self.location radiusText];
    self.UIshare.on = [self.location.share boolValue];
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    if (![self.location.automatic boolValue] && [self.location.belongsTo.topic
                                                 isEqualToString:[delegate.settings theGeneralTopic]]) {
        self.UIlatitude.enabled = TRUE;
        self.UIlatitude.userInteractionEnabled = TRUE;
        self.UIlatitude.textColor = [UIColor blackColor];

        self.UIlongitude.enabled = TRUE;
        self.UIlongitude.userInteractionEnabled = TRUE;
        self.UIlongitude.textColor = [UIColor blackColor];

        self.UIremark.enabled = TRUE;
        self.UIremark.userInteractionEnabled = TRUE;
        self.UIremark.textColor = [UIColor blackColor];

        self.UIradius.enabled = TRUE;
        self.UIradius.userInteractionEnabled = TRUE;
        self.UIradius.textColor = [UIColor blackColor];

        self.UIshare.enabled = TRUE;
        self.UIshare.userInteractionEnabled = TRUE;
        
        self.UIscan.enabled = TRUE;
        self.UIscan.userInteractionEnabled = TRUE;

    } else {
        self.UIlatitude.enabled = FALSE;
        self.UIlatitude.userInteractionEnabled = FALSE;
        self.UIlatitude.textColor = [UIColor lightGrayColor];
        
        self.UIlongitude.enabled = FALSE;
        self.UIlongitude.userInteractionEnabled = FALSE;
        self.UIlongitude.textColor = [UIColor lightGrayColor];
        
        self.UIremark.enabled = FALSE;
        self.UIremark.userInteractionEnabled = FALSE;
        self.UIremark.textColor = [UIColor lightGrayColor];
        
        self.UIradius.enabled = FALSE;
        self.UIradius.userInteractionEnabled = FALSE;
        self.UIradius.textColor = [UIColor lightGrayColor];
        
        self.UIshare.enabled = FALSE;
        self.UIshare.userInteractionEnabled = FALSE;
        
        self.UIscan.enabled = FALSE;
    }
}

- (IBAction)latitudechanged:(UITextField *)sender {
    self.location.latitude = @([sender.text doubleValue]);
    self.location.placemark = nil;
    self.location.accuracy = @(0);
    self.location.altitude = @(0);
    self.location.verticalaccuracy = @(0);
    self.location.speed = @(0);
    self.location.course = @(0);
    self.needsUpdate = TRUE;
}

- (IBAction)longitudechanged:(UITextField *)sender {
    self.location.longitude = @([sender.text doubleValue]);
    self.location.placemark = nil;
    self.location.accuracy = @(0);
    self.location.altitude = @(0);
    self.location.verticalaccuracy = @(0);
    self.location.speed = @(0);
    self.location.course = @(0);
    self.needsUpdate = TRUE;
}

- (IBAction)sharechanged:(UISwitch *)sender {
    self.location.share = @(sender.on);
    self.needsUpdate = TRUE;
}

- (IBAction)remarkchanged:(UITextField *)sender {
    if (![sender.text isEqualToString:self.location.remark]) {
        self.location.remark = sender.text;
        self.location.accuracy = @(0);
        self.location.altitude = @(0);
        self.location.verticalaccuracy = @(0);
        self.location.speed = @(0);
        self.location.course = @(0);
        self.needsUpdate = TRUE;
    }
}

- (IBAction)radiuschanged:(UITextField *)sender {
    if ([sender.text doubleValue] != [self.location.regionradius doubleValue]) {
        self.location.regionradius = @([sender.text doubleValue]);
        self.needsUpdate = TRUE;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    self.UIplace.text = self.location.placemark;
}

- (IBAction)navigatePressed:(UIButton *)sender {
    MKPlacemark* place = [[MKPlacemark alloc] initWithCoordinate: self.location.coordinate addressDictionary: nil];
    MKMapItem* destination = [[MKMapItem alloc] initWithPlacemark: place];
    destination.name = self.location.nameText;
    NSArray* items = [[NSArray alloc] initWithObjects: destination, nil];
    NSDictionary* options = [[NSDictionary alloc] initWithObjectsAndKeys:
                             MKLaunchOptionsDirectionsModeDriving,
                             MKLaunchOptionsDirectionsModeKey, nil];
    [MKMapItem openMapsWithItems: items launchOptions: options];
}

- (IBAction)scan:(UIButton *)sender {
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
        NSArray *components = [result componentsSeparatedByString:@":"];
        if (components.count == 5) {
            NSString *magic = components[0];
            if ([magic isEqualToString:@"BEACON"]) {
                NSString *name = components[1];
                NSString *uuid = components[2];
                int major = [components[3] intValue];
                int minor = [components[4] intValue];

                self.location.remark = [NSString stringWithFormat:@"%@:%@%@%@",
                                        name,
                                        uuid,
                                        major ? [NSString stringWithFormat:@":%d", major] : @"",
                                        minor ? [NSString stringWithFormat:@":%d", minor] : @""
                                        ];
                [self setup];
            } else {
                [AlertView alert:@"QRScanner" message:@"Unknown type"];
            }
            
        } else {
            [AlertView alert:@"QRScanner" message:@"Unknown format"];
        }
    }];
}

- (void)readerDidCancel:(QRCodeReaderViewController *)reader
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

@end
