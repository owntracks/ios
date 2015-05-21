//
//  ViewController.m
//  OwnTracks
//
//  Created by Christoph Krey on 17.08.13.
//  Copyright (c) 2013-2015 Christoph Krey. All rights reserved.
//

#import "ViewController.h"
#import "StatusTVC.h"
#import "FriendAnnotationV.h"
#import "FriendTVC.h"
#import "LocationTVC.h"
#import "EditLocationTVC.h"
#import "CoreData.h"
#import "Friend+Create.h"
#import "Location+Create.h"
#import "LocationManager.h"

#import <CocoaLumberjack/CocoaLumberjack.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *UIBadge;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *locationButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *beaconButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *connectionButton;

@property (nonatomic) int connectionStateOut;
@property (nonatomic) int connectionBufferedOut;

@property (nonatomic) BOOL beaconOn;

@property (strong, nonatomic) UIBarButtonItem *rootPopoverButtonItem;

@property (strong, nonatomic) NSFetchedResultsController *frc;
@property (nonatomic) BOOL suspendAutomaticTrackingOfChangesInManagedObjectContext;

@end

@implementation ViewController
static const DDLogLevel ddLogLevel = DDLogLevelError;

#define KEEPALIVE 600.0

- (void)setBadge:(NSNumber *)number {
    unsigned long inQueue = [number unsignedLongValue];
    DDLogVerbose(@"inQueue %lu", inQueue);
    if (self.UIBadge) {
        if (inQueue > 0) {
            self.UIBadge.text = [NSString stringWithFormat:@"%lu", inQueue];
        } else {
            self.UIBadge.text = @"";
        }
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    DDLogVerbose(@"ddLogLevel %lu", (unsigned long)ddLogLevel);
    
    self.mapView.delegate = self;
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    delegate.delegate = self;
    
    UISplitViewController *splitViewController;
    
    if (self.splitViewController) {
        splitViewController = self.splitViewController;
    }
    
    if (splitViewController) {
        splitViewController.delegate = self;
        splitViewController.presentsWithGesture = false;
    }
    
    self.mapView.mapType = MKMapTypeStandard;
    self.mapView.showsUserLocation = TRUE;
    
    
}

- (BOOL)splitViewController:(UISplitViewController *)svc
   shouldHideViewController:(UIViewController *)vc
              inOrientation:(UIInterfaceOrientation)orientation
{
    return YES;
}

- (void)splitViewController:(UISplitViewController *)svc
          popoverController:(UIPopoverController *)pc
  willPresentViewController:(UIViewController *)aViewController
{
    //
}

- (void)splitViewController:(UISplitViewController *)svc
     willHideViewController:(UIViewController *)aViewController
          withBarButtonItem:(UIBarButtonItem *)barButtonItem
       forPopoverController:(UIPopoverController *)pc
{
    [self showRootPopoverButtonItem:barButtonItem];
}

- (void)splitViewController:(UISplitViewController *)svc
     willShowViewController:(UIViewController *)aViewController
  invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    [self invalidateRootPopoverButtonItem:barButtonItem];
}


- (void)showRootPopoverButtonItem:(UIBarButtonItem *)barButtonItem {
    barButtonItem.image = [UIImage imageNamed:@"Friends"];
    self.rootPopoverButtonItem = barButtonItem;
    
    NSMutableArray *toolBarItems = [self.toolbar.items mutableCopy];
    [toolBarItems insertObject:barButtonItem atIndex:0];
    [self.toolbar setItems:toolBarItems animated:YES];
}


