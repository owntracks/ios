//
//  RegionTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.10.13.
//  Copyright © 2013-2025  Christoph Krey. All rights reserved.
//

#import "RegionTVC.h"
#import "Friend+CoreDataClass.h"
#import "OwnTracksAppDelegate.h"
#import "Settings.h"
#import "CoreData.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface RegionTVC ()
@property (weak, nonatomic) IBOutlet UITextField *UIname;
@property (weak, nonatomic) IBOutlet UITextField *UIuuid;
@property (weak, nonatomic) IBOutlet UITextField *UImajor;
@property (weak, nonatomic) IBOutlet UITextField *UIminor;

@property (weak, nonatomic) IBOutlet UITextField *UIlatitude;
@property (weak, nonatomic) IBOutlet UITextField *UIlongitude;
@property (weak, nonatomic) IBOutlet UITextField *UIradius;

@property (nonatomic) BOOL needsUpdate;
@property (strong, nonatomic) CLRegion *oldRegion;
@end

@implementation RegionTVC
static const DDLogLevel ddLogLevel = DDLogLevelInfo;

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.UIlatitude.delegate = self;
    self.UIlongitude.delegate = self;
    self.UIname.delegate = self;
    self.UIuuid.delegate = self;
    self.UImajor.delegate = self;
    self.UIminor.delegate = self;
    self.UIradius.delegate = self;
    
    self.title = (self.region).name;
    
    [self setup];
    self.oldRegion = self.region.CLregion;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return TRUE;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.needsUpdate) {
        self.region.name = self.UIname.text;

        self.region.lat = @((self.UIlatitude.text).doubleValue);
        self.region.lon = @((self.UIlongitude.text).doubleValue);
        self.region.radius = @((self.UIradius.text).doubleValue);
        
        self.region.uuid = self.UIuuid.text;
        DDLogVerbose(@"UImajor %@", self.UImajor.text);
        DDLogVerbose(@"UImajor intValue %d", [self.UImajor.text intValue]);
        DDLogVerbose(@"UImajor NSNumber %@", @(self.UImajor.text.intValue));
        self.region.major = @((self.UImajor.text).intValue);
        self.region.minor = @((self.UIminor.text).intValue);
        
        OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [ad sendRegion:self.region];
        if (self.oldRegion) {
            DDLogVerbose(@"stopMonitoringForRegion %@", self.oldRegion.identifier);
            [[LocationManager sharedInstance] stopRegion:self.oldRegion];
        }
        if (self.region.CLregion) {
            DDLogVerbose(@"startMonitoringForRegion %@", self.region.name);
            [[LocationManager sharedInstance] startRegion:self.region.CLregion];
        }
    }
    [CoreData.sharedInstance sync:self.region.managedObjectContext];
}

- (void)setup {
    self.UIname.text = self.region.name;
    self.UIname.enabled = [self.editing boolValue];

    self.UIlatitude.text = [NSString stringWithFormat:@"%.14g", (self.region.lat).doubleValue];
    self.UIlatitude.enabled = [self.editing boolValue];

    self.UIlongitude.text = [NSString stringWithFormat:@"%.14g", (self.region.lon).doubleValue];
    self.UIlongitude.enabled = [self.editing boolValue];

    self.UIradius.text = [NSString stringWithFormat:@"%.14g", (self.region.radius).doubleValue];
    self.UIradius.enabled = [self.editing boolValue];
    
    self.UIuuid.text = self.region.uuid;
    self.UIuuid.enabled = [self.editing boolValue];
    DDLogVerbose(@"UImajor NSNumber %@", self.region.major);
    DDLogVerbose(@"UImajor unsignedIntValue %u", [self.region.major unsignedIntValue]);
    DDLogVerbose(@"UImajor NSString %@", [NSString stringWithFormat:@"%u", [self.region.major unsignedIntValue]]);
    self.UImajor.text = [NSString stringWithFormat:@"%u", (self.region.major).unsignedShortValue];
    self.UImajor.enabled = [self.editing boolValue];

    self.UIminor.text = [NSString stringWithFormat:@"%u", (self.region.minor).unsignedShortValue];
    self.UIminor.enabled = [self.editing boolValue];
}

- (IBAction)latitudechanged:(UITextField *)sender {
    self.needsUpdate = TRUE;
}

- (IBAction)longitudechanged:(UITextField *)sender {
    self.needsUpdate = TRUE;
}

- (IBAction)namechanged:(UITextField *)sender {
    self.needsUpdate = TRUE;
}

- (IBAction)radiuschanged:(UITextField *)sender {
    self.needsUpdate = TRUE;
}
- (IBAction)uuidchanged:(UITextField *)sender {
    self.needsUpdate = TRUE;
}
- (IBAction)majorchanged:(UITextField *)sender {
    self.needsUpdate = TRUE;
}
- (IBAction)minorchanged:(UITextField *)sender {
    self.needsUpdate = TRUE;
}

- (IBAction)navigatePressed:(UIButton *)sender {
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake((self.region.lat).doubleValue,
                                                              (self.region.lon).doubleValue);
    MKPlacemark* place = [[MKPlacemark alloc] initWithCoordinate: coord addressDictionary: nil];
    MKMapItem* destination = [[MKMapItem alloc] initWithPlacemark: place];
    destination.name = self.region.name;
    NSArray* items = @[destination];
    NSDictionary* options = @{MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving};
    [MKMapItem openMapsWithItems: items launchOptions: options];
}
@end
