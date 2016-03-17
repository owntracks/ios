//
//  WaypointTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.10.13.
//  Copyright © 2013-2016 Christoph Krey. All rights reserved.
//

#import "WaypointTVC.h"
#import "Friend+Create.h"
#import "Waypoint+Create.h"
#import "OwnTracksAppDelegate.h"
#import "PersonTVC.h"
#import "Settings.h"
#import "CoreData.h"
#import "AlertView.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface WaypointTVC ()
@property (weak, nonatomic) IBOutlet UITextField *UIcoordinate;
@property (weak, nonatomic) IBOutlet UILabel *UIplace;
@property (weak, nonatomic) IBOutlet UITextField *UItimestamp;
@property (weak, nonatomic) IBOutlet UITextField *UItopic;
@property (weak, nonatomic) IBOutlet UITextField *UIinfo;

@property (nonatomic) BOOL needsUpdate;
@property (strong, nonatomic) CLRegion *oldRegion;
@end

@implementation WaypointTVC
static const DDLogLevel ddLogLevel = DDLogLevelError;

- (IBAction)setPerson:(UIStoryboardSegue *)segue {
    if ([segue.sourceViewController isKindOfClass:[PersonTVC class]]) {
        PersonTVC *personTVC = (PersonTVC *)segue.sourceViewController;
        [self.waypoint.belongsTo linkToAB:personTVC.person];
        [self.tableView reloadData];
        self.title = self.waypoint.belongsTo.nameOrTopic;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.tableView.estimatedRowHeight = 150;
    self.tableView.rowHeight = UITableViewAutomaticDimension;

    self.title = self.waypoint.belongsTo.nameOrTopic;
    
    [self.waypoint getReverseGeoCode];
    [self setup];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.waypoint removeObserver:self forKeyPath:@"placemark"];
}

- (void)setup
{
    self.UIcoordinate.text = [self.waypoint coordinateText];
    
    self.UItimestamp.text = [self.waypoint timestampText];
    self.UIinfo.text = [self.waypoint infoText];
    self.UItopic.text = self.waypoint.belongsTo.topic;
    
    [self.waypoint addObserver:self forKeyPath:@"placemark" options:NSKeyValueObservingOptionNew context:nil];
    self.UIplace.text = self.waypoint.placemark;
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    DDLogVerbose(@"revgeo updated");
    self.UIplace.text = self.waypoint.placemark;
}

- (IBAction)navigatePressed:(UIButton *)sender {
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake([self.waypoint.lat doubleValue],
                                                              [self.waypoint.lon doubleValue]);
    MKPlacemark* place = [[MKPlacemark alloc] initWithCoordinate: coord addressDictionary: nil];
    MKMapItem* destination = [[MKMapItem alloc] initWithPlacemark: place];
    destination.name = self.waypoint.belongsTo.nameOrTopic;
    NSArray* items = [[NSArray alloc] initWithObjects: destination, nil];
    NSDictionary* options = [[NSDictionary alloc] initWithObjectsAndKeys:
                             MKLaunchOptionsDirectionsModeDriving,
                             MKLaunchOptionsDirectionsModeKey, nil];
    [MKMapItem openMapsWithItems: items launchOptions: options];
}

@end