- (void)invalidateRootPopoverButtonItem:(UIBarButtonItem *)barButtonItem {
    NSMutableArray *toolBarItems = [self.toolbar.items mutableCopy];
    [toolBarItems removeObject:barButtonItem];
    [self.toolbar setItems:toolBarItems animated:YES];
    
    self.rootPopoverButtonItem = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.rootPopoverButtonItem) {
        if (![self.toolbar.items containsObject:self.rootPopoverButtonItem]) {
            NSMutableArray *toolBarItems = [self.toolbar.items mutableCopy];
            [toolBarItems insertObject:self.rootPopoverButtonItem atIndex:0];
            [self.toolbar setItems:toolBarItems animated:YES];
        }
    } else {
        if ([self.toolbar.items containsObject:self.rootPopoverButtonItem]) {
            NSMutableArray *toolBarItems = [self.toolbar.items mutableCopy];
            [toolBarItems removeObject:self.rootPopoverButtonItem];
            [self.toolbar setItems:toolBarItems animated:YES];
        }
    }
    
    [self performSelector:@selector(hideNavBar) withObject:nil afterDelay:2.0];
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate addObserver:self forKeyPath:@"connectionStateOut"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    [delegate addObserver:self forKeyPath:@"connectionBufferedOut"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    [delegate addObserver:self forKeyPath:@"inQueue"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    
    [self monitoringButtonImage];
    [self beaconButtonImage];
    [self connectionButtonImage];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if ([CoreData theManagedObjectContext]) {
        if (!self.frc) {
            [[LocationManager sharedInstance] resetRegions];
            
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Location"];
            request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
            
            self.frc = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                           managedObjectContext:[CoreData theManagedObjectContext]
                                                             sectionNameKeyPath:nil
                                                                      cacheName:nil];
            self.frc.delegate = self;
        }
    }
}

- (void)hideNavBar
{
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate removeObserver:self forKeyPath:@"connectionStateOut" context:nil];
    [delegate removeObserver:self forKeyPath:@"connectionBufferedOut" context:nil];
    [delegate removeObserver:self forKeyPath:@"inQueue" context:nil];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
}

- (void)setCenter:(Location *)location {
    CLLocationCoordinate2D coordinate = location.coordinate;
    [self.mapView setVisibleMapRect:[self centeredRect:coordinate] animated:YES];
    self.mapView.userTrackingMode = MKUserTrackingModeNone;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)object;
    if ([keyPath isEqualToString:@"connectionStateOut"] || [keyPath isEqualToString:@"connectionBufferedOut"]) {
        if ([keyPath isEqualToString:@"connectionStateOut"]) {
            self.connectionStateOut = [delegate.connectionStateOut intValue];
        }
        if ([keyPath isEqualToString:@"connectionBufferedOut"]) {
            self.connectionBufferedOut = [delegate.connectionBufferedOut intValue];
        }
        [self connectionButtonImage];
    }
    if ([keyPath isEqualToString:@"inQueue"]) {
        [self performSelectorOnMainThread:@selector(setBadge:) withObject:delegate.inQueue waitUntilDone:NO];
    }
}


#pragma UI actions

#define ACTION_MONITORING @"Location Monitoring Mode"
#define ACTION_MAP @"Map Modes"
#define ACTION_BEACON @"iBeacon"
#define ACTION_CONNECTION @"MQTT Connection"

- (IBAction)location:(UIBarButtonItem *)sender
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:ACTION_MONITORING
                                                             delegate:self
                                                    cancelButtonTitle:([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) ? @"Cancel" : nil
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:
                                  [NSString stringWithFormat:@"◼︎ Manual %@",
                                   [LocationManager sharedInstance].monitoring == 0 ? @"✔︎" : @""],
                                  [NSString stringWithFormat:@"▶︎ Significant Changes %@",
                                   [LocationManager sharedInstance].monitoring == 1 ? @"✔︎" : @""],
                                  [NSString stringWithFormat:@"▶︎▶︎ Move Mode %@",
                                   [LocationManager sharedInstance].monitoring == 2 ? @"✔︎" : @""],
                                  @"",
                                  @"Publish Now",
                                  nil];
    [actionSheet showFromBarButtonItem:sender animated:YES];
}

