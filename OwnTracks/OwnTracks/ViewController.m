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
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *connectionButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *locationButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *beaconButton;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIProgressView *progress;

@property (nonatomic) BOOL beaconOn;

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
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [self showState:delegate.connection.state];
    
    [self monitoringButtonImage];
    [self beaconButtonImage];
    
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

#pragma UI actions

/*
 * setCenter is the unwind action from the friends submenues
 */
- (IBAction)setCenter:(UIStoryboardSegue *)segue {
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(0, 0);
    
    if ([segue.sourceViewController isKindOfClass:[FriendTVC class]]) {
        FriendTVC *friendTVC = (FriendTVC *)segue.sourceViewController;
        coordinate = friendTVC.selectedLocation.coordinate;
    }
    if ([segue.sourceViewController isKindOfClass:[LocationTVC class]]) {
        LocationTVC *locationTVC = (LocationTVC *)segue.sourceViewController;
        coordinate = locationTVC.selectedLocation.coordinate;
    }
    
    [self.mapView setVisibleMapRect:[self centeredRect:coordinate] animated:YES];
    self.mapView.userTrackingMode = MKUserTrackingModeNone;
}

#define ACTION_MONITORING @"Location Monitoring Mode"
#define ACTION_MAP @"Map Modes"
#define ACTION_CONNECTION @"Connection"
#define ACTION_BEACON @"iBeacon"

- (IBAction)location:(UIBarButtonItem *)sender
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:ACTION_MONITORING
                                                             delegate:self
                                                    cancelButtonTitle:@"Cancel"
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
                                                    cancelButtonTitle:@"Cancel"
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
                self.mapView.userTrackingMode = MKUserTrackingModeNone;
                break;
            case 1:
                self.mapView.userTrackingMode = MKUserTrackingModeFollow;
                break;
            case 2:
                self.mapView.userTrackingMode = MKUserTrackingModeFollowWithHeading;
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
                
                self.mapView.userTrackingMode = MKUserTrackingModeNone;
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
    }
}

- (void)monitoringButtonImage
{
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[[UIApplication sharedApplication] delegate];

    switch (delegate.monitoring) {
        case 2:
            self.locationButton.image = [UIImage imageNamed:@"Move.png"];
            break;
        case 1:
            self.locationButton.image = [UIImage imageNamed:@"LocationOn.png"];
            break;
        case 0:
        default:
            self.locationButton.image = [UIImage imageNamed:@"LocationOff.png"];
            break;
    }
}

- (IBAction)connection:(UIBarButtonItem *)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:ACTION_CONNECTION
                                                             delegate:self
                                                    cancelButtonTitle:@"Cancel"
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:
                                  @"(Re-)Connect",
                                  @"Disconnect",
                                  nil];
    [actionSheet showFromBarButtonItem:sender animated:YES];
}

- (IBAction)beaconPressed:(UIBarButtonItem *)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:ACTION_BEACON
                                                             delegate:self
                                                    cancelButtonTitle:@"Cancel"
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:
                                  @"Start Ranging",
                                  @"Stop Ranging",
                                  nil];
    [actionSheet showFromBarButtonItem:sender animated:YES];
}

- (void)beaconButtonImage
{
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[[UIApplication sharedApplication] delegate];

    if (delegate.ranging) {
        self.beaconButton.image = [UIImage imageNamed:@"iBeaconOn.png"];
    } else {
        self.beaconButton.image = [UIImage imageNamed:@"iBeacon.png"];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    /*
     * segue for connection status view
     */
    
    if ([segue.identifier isEqualToString:@"setConnection:"]) {
        if ([segue.destinationViewController respondsToSelector:@selector(setConnection:)]) {
            OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
            [segue.destinationViewController performSelector:@selector(setConnection:) withObject:delegate.connection];
        }
    }
    
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
        self.beaconButton.image = [UIImage imageNamed:@"iBeaconOn.png"];
    } else {
        self.beaconButton.image = [UIImage imageNamed:@"iBeacon.png"];
    }
}

#pragma ConnectionDelegate

