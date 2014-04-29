//
//  EditLocationTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.10.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "EditLocationTVC.h"
#import "Friend+Create.h"
#import "OwnTracksAppDelegate.h"
#import "CoreData.h"

@interface EditLocationTVC ()
@property (weak, nonatomic) IBOutlet UIBarButtonItem *UInew;
@property (weak, nonatomic) IBOutlet UITableViewCell *remarkCell;
@property (weak, nonatomic) IBOutlet UITextField *UItimestamp;
@property (weak, nonatomic) IBOutlet UITextField *UIlatitude;
@property (weak, nonatomic) IBOutlet UITextField *UIlongitude;
@property (weak, nonatomic) IBOutlet UITextView *UIplace;
@property (weak, nonatomic) IBOutlet UITextField *UIremark;
@property (weak, nonatomic) IBOutlet UITextField *UIradius;
@property (weak, nonatomic) IBOutlet UISwitch *UIshare;

@property (nonatomic) BOOL needsUpdate;
@property (strong, nonatomic) CLRegion *oldRegion;
@end

@implementation EditLocationTVC

- (void)setLocation:(Location *)location
{
    _location = location;
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
            [delegate.manager stopMonitoringForRegion:self.oldRegion];
        }
        if ([self.location region]) {
            [delegate.manager startMonitoringForRegion:[self.location region]];
        }
    }
}
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.title = [self.location nameText];

    [self.location getReverseGeoCode];
    [self setup];
    self.oldRegion = [self.location region];
}

- (void)setup
{
    self.UIlatitude.text = [NSString stringWithFormat:@"%g", [self.location.latitude doubleValue]];
    self.UIlongitude.text = [NSString stringWithFormat:@"%g", [self.location.longitude doubleValue]];
    
    self.UItimestamp.text = [self.location timestampText];
    
    [self.location addObserver:self forKeyPath:@"placemark" options:NSKeyValueObservingOptionNew context:nil];
    self.UIplace.text = self.location.placemark;
    
    self.UIremark.text = self.location.remark;
    self.UIradius.text = [self.location radiusText];
    self.UIshare.on = [self.location.share boolValue];
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    if (![self.location.automatic boolValue] && [self.location.belongsTo.topic
                                                 isEqualToString:[delegate.settings theGeneralTopic]]) {
        self.UIlatitude.enabled = TRUE;
        self.UIlongitude.enabled = TRUE;
        self.UIremark.enabled = TRUE;
        self.UIradius.enabled = TRUE;
        self.UIshare.enabled = TRUE;
    } else {
        self.UIlatitude.enabled = FALSE;
        self.UIlongitude.enabled = FALSE;
        self.UIremark.enabled = FALSE;
        self.UIradius.enabled = FALSE;
        self.UIshare.enabled = FALSE;
    }
    if ([self.location.belongsTo.topic
         isEqualToString:[delegate.settings theGeneralTopic]]) {
        self.UInew.enabled = TRUE;
    } else {
        self.UInew.enabled = FALSE;
    }
}

- (IBAction)latitudechanged:(UITextField *)sender {
    self.location.latitude = @([sender.text doubleValue]);
    self.location.placemark = nil;
    self.location.accuracy = @(0);
    self.needsUpdate = TRUE;
}

- (IBAction)longitudechanged:(UITextField *)sender {
    self.location.longitude = @([sender.text doubleValue]);
    self.location.placemark = nil;
    self.location.accuracy = @(0);
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

- (IBAction)new:(UIBarButtonItem *)sender {
    [self.location removeObserver:self forKeyPath:@"placemark"];

    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    self.location = [Location locationWithTopic:[delegate.settings theGeneralTopic]
                                      timestamp:[NSDate date]
                                     coordinate:CLLocationCoordinate2DMake(0, 0)
                                       accuracy:0
                                      automatic:NO
                                         remark:@""
                                         radius:0
                                          share:NO
                         inManagedObjectContext:[CoreData theManagedObjectContext]
                     ];
    [self setup];
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

@end
