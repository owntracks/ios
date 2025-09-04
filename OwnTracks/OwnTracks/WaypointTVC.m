//
//  WaypointTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.10.13.
//  Copyright © 2013-2025  Christoph Krey. All rights reserved.
//

#import "WaypointTVC.h"
#import "Friend+CoreDataClass.h"
#import "Waypoint+CoreDataClass.h"
#import "OwnTracksAppDelegate.h"
#import "LocationManager.h"
#import "PersonTVC.h"
#import "Settings.h"
#import "CoreData.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <Contacts/Contacts.h>

@interface WaypointTVC ()
@property (weak, nonatomic) IBOutlet UITextField *UIcoordinate;
@property (weak, nonatomic) IBOutlet UITextField *UIdistance;
@property (weak, nonatomic) IBOutlet UITextField *UItrigger;
@property (weak, nonatomic) IBOutlet UITextField *UImonitoring;
@property (weak, nonatomic) IBOutlet UITextField *UIconnection;
@property (weak, nonatomic) IBOutlet UITextField *UIregions;
@property (weak, nonatomic) IBOutlet UILabel *UIplace;
@property (weak, nonatomic) IBOutlet UITextField *UItimestamp;
@property (weak, nonatomic) IBOutlet UITextField *UItopic;
@property (weak, nonatomic) IBOutlet UITextField *UIinfo;
@property (weak, nonatomic) IBOutlet UITextField *UIcreatedAt;
@property (weak, nonatomic) IBOutlet UITextField *UIbatterylevel;
@property (weak, nonatomic) IBOutlet UITextField *UIbatterystatus;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *bookmarkButton;
@property (weak, nonatomic) IBOutlet UITextField *UIpoi;
@property (weak, nonatomic) IBOutlet UITextField *UItag;
@property (weak, nonatomic) IBOutlet UIImageView *UIphoto;
@property (weak, nonatomic) IBOutlet UITextField *UIimageName;
@property (weak, nonatomic) IBOutlet UITextField *UIpressure;
@property (weak, nonatomic) IBOutlet UITextField *UImotionActivities;

@property (nonatomic) BOOL needsUpdate;
@property (strong, nonatomic) CLRegion *oldRegion;
@end

@implementation WaypointTVC
static const DDLogLevel ddLogLevel = DDLogLevelInfo;

- (IBAction)setPerson:(UIStoryboardSegue *)segue {
    if ([segue.sourceViewController isKindOfClass:[PersonTVC class]]) {
        PersonTVC *personTVC = (PersonTVC *)segue.sourceViewController;
        self.waypoint.belongsTo.contactId = personTVC.contactId;
        [[CoreData sharedInstance] sync:self.waypoint.managedObjectContext];
        [self.tableView reloadData];
        self.title = self.waypoint.belongsTo.nameOrTopic;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    BOOL locked = [Settings theLockedInMOC:CoreData.sharedInstance.mainMOC];

    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    if (locked || status != CNAuthorizationStatusAuthorized) {
        [self.navigationItem setRightBarButtonItem:nil];
    }

    self.tableView.estimatedRowHeight = 150;
    self.tableView.rowHeight = UITableViewAutomaticDimension;

    self.title = self.waypoint.belongsTo.nameOrTopic;
    
    if ([[NSUserDefaults standardUserDefaults] integerForKey:@"noRevgeo"] > 0) {
        [self.waypoint getReverseGeoCode];
    } else {
        self.waypoint.placemark = self.waypoint.defaultPlacemark;
        self.waypoint.belongsTo.topic = self.waypoint.belongsTo.topic;
        [CoreData.sharedInstance sync:self.waypoint.managedObjectContext];
    }

    [self setup];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.waypoint removeObserver:self forKeyPath:@"placemark"];
}

