//
//  RegionTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.10.13.
//  Copyright © 2013-2022  Christoph Krey. All rights reserved.
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
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.UIlatitude.delegate = self;
    self.UIlongitude.delegate = self;
    self.UIname.delegate = self;
    self.UIuuid.delegate = self;
    self.UImajor.delegate = self;
    self.UIminor.delegate = self;
    self.UIradius.delegate = self;
    
    self.title = (self.editRegion).name;
    
    [self setup];
    self.oldRegion = self.editRegion.CLregion;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return TRUE;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.needsUpdate) {
        self.editRegion.name = self.UIname.text;

        self.editRegion.lat = @((self.UIlatitude.text).doubleValue);
        self.editRegion.lon = @((self.UIlongitude.text).doubleValue);
        self.editRegion.radius = @((self.UIradius.text).doubleValue);
        
        self.editRegion.uuid = self.UIuuid.text;
        DDLogVerbose(@"UImajor %@", self.UImajor.text);
        DDLogVerbose(@"UImajor intValue %d", [self.UImajor.text intValue]);
        DDLogVerbose(@"UImajor NSNumber %@", @(self.UImajor.text.intValue));
        self.editRegion.major = @((self.UImajor.text).intValue);
        self.editRegion.minor = @((self.UIminor.text).intValue);
        
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [delegate sendRegion:self.editRegion];
        if (self.oldRegion) {
            DDLogVerbose(@"stopMonitoringForRegion %@", self.oldRegion.identifier);
            [[LocationManager sharedInstance] stopRegion:self.oldRegion];
        }
        if (self.editRegion.CLregion) {
            DDLogVerbose(@"startMonitoringForRegion %@", self.editRegion.name);
            [[LocationManager sharedInstance] startRegion:self.editRegion.CLregion];
        }
    }
    [CoreData.sharedInstance sync:self.editRegion.managedObjectContext];
}

- (void)setup {
    self.UIname.text = self.editRegion.name;

    self.UIlatitude.text = [NSString stringWithFormat:@"%.14g", (self.editRegion.lat).doubleValue];
    self.UIlongitude.text = [NSString stringWithFormat:@"%.14g", (self.editRegion.lon).doubleValue];
    self.UIradius.text = [NSString stringWithFormat:@"%.14g", (self.editRegion.radius).doubleValue];
    
    self.UIuuid.text = self.editRegion.uuid;
    DDLogVerbose(@"UImajor NSNumber %@", self.editRegion.major);
    DDLogVerbose(@"UImajor unsignedIntValue %u", [self.editRegion.major unsignedIntValue]);
    DDLogVerbose(@"UImajor NSString %@", [NSString stringWithFormat:@"%u", [self.editRegion.major unsignedIntValue]]);
    self.UImajor.text = [NSString stringWithFormat:@"%u", (self.editRegion.major).unsignedShortValue];
    self.UIminor.text = [NSString stringWithFormat:@"%u", (self.editRegion.minor).unsignedShortValue];
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

@end
