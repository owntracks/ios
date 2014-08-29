//
//  ViewController.m
//  OwnTracks
//
//  Created by Christoph Krey on 17.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
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

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *locationButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *beaconButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *connectionButton;

@property (nonatomic) BOOL beaconOn;

@property (strong, nonatomic) UIBarButtonItem *rootPopoverButtonItem;

@property (strong, nonatomic) NSFetchedResultsController *frc;
@property (nonatomic) BOOL suspendAutomaticTrackingOfChangesInManagedObjectContext;

@end

@implementation ViewController

#define KEEPALIVE 600.0

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.mapView.delegate = self;
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    delegate.delegate = self;
 
    self.mapView.mapType = MKMapTypeStandard;
    self.mapView.showsUserLocation = TRUE;
    
    UISplitViewController *splitViewController;
    
    if (self.splitViewController) {
        splitViewController = self.splitViewController;
    }
    
    if (splitViewController) {
        splitViewController.delegate = self;
        splitViewController.presentsWithGesture = false;
    }
    
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
    [delegate addObserver:self forKeyPath:@"connectionState" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    [delegate addObserver:self forKeyPath:@"connectionBuffered" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    
    [self monitoringButtonImage];
    [self beaconButtonImage];
    [self connectionButtonImage];
    
    if ([CoreData theManagedObjectContext]) {
        if (!self.frc) {
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
    [delegate removeObserver:self forKeyPath:@"connectionState" context:nil];
    [delegate removeObserver:self forKeyPath:@"connectionBuffered" context:nil];
    
    [self.navigationController setNavigationBarHidden:NO animated:NO];
}

- (void)setCenter:(Location *)location {
    CLLocationCoordinate2D coordinate = location.coordinate;
    [self.mapView setVisibleMapRect:[self centeredRect:coordinate] animated:YES];
    self.mapView.userTrackingMode = MKUserTrackingModeNone;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self connectionButtonImage];
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
                                  @"Manual",
                                  @"Significant Changes",
                                  @"Move Mode",
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
                                  @"No Tracking",
                                  @"Follow",
                                  @"Follow with Heading",
                                  @"Show all Friends",
                                  @"Standard Map",
                                  @"Satellite Map",
                                  @"Hybrid Map",
                                  nil];
    [actionSheet showFromBarButtonItem:sender animated:YES];
}

- (IBAction)beaconPressed:(UIBarButtonItem *)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:ACTION_BEACON
                                                             delegate:self
                                                    cancelButtonTitle:([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) ? @"Cancel" : nil
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:
                                  @"Start Ranging",
                                  @"Stop Ranging",
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
                delegate.monitoring = 0;
                break;
            case 1:
                delegate.monitoring = 1;
                break;
            case 2:
                delegate.monitoring = 2;
                break;
            case 3:
                [delegate sendNow];
                break;
        }
        
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
            case 3:
            {
                CLLocationCoordinate2D center = delegate.manager.location.coordinate;
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
            case 4:
                self.mapView.mapType = MKMapTypeStandard;
                break;
            case 5:
                self.mapView.mapType = MKMapTypeSatellite;
                break;
            case 6:
                self.mapView.mapType = MKMapTypeHybrid;
                break;
        }
    } else if ([actionSheet.title isEqualToString:ACTION_BEACON]) {
        switch (buttonIndex - actionSheet.firstOtherButtonIndex) {
            case 0:
                delegate.ranging = YES;
                break;
            case 1:
                delegate.ranging = NO;
                break;
        }
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
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[[UIApplication sharedApplication] delegate];

    switch (delegate.monitoring) {
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
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if (delegate.ranging) {
        self.beaconButton.image = [UIImage imageNamed:@"iBeaconOn"];
    } else {
        self.beaconButton.image = [UIImage imageNamed:@"iBeaconOff"];
    }
}

- (void)connectionButtonImage
{
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    switch ([delegate.connectionState intValue]) {
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
    
    if ([delegate.connectionBuffered intValue]) {
        if ([delegate.connectionBuffered intValue] % 2) {
            self.connectionButton.image = [UIImage imageNamed:@"ConnectionMid"];
        } else {
            self.connectionButton.image = [UIImage imageNamed:@"ConnectionOff"];
        }
    } else {
        self.connectionButton.image = [UIImage imageNamed:@"ConnectionOn"];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    /*
     * segue for location detail view
     */
    
    if ([segue.identifier isEqualToString:@"showDetail:"]) {
        if ([segue.destinationViewController respondsToSelector:@selector(setLocation:)]) {
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
- (void)didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
    if ([region isKindOfClass:[CLBeaconRegion class]]) {
        switch (state) {
            case CLRegionStateInside:
                self.beaconButton.tintColor = [UIColor colorWithRed:190.0/255.0 green:0.0 blue:0.0 alpha:1.0];
                break;
            case CLRegionStateOutside:
                self.beaconButton.tintColor = [UIColor colorWithRed:0.0 green:0.0 blue:190.0/255.0 alpha:1.0];
                break;
            case CLRegionStateUnknown:
            default:
                self.beaconButton.tintColor = [UIColor colorWithRed:190.0/255.0 green:190.0/255.0 blue:190.0/255.0 alpha:1.0];
                break;
        }
    }
}

- (void)didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    self.beaconOn = !self.beaconOn;
    if (self.beaconOn) {
        self.beaconButton.image = [UIImage imageNamed:@"iBeaconOn"];
    } else {
        self.beaconButton.image = [UIImage imageNamed:@"iBeaconOff"];
    }
}

#pragma MKMapViewDelegate

#define REUSE_ID_OTHER @"Annotation_other"
#define REUSE_ID_PICTURE @"Annotation_picture"
#define OLD_TIME -12*60*60

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    } else {
        if ([annotation isKindOfClass:[Location class]]) {
            Location *location = (Location *)annotation;
            
            MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_PICTURE];
            FriendAnnotationV *friendAnnotationV;
            if (annotationView) {
                friendAnnotationV = (FriendAnnotationV *)annotationView;
            } else {
                friendAnnotationV = [[FriendAnnotationV alloc] initWithAnnotation:annotation reuseIdentifier:REUSE_ID_PICTURE];
                friendAnnotationV.canShowCallout = YES;
            }
            
            friendAnnotationV.personImage = [UIImage imageWithData:[location.belongsTo image]];
            friendAnnotationV.tid = [location.belongsTo getEffectiveTid];
            friendAnnotationV.speed = [location.speed doubleValue];
            friendAnnotationV.course = [location.course doubleValue];
            friendAnnotationV.automatic = [location.automatic boolValue];
            
            OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
            friendAnnotationV.me = [location.belongsTo.topic isEqualToString:[delegate.settings theGeneralTopic]];
            
            [friendAnnotationV setNeedsDisplay];
            
            friendAnnotationV.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
            
            return friendAnnotationV;
        }
        return nil;
    }
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[Location class]]) {
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[[UIApplication sharedApplication] delegate];
        MKCircleRenderer *renderer = [[MKCircleRenderer alloc] initWithCircle:overlay];
        
        Location *location = (Location *)overlay;
        if ([location.region isKindOfClass:[CLCircularRegion class]]) {
            CLCircularRegion *circularRegion = (CLCircularRegion *)location.region;
            if ([circularRegion containsCoordinate:[delegate.manager location].coordinate]) {
                renderer.fillColor = [UIColor colorWithRed:1.0 green:0.5 blue:0.5 alpha:0.333];
            } else {
                renderer.fillColor = [UIColor colorWithRed:0.5 green:0.5 blue:1.0 alpha:0.333];
            }
        }
        return renderer;
        
    } else {
        return nil;
    }
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
#ifdef DEBUG
    NSLog(@"didSelectAnnotationView");
