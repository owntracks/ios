//
//  EditLocationTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.10.13.
//  Copyright (c) 2013, 2014 Christoph Krey. All rights reserved.
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
@property (weak, nonatomic) IBOutlet UITextField *UIaltitude;
@property (weak, nonatomic) IBOutlet UITextField *UIspeed;
@property (weak, nonatomic) IBOutlet UITextField *UIcourse;

@property (nonatomic) BOOL needsUpdate;
@property (strong, nonatomic) CLRegion *oldRegion;
@end

@implementation EditLocationTVC

- (void)setLocation:(Location *)location
{
    _location = location;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.title = [self.location nameText];
    
    [self.location getReverseGeoCode];
    [self setup];
    self.oldRegion = [self.location region];
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
#ifdef DEBUG
            NSLog(@"stopMonitoringForRegion %@", self.oldRegion.identifier);
#endif
            [delegate.manager stopMonitoringForRegion:self.oldRegion];
        }
        if ([self.location region]) {
#ifdef DEBUG
            NSLog(@"startMonitoringForRegion %@", self.location.region.identifier);
#endif

            [delegate.manager startMonitoringForRegion:[self.location region]];
        }
    }
}
- (void)setup
{
    self.UIlatitude.text = [NSString stringWithFormat:@"%g", [self.location.latitude doubleValue]];
    self.UIlongitude.text = [NSString stringWithFormat:@"%g", [self.location.longitude doubleValue]];
    
    self.UItimestamp.text = [self.location timestampText];
    self.UIaltitude.text = [NSString stringWithFormat:@"%d", [self.location.altitude intValue]];
    self.UIspeed.text = [NSString stringWithFormat:@"%d", [self.location.speed intValue]];
    self.UIcourse.text = [NSString stringWithFormat:@"%d", [self.location.course intValue]];
    
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

- (IBAction)new:(UIBarButtonItem *)sender {
    [self.location removeObserver:self forKeyPath:@"placemark"];

    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    self.location = [Location locationWithTopic:[delegate.settings theGeneralTopic]
                                            tid:[delegate.settings stringForKey:@"trackerid_preference"]
                                      timestamp:[NSDate date]
                                     coordinate:delegate.manager.location.coordinate
                                       accuracy:delegate.manager.location.horizontalAccuracy
                                       altitude:delegate.manager.location.altitude
                               verticalaccuracy:delegate.manager.location.verticalAccuracy
                                          speed:delegate.manager.location.speed
                                         course:delegate.manager.location.course
                                      automatic:NO
                                         remark:@"new location"
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