- (IBAction)friends:(UIBarButtonItem *)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:ACTION_MAP
                                                             delegate:self
                                                    cancelButtonTitle:([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) ? @"Cancel" : nil
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:
                                  [NSString stringWithFormat:@"No Tracking %@",
                                   self.mapView.userTrackingMode == MKUserTrackingModeNone ? @"✔︎" : @""],
                                  [NSString stringWithFormat:@"Follow %@",
                                   self.mapView.userTrackingMode == MKUserTrackingModeFollow ? @"✔︎" : @""],
                                  [NSString stringWithFormat:@"Follow with Heading %@",
                                   self.mapView.userTrackingMode == MKUserTrackingModeFollowWithHeading ? @"✔︎" : @""],
                                  @"",
                                  @"Show all Friends",
                                  @"",
                                  [NSString stringWithFormat:@"Standard Map %@",
                                   self.mapView.mapType == MKMapTypeStandard ? @"✔︎" : @""],
                                  [NSString stringWithFormat:@"Satellite Map %@",
                                   self.mapView.mapType == MKMapTypeSatellite ? @"✔︎" : @""],
                                  [NSString stringWithFormat:@"Hybrid Map %@",
                                   self.mapView.mapType == MKMapTypeHybrid ? @"✔︎" : @""],
                                  nil];
    [actionSheet showFromBarButtonItem:sender animated:YES];
}

- (IBAction)beaconPressed:(UIBarButtonItem *)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:ACTION_BEACON
                                                             delegate:self
                                                    cancelButtonTitle:([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) ? @"Cancel" : nil
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:
                                  [NSString stringWithFormat:@"Ranging On %@",
                                   [LocationManager sharedInstance].ranging ? @"✔︎" : @""],
                                  [NSString stringWithFormat:@"Ranging Off %@",
                                   ![LocationManager sharedInstance].ranging ? @"✔︎" : @""],
                                  nil];
    [actionSheet showFromBarButtonItem:sender animated:YES];
}