#endif
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
#ifdef DEBUG
    NSLog(@"calloutAccessoryControlTapped");
#endif
    [self performSegueWithIdentifier:@"showDetail:" sender:view];
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)performFetch
{
    if (self.frc) {
        if (self.frc.fetchRequest.predicate) {
#ifdef DEBUG
            NSLog(@"[%@ %@] fetching %@ with predicate: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), self.frc.fetchRequest.entityName, self.frc.fetchRequest.predicate);
#endif
        } else {
#ifdef DEBUG
            NSLog(@"[%@ %@] fetching all %@ (i.e., no predicate)", NSStringFromClass([self class]), NSStringFromSelector(_cmd), self.frc.fetchRequest.entityName);
#endif
        }
        NSError *error;
        [self.frc performFetch:&error];
        if (error) NSLog(@"[%@ %@] %@ (%@)", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [error localizedDescription], [error localizedFailureReason]);
    } else {
#ifdef DEBUG
        NSLog(@"[%@ %@] no NSFetchedResultsController (yet?)", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
#endif
    }
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;

    [self.mapView addAnnotations:[Location allValidLocationsInManagedObjectContext:[CoreData theManagedObjectContext]]];
    
    NSArray *overlays = [Location allWaypointsOfTopic:[delegate.settings theGeneralTopic]
                              inManagedObjectContext:[CoreData theManagedObjectContext]];

    [self.mapView addOverlays:overlays];
    for (Location *location in overlays) {
        if (location.region) {
#ifdef DEBUG
            NSLog(@"startMonitoringForRegion %@", location.region.identifier);
            for (CLRegion *region in delegate.manager.monitoredRegions) {
                NSLog(@"region %@", region.identifier);
            }
#endif
            [delegate.manager startMonitoringForRegion:location.region];
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
#ifdef DEBUG
            NSLog(@"[%@ %@] %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), oldfrc ? @"updated" : @"set");
#endif
            [self performFetch];
        } else {
#ifdef DEBUG
            NSLog(@"[%@ %@] reset to nil", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
#endif
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
                //
                break;
                
            case NSFetchedResultsChangeDelete:
                //
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
                if (coordinate.latitude != 0 || coordinate.longitude !=0) {
                    [self.mapView addAnnotation:location];
                }
                if ([location.belongsTo.topic isEqualToString:[delegate.settings theGeneralTopic]]) {
                    [self.mapView addOverlay:location];
                    if (location.region) {
#ifdef DEBUG
                        NSLog(@"startMonitoringForRegion %@", location.region.identifier);
                        for (CLRegion *region in delegate.manager.monitoredRegions) {
                            NSLog(@"region %@", region.identifier);
                        }
#endif
                        [delegate.manager startMonitoringForRegion:location.region];
                    }
                }
                break;
                
            case NSFetchedResultsChangeDelete:
                [self.mapView removeAnnotation:location];
                if ([location.belongsTo.topic isEqualToString:[delegate.settings theGeneralTopic]]) {
                    [self.mapView removeOverlay:location];
                    for (CLRegion *region in delegate.manager.monitoredRegions) {
                        if ([region.identifier isEqualToString:location.region.identifier]) {
#ifdef DEBUG
                            NSLog(@"stopMonitoringForRegion %@", region.identifier);
                            for (CLRegion *region in delegate.manager.monitoredRegions) {
                                NSLog(@"region %@", region.identifier);
                            }
#endif
                            [delegate.manager stopMonitoringForRegion:region];
                        }
                    }
                }
                break;
                
            case NSFetchedResultsChangeUpdate:
            case NSFetchedResultsChangeMove:
                [self.mapView removeAnnotation:location];
                if ([location.belongsTo.topic isEqualToString:[delegate.settings theGeneralTopic]]) {
                    [self.mapView removeOverlay:location];
                    [self.mapView addOverlay:location];
                }
                if (coordinate.latitude != 0 || coordinate.longitude !=0) {
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

@end