- (void)setup {
    self.UIcoordinate.text = (self.waypoint).coordinateText;
    CLLocationDistance distance = [self.waypoint getDistanceFrom:[LocationManager sharedInstance].location];
    self.UIdistance.text = [Waypoint distanceText:distance];
    self.UItrigger.text = self.waypoint.triggerText;
    self.UImonitoring.text = self.waypoint.monitoringText;
    self.UIconnection.text = self.waypoint.connectionText;
    
    self.UIregions.text = @"-";
    if (self.waypoint.inRegions) {
        NSArray <NSString *>* inRegions = [NSJSONSerialization JSONObjectWithData:self.waypoint.inRegions
                                                                          options:0
                                                                            error:nil];
        for (NSString *inRegion in inRegions) {
            if ([self.UIregions.text isEqualToString:@"-"]) {
                self.UIregions.text = inRegion;
            } else {
                self.UIregions.text = [self.UIregions.text stringByAppendingFormat:@", %@", inRegion];
            }
        }
    }

    self.UImotionActivities.text = @"-";
    if (self.waypoint.motionActivities) {
        NSArray <NSString *>* motionActivities = [NSJSONSerialization JSONObjectWithData:self.waypoint.motionActivities
                                                                          options:0
                                                                            error:nil];
        for (NSString *motionActivity in motionActivities) {
            if ([self.UImotionActivities.text isEqualToString:@"-"]) {
                self.UImotionActivities.text = motionActivity;
            } else {
                self.UImotionActivities.text = [self.UImotionActivities.text stringByAppendingFormat:@", %@", motionActivity];
            }
        }
    }

    if (self.waypoint.pressure) {
        NSMeasurement *m = [[NSMeasurement alloc] initWithDoubleValue:self.waypoint.pressure.doubleValue
                                                                 unit:[NSUnitPressure kilopascals]];
        NSMeasurementFormatter *mf = [[NSMeasurementFormatter alloc] init];
        mf.unitOptions = NSMeasurementFormatterUnitOptionsNaturalScale;
        mf.numberFormatter.maximumFractionDigits = 3;
        self.UIpressure.text = [mf stringFromMeasurement:m];
    } else {
        self.UIpressure.text = NSLocalizedString( @"No pressure available",  @"No pressure available");
    }

    self.UItimestamp.text = (self.waypoint).timestampText;
    self.UIcreatedAt.text = (self.waypoint).createdAtText;
    self.UIinfo.text = (self.waypoint).infoText;
    self.UIbatterystatus.text = (self.waypoint).batteryStatusText;
    self.UIbatterylevel.text = (self.waypoint).batteryLevelText;
    self.UItopic.text = self.waypoint.belongsTo.topic;
    self.UIpoi.text = self.waypoint.poi;
    self.UItag.text = self.waypoint.tag;
    self.UIphoto.image = [UIImage imageWithData:self.waypoint.image];
    self.UIimageName.text = self.waypoint.imageName;

    [self.waypoint addObserver:self
                    forKeyPath:@"placemark"
                       options:NSKeyValueObservingOptionNew context:nil];
    self.UIplace.text = self.waypoint.placemark;
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    DDLogVerbose(@"revgeo updated");
    self.UIplace.text = self.waypoint.placemark;
}

- (IBAction)navigatePressed:(UIButton *)sender {
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake((self.waypoint.lat).doubleValue,
                                                              (self.waypoint.lon).doubleValue);
    MKPlacemark* place = [[MKPlacemark alloc] initWithCoordinate: coord addressDictionary: nil];
    MKMapItem* destination = [[MKMapItem alloc] initWithPlacemark: place];
    destination.name = self.waypoint.belongsTo.nameOrTopic;
    NSArray* items = @[destination];
    NSDictionary* options = @{MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving};
    [MKMapItem openMapsWithItems: items launchOptions: options];
}

- (NSIndexPath *)tableView:(UITableView *)tableView
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && indexPath.row == 0) {
        NSString *locationString = (self.waypoint).shortCoordinateText;
        UIPasteboard *generalPasteboard = [UIPasteboard generalPasteboard];
        [generalPasteboard setString:locationString];
        [NavigationController alert:NSLocalizedString(@"Clipboard",
                                                      @"Clipboard")
                            message:NSLocalizedString(@"Location copied to clipboard",
                                                      @"Location copied to clipboard")
                       dismissAfter:1
        ];
    } else if (indexPath.section == 1 && indexPath.row == 6) {
        UIPasteboard *generalPasteboard = [UIPasteboard generalPasteboard];
        [generalPasteboard setString:(self.waypoint).belongsTo.topic];
        [NavigationController alert:NSLocalizedString(@"Clipboard",
                                                      @"Clipboard")
                            message:NSLocalizedString(@"Topic copied to clipboard",
                                                      @"Topic copied to clipboard")
                       dismissAfter:1
        ];
    }

    return nil;
}

@end