- (IBAction)connectionPressed:(UIBarButtonItem *)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:ACTION_CONNECTION
                                                             delegate:self
                                                    cancelButtonTitle:([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) ? @"Cancel" : nil
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:
                                  @"(Re-)Connect",
                                  @"Disconnect",
                                  nil];
    [actionSheet showFromBarButtonItem:sender animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if ([actionSheet.title isEqualToString:ACTION_MONITORING]) {
        switch (buttonIndex - actionSheet.firstOtherButtonIndex) {
            case 0:
                [LocationManager sharedInstance].monitoring = 0;
                break;
            case 1:
                [LocationManager sharedInstance].monitoring = 1;
                break;
            case 2:
                [LocationManager sharedInstance].monitoring = 2;
                break;
            case 4:
                [delegate sendNow];
                break;
        }
        [delegate.settings setInt:[LocationManager sharedInstance].monitoring forKey:@"monitoring_preference"];
        [self monitoringButtonImage];
        
    } else if ([actionSheet.title isEqualToString:ACTION_MAP]) {
        switch (buttonIndex - actionSheet.firstOtherButtonIndex) {
            case 0:
                [self.mapView setUserTrackingMode:MKUserTrackingModeNone animated:YES];
                break;
            case 1:
                [self.mapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
                break;
            case 2:
                [self.mapView setUserTrackingMode:MKUserTrackingModeFollowWithHeading animated:YES];
                break;
            case 4:
            {
                CLLocationCoordinate2D center = [LocationManager sharedInstance].location.coordinate;
                MKMapRect rect = [self centeredRect:center];
                
                for (Location *location in [Location allLocationsInManagedObjectContext:[CoreData theManagedObjectContext]])
                {
                    CLLocationCoordinate2D coordinate = location.coordinate;
                    if (coordinate.latitude != 0 || coordinate.longitude != 0) {
                        MKMapPoint point = MKMapPointForCoordinate(coordinate);
                        if (point.x < rect.origin.x) {
                            rect.size.width += rect.origin.x - point.x;
                            rect.origin.x = point.x;
                        }
                        if (point.x > rect.origin.x + rect.size.width) {
                            rect.size.width += point.x - rect.origin.x;
                        }
                        if (point.y < rect.origin.y) {
                            rect.size.height += rect.origin.y - point.y;
                            rect.origin.y = point.y;
                        }
                        if (point.y > rect.origin.y + rect.size.height) {
                            rect.size.height += point.y - rect.origin.y;
                        }
                    }
                }
                
                rect.origin.x -= rect.size.width/10.0;
                rect.origin.y -= rect.size.height/10.0;
                rect.size.width *= 1.2;
                rect.size.height *= 1.2;
                
                [self.mapView setUserTrackingMode:MKUserTrackingModeNone animated:YES];
                [self.mapView setVisibleMapRect:rect animated:YES];
                break;
            }
            case 6:
                self.mapView.mapType = MKMapTypeStandard;
                break;
            case 7:
                self.mapView.mapType = MKMapTypeSatellite;
                break;
            case 8:
                self.mapView.mapType = MKMapTypeHybrid;
                break;
        }
    } else if ([actionSheet.title isEqualToString:ACTION_BEACON]) {
        switch (buttonIndex - actionSheet.firstOtherButtonIndex) {
            case 0:
                [LocationManager sharedInstance].ranging = YES;
                break;
            case 1:
                [LocationManager sharedInstance].ranging = NO;
                break;
        }
        [delegate.settings setBool:[LocationManager sharedInstance].ranging forKey:@"ranging_preference"];
        [self beaconButtonImage];
        
    } else if ([actionSheet.title isEqualToString:ACTION_CONNECTION]) {
        switch (buttonIndex - actionSheet.firstOtherButtonIndex) {
            case 0:
                [delegate connectionOff];
                [delegate reconnect];
                break;
            case 1:
                [delegate connectionOff];
                break;
        }
        [self connectionButtonImage];
    }
}

- (void)monitoringButtonImage
{
    switch ([LocationManager sharedInstance].monitoring) {
        case 2:
            self.locationButton.image = [UIImage imageNamed:@"FastMode"];
            break;
        case 1:
            self.locationButton.image = [UIImage imageNamed:@"PlayMode"];
            break;
        case 0:
        default:
            self.locationButton.image = [UIImage imageNamed:@"StopMode"];
            break;
    }
}

- (void)beaconButtonImage
{
    if ([LocationManager sharedInstance].ranging) {
        self.beaconButton.image = [UIImage imageNamed:@"iBeaconOn"];
    } else {
        self.beaconButton.image = [UIImage imageNamed:@"iBeaconOff"];
    }
}

- (void)connectionButtonImage
{
    if (self.connectionBufferedOut) {
        if (self.connectionBufferedOut % 2) {
            self.connectionButton.image = [UIImage imageNamed:@"ConnectionMid"];
        } else {
            self.connectionButton.image = [UIImage imageNamed:@"ConnectionOff"];
        }
    } else {
        self.connectionButton.image = [UIImage imageNamed:@"ConnectionOn"];
    }
    
    switch (self.connectionStateOut) {
        case state_connected:
            self.connectionButton.tintColor = [UIColor colorWithRed:0.0 green:190.0/255.0 blue:0.0 alpha:1.0];
            break;
        case state_starting:
            self.connectionButton.tintColor = [UIColor colorWithRed:0.0 green:0.0 blue:190.0/255.0 alpha:1.0];
            break;
        case state_closed:
        case state_closing:
        case state_connecting:
            self.connectionButton.tintColor = [UIColor colorWithRed:190.0/255.0 green:190.0/255.0 blue:0.0 alpha:1.0];
            break;
        case state_error:
            self.connectionButton.tintColor = [UIColor colorWithRed:190.0/255.0 green:0.0 blue:0.0 alpha:1.0];
            break;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    /*
     * segue for location detail view
     */
    
    if ([segue.identifier isEqualToString:@"showDetail:"]) {
        if ([segue.destinationViewController respondsToSelector:@selector(setLocation:)]) {
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideNavBar) object:nil];
            MKAnnotationView *view = (MKAnnotationView *)sender;
            Location *location  = (Location *)view.annotation;
            [segue.destinationViewController performSelector:@selector(setLocation:) withObject:location];
        }
    }
}