- (void)showState:(NSInteger)state
{
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[[UIApplication sharedApplication] delegate];
    switch (delegate.connection.state) {
        case state_connected:
            self.connectionButton.tintColor = [UIColor colorWithRed:0.0 green:190.0/255 blue:0.0 alpha:1.0];
            break;
        case state_error:
            self.connectionButton.tintColor = [UIColor colorWithRed:190.0/255.0 green:0.0 blue:0.0 alpha:1.0];
            break;
        case state_connecting:
        case state_closing:
            self.connectionButton.tintColor = [UIColor colorWithRed:190.0/255.0 green:190.0/255.0 blue:0.0 alpha:1.0];
            break;
        case state_starting:
        default:
            self.connectionButton.tintColor = [UIColor colorWithRed:0.0 green:0.0 blue:190.0/255.0 alpha:1.0];
            break;
    }
}

- (void)totalBuffered:(NSUInteger)count
{
    if (count) {
        self.progress.hidden = FALSE;
        [self.progress setProgress:1.0 / (count + 1) animated:YES];
    } else {
        self.progress.hidden = TRUE;
    }
}

#pragma MKMapViewDelegate

#define REUSE_ID_SELF @"Annotation_self"
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
            OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
            
            if ([location.belongsTo.topic isEqualToString:[delegate.settings theGeneralTopic]]) {
                MKPinAnnotationView *pinAnnotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_SELF];
                if (!pinAnnotationView) {
                    pinAnnotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:REUSE_ID_SELF];
                    pinAnnotationView.canShowCallout = YES;
                }
                if ([location.automatic boolValue]) {
                    pinAnnotationView.pinColor = MKPinAnnotationColorRed;
                } else {
                    pinAnnotationView.pinColor = MKPinAnnotationColorPurple;
                }
                
                if (!location.justcreated || [location.justcreated boolValue]) {
                    pinAnnotationView.animatesDrop = YES;
                    location.justcreated = @(FALSE);
                }
                pinAnnotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
                
                return pinAnnotationView;
            } else {
                Friend *friend = location.belongsTo;
                if (friend && [friend image]) {
                    UIColor *color;
                    
                    if ([location.automatic boolValue]) {
                        if ([location.timestamp compare:[NSDate dateWithTimeIntervalSinceNow:OLD_TIME]] == NSOrderedAscending) {
                            color = [UIColor redColor];
                        } else {
                            color = [UIColor greenColor];
                        }
                    } else {
                        color = [UIColor blueColor];
                    }
                    
                    MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_PICTURE];
                    FriendAnnotationV *friendAnnotationV;
                    if (annotationView) {
                        friendAnnotationV = (FriendAnnotationV *)annotationView;
                    } else {
                        friendAnnotationV = [[FriendAnnotationV alloc] initWithAnnotation:annotation reuseIdentifier:REUSE_ID_PICTURE];
                        friendAnnotationV.canShowCallout = YES;
                    }
                    friendAnnotationV.personImage = [UIImage imageWithData:[friend image]];
                    friendAnnotationV.circleColor = color;
                    [friendAnnotationV setNeedsDisplay];
                    
                    friendAnnotationV.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
                    
                    return friendAnnotationV;
                } else {
                    MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_OTHER];
                    if (annotationView) {
                        return annotationView;
                    } else {
                        MKPinAnnotationView *pinAnnotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:REUSE_ID_OTHER];
                        pinAnnotationView.pinColor = MKPinAnnotationColorGreen;
                        pinAnnotationView.canShowCallout = YES;
                        
                        pinAnnotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
                        
                        return pinAnnotationView;
                    }
                }
            }
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

#pragma action sheet

- (void)disappearingActionSheet:(NSString *)title button:(UIBarButtonItem *)button
{
#ifdef DEBUG
    NSLog(@"App disappearingActionSheet %@", title);
#endif
    
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:title
                                                                 delegate:nil
                                                        cancelButtonTitle:nil
                                                   destructiveButtonTitle:nil
                                                        otherButtonTitles:nil];
        actionSheet.delegate = self;
        [actionSheet showFromBarButtonItem:button animated:YES];
        [self performSelector:@selector(dismissActionSheetAfterDelay:) withObject:actionSheet afterDelay:0.75];
    }
}

- (void)dismissActionSheetAfterDelay:(UIActionSheet *)actionSheet
{
    [actionSheet dismissWithClickedButtonIndex:0 animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // this is a hack because otherwise the progress bar is grey after the actionsheet was displayed
    float progress = self.progress.progress;
    [self.progress setProgress:progress*0.9 animated:YES];
    [self.progress setProgress:progress animated:YES];
}

@end