#pragma centeredRect

#define INITIAL_RADIUS 600.0

- (MKMapRect)centeredRect:(CLLocationCoordinate2D)center
{
    MKMapRect rect;
    
    double r = INITIAL_RADIUS * MKMapPointsPerMeterAtLatitude(center.latitude);
    
    rect.origin = MKMapPointForCoordinate(center);
    rect.origin.x -= r;
    rect.origin.y -= r;
    rect.size.width = 2*r;
    rect.size.height = 2*r;
    
    return rect;
}



#pragma RangingDelegate
- (void)regionState:(CLRegion *)region inside:(BOOL)inside {
    if ([[LocationManager sharedInstance] insideBeaconRegion]) {
        self.beaconButton.tintColor = [UIColor colorWithRed:190.0/255.0 green:0.0 blue:0.0 alpha:1.0];
    } else {
        self.beaconButton.tintColor = [UIColor colorWithRed:0.0 green:0.0 blue:190.0/255.0 alpha:1.0];
    }
}

- (void)beaconInRange:(CLBeacon *)beacon {
    self.beaconOn = !self.beaconOn;
    if (self.beaconOn) {
        self.beaconButton.image = [UIImage imageNamed:@"iBeaconOn"];
    } else {
        self.beaconButton.image = [UIImage imageNamed:@"iBeaconOff"];
    }
}

#pragma MKMapViewDelegate

#define REUSE_ID_PIN @"Annotation_pin"
#define REUSE_ID_PICTURE @"Annotation_picture"
#define OLD_TIME -12*60*60

// This is a hack because the FriendAnnotationView did not erase it's callout after being dragged
- (void)mapView:(MKMapView *)mapView
 annotationView:(MKAnnotationView *)view
didChangeDragState:(MKAnnotationViewDragState)newState
   fromOldState:(MKAnnotationViewDragState)oldState {
    if (newState == MKAnnotationViewDragStateNone) {
        DDLogVerbose(@"MKAnnotationViewDragStateNone");
        NSArray *annotations = mapView.annotations;
        [mapView removeAnnotations:annotations];
        [mapView addAnnotations:annotations];
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    } else {
        if ([annotation isKindOfClass:[Location class]]) {
            Location *location = (Location *)annotation;
            MKAnnotationView *annotationView;
            
            OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
            if ([location.belongsTo.topic isEqualToString:[delegate.settings theGeneralTopic]]) {
                if (location == [location.belongsTo newestLocation]) {
                    annotationView = [self pictureAnnotationView:mapView location:location];
                } else {
                    annotationView = [self pinAnnotationView:mapView location:location];
                }
            } else {
                annotationView = [self pictureAnnotationView:mapView location:location];
            }
            
            DDLogVerbose(@"location.automatic: %@", location.automatic ? [location.automatic boolValue] ? @"true" : @"false" : @"nil");

            annotationView.draggable = ![location.automatic boolValue];
            annotationView.canShowCallout = YES;
            annotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
            UIButton *refreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
            [refreshButton setImage:[UIImage imageNamed:@"Refresh"] forState:UIControlStateNormal];
            [refreshButton sizeToFit];
            annotationView.leftCalloutAccessoryView = refreshButton;
            [annotationView setNeedsDisplay];
            return annotationView;
        }
        return nil;
    }
}

- (MKAnnotationView *)pictureAnnotationView:(MKMapView *)mapView location:(Location *)location {
    MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_PICTURE];
    FriendAnnotationV *friendAnnotationV;
    if (annotationView) {
        friendAnnotationV = (FriendAnnotationV *)annotationView;
    } else {
        friendAnnotationV = [[FriendAnnotationV alloc] initWithAnnotation:location reuseIdentifier:REUSE_ID_PICTURE];
    }
    
    NSData *data = [location.belongsTo image];
    UIImage *image = [UIImage imageWithData:data];
    friendAnnotationV.personImage = image;
    friendAnnotationV.tid = [location.belongsTo getEffectiveTid];
    friendAnnotationV.speed = [location.speed doubleValue];
    friendAnnotationV.course = [location.course doubleValue];
    friendAnnotationV.automatic = [location.automatic boolValue];
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    friendAnnotationV.me = [location.belongsTo.topic isEqualToString:[delegate.settings theGeneralTopic]];
    return friendAnnotationV;
}

- (MKAnnotationView *)pinAnnotationView:(MKMapView *)mapView location:(Location *)location {
    MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_PIN];
    MKPinAnnotationView *pinAnnotationView;
    if (annotationView) {
        pinAnnotationView = (MKPinAnnotationView *)annotationView;
    } else {
        pinAnnotationView  = [[MKPinAnnotationView alloc] initWithAnnotation:location reuseIdentifier:REUSE_ID_PIN];
    }
    
    if ([location.automatic boolValue]) {
        pinAnnotationView.pinColor = MKPinAnnotationColorRed;
    } else {
        pinAnnotationView.pinColor = MKPinAnnotationColorPurple;
    }
    return pinAnnotationView;
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[Location class]]) {
        MKCircleRenderer *renderer = [[MKCircleRenderer alloc] initWithCircle:overlay];
        
        Location *location = (Location *)overlay;
        if ([location.verticalaccuracy boolValue]) {
            renderer.fillColor = [UIColor colorWithRed:1.0 green:0.5 blue:0.5 alpha:0.333];
        } else {
            renderer.fillColor = [UIColor colorWithRed:0.5 green:0.5 blue:1.0 alpha:0.333];
        }
        return renderer;
        
    } else {
        return nil;
    }
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
    DDLogVerbose(@"calloutAccessoryControlTapped %@ %@", view, control);
    if (control == view.rightCalloutAccessoryView) {
        [self performSegueWithIdentifier:@"showDetail:" sender:view];
    } else if (control == view.leftCalloutAccessoryView) {
        Location *location = (Location *)view.annotation;
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[[UIApplication sharedApplication] delegate];
        [delegate requestLocationFromFriend:location.belongsTo];
    }
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)performFetch
{
    if (self.frc) {
        if (self.frc.fetchRequest.predicate) {
            DDLogVerbose(@"[%@ %@] fetching %@ with predicate: %@",
                         NSStringFromClass([self class]),
                         NSStringFromSelector(_cmd),
                         self.frc.fetchRequest.entityName,
                         self.frc.fetchRequest.predicate);
        } else {
            DDLogVerbose(@"[%@ %@] fetching all %@ (i.e., no predicate)",
                         NSStringFromClass([self class]),
                         NSStringFromSelector(_cmd),
                         self.frc.fetchRequest.entityName);
        }
        NSError *error;
        [self.frc performFetch:&error];
        if (error) DDLogError(@"[%@ %@] %@ (%@)", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [error localizedDescription], [error localizedFailureReason]);
    } else {
        DDLogVerbose(@"[%@ %@] no NSFetchedResultsController (yet?)", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
    }
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    
    [self.mapView addAnnotations:[Location allValidLocationsInManagedObjectContext:[CoreData theManagedObjectContext]]];
    
    NSArray *overlays = [Location allWaypointsOfTopic:[delegate.settings theGeneralTopic]
                               inManagedObjectContext:[CoreData theManagedObjectContext]];
    
    [self.mapView addOverlays:overlays];
    for (Location *location in overlays) {
        if (location.region) {
            [[LocationManager sharedInstance] startRegion:location.region];
        }
    }
}

- (void)setFrc:(NSFetchedResultsController *)newfrc
{
    NSFetchedResultsController *oldfrc = _frc;
    if (newfrc != oldfrc) {
        _frc = newfrc;
        newfrc.delegate = self;
        if ((!self.title || [self.title isEqualToString:oldfrc.fetchRequest.entity.name]) && (!self.navigationController || !self.navigationItem.title)) {
            self.title = newfrc.fetchRequest.entity.name;
        }
        if (newfrc) {
            DDLogVerbose(@"[%@ %@] %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), oldfrc ? @"updated" : @"set");
            [self performFetch];
        } else {
            DDLogVerbose(@"[%@ %@] reset to nil", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
        }
    }
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    //
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type
{
    if (!self.suspendAutomaticTrackingOfChangesInManagedObjectContext)
    {
        switch(type)
        {
            case NSFetchedResultsChangeInsert:
            case NSFetchedResultsChangeDelete:
            case NSFetchedResultsChangeUpdate:
            default:
                break;
        }
    }
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    if (!self.suspendAutomaticTrackingOfChangesInManagedObjectContext)
    {
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        Location *location = (Location *)anObject;
        CLLocationCoordinate2D coordinate = location.coordinate;
        
        switch(type)
        {
            case NSFetchedResultsChangeInsert:
                if (coordinate.latitude != 0 || coordinate.longitude != 0) {
                    [self.mapView addAnnotation:location];
                }
                if ([location.belongsTo.topic isEqualToString:[delegate.settings theGeneralTopic]]) {
                    [self.mapView addOverlay:location];
                    if (location.region) {
                        [[LocationManager sharedInstance] startRegion:location.region];
                    }
                }
                break;
                
            case NSFetchedResultsChangeDelete:
                [self.mapView removeAnnotation:location];
                if ([location.belongsTo.topic isEqualToString:[delegate.settings theGeneralTopic]]) {
                    [self.mapView removeOverlay:location];
                    [[LocationManager sharedInstance] stopRegion:location.region];
                }
                break;
                
            case NSFetchedResultsChangeUpdate:
            case NSFetchedResultsChangeMove:
                [self.mapView removeAnnotation:location];
                if ([location.belongsTo.topic isEqualToString:[delegate.settings theGeneralTopic]]) {
                    [self.mapView removeOverlay:location];
                    [self.mapView addOverlay:location];
                }
                if (coordinate.latitude != 0 || coordinate.longitude != 0) {
                    [self.mapView addAnnotation:location];
                }
                break;
        }
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    //
}

- (void)endSuspensionOfUpdatesDueToContextChanges
{
    self.suspendAutomaticTrackingOfChangesInManagedObjectContext = NO;
}

- (void)setSuspendAutomaticTrackingOfChangesInManagedObjectContext:(BOOL)suspend
{
    if (suspend) {
        _suspendAutomaticTrackingOfChangesInManagedObjectContext = YES;
    } else {
        [self endSuspensionOfUpdatesDueToContextChanges];
    }
}
- (IBAction)longDoublePress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [delegate sendNow];
    }
}

- (IBAction)longPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        CLLocationCoordinate2D center = self.mapView.centerCoordinate;
        CLLocation *location = [[CLLocation alloc] initWithLatitude:center.latitude longitude:center.longitude];
        
        [Location locationWithTopic:[delegate.settings theGeneralTopic]
                                tid:[delegate.settings stringForKey:@"trackerid_preference"]
                          timestamp:[NSDate date]
                         coordinate:location.coordinate
                           accuracy:location.horizontalAccuracy
                           altitude:location.altitude
                   verticalaccuracy:location.verticalAccuracy
                              speed:location.speed
                             course:location.course
                          automatic:NO
                             remark:@"Center"
                             radius:0
                              share:NO
             inManagedObjectContext:[CoreData theManagedObjectContext]
         ];
    }
}

@end
