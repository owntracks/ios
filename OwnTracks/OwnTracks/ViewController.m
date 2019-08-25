//
//  ViewController.m
//  OwnTracks
//
//  Created by Christoph Krey on 17.08.13.
//  Copyright © 2013 -2019 Christoph Krey. All rights reserved.
//

#import "ViewController.h"
#import "StatusTVC.h"
#import "FriendAnnotationV.h"
#import "FriendsTVC.h"
#import "RegionsTVC.h"
#import "WaypointTVC.h"
#import "CoreData.h"
#import "Friend+CoreDataClass.h"
#import "Region+CoreDataClass.h"
#import "Waypoint+CoreDataClass.h"
#import "UIColor+WithName.h"
#import "LocationManager.h"
#import "OwnTracking.h"

#import <CocoaLumberjack/CocoaLumberjack.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@property (strong, nonatomic) NSFetchedResultsController *frcFriends;
@property (strong, nonatomic) NSFetchedResultsController *frcRegions;
@property (nonatomic) BOOL suspendAutomaticTrackingOfChangesInManagedObjectContext;
@property (strong, nonatomic) MKUserTrackingBarButtonItem *userTracker;

@property (nonatomic) BOOL initialCenter;
@property (strong, nonatomic) UISegmentedControl *modes;
@property (strong, nonatomic) MKUserTrackingButton *trackingButton;

@end


@implementation ViewController
static const DDLogLevel ddLogLevel = DDLogLevelWarning;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.mapView.delegate = self;
    self.mapView.mapType = MKMapTypeStandard;
    self.mapView.showsUserLocation = TRUE;
    // we don't show the scale as it would conflict with the new mode display
    self.mapView.showsScale = FALSE;

    DDLogInfo(@"[ViewController] viewDidLoad mapView region %g %g %g %g",
              self.mapView.region.center.latitude,
              self.mapView.region.center.longitude,
              self.mapView.region.span.latitudeDelta,
              self.mapView.region.span.longitudeDelta);

    self.trackingButton = [MKUserTrackingButton userTrackingButtonWithMapView:self.mapView];
    self.trackingButton.translatesAutoresizingMaskIntoConstraints = false;
    [self.view addSubview:self.trackingButton];

    NSLayoutConstraint *bottomTracking = [NSLayoutConstraint
                                          constraintWithItem:self.trackingButton
                                          attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
                                          toItem:self.mapView
                                          attribute:NSLayoutAttributeBottom
                                          multiplier:1
                                          constant:-10];
    NSLayoutConstraint *trailingTraccking = [NSLayoutConstraint
                                             constraintWithItem:self.trackingButton
                                             attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual
                                             toItem:self.mapView
                                             attribute:NSLayoutAttributeTrailing
                                             multiplier:1
                                             constant:-10];

    [NSLayoutConstraint activateConstraints:@[bottomTracking, trailingTraccking]];

    self.modes = [[UISegmentedControl alloc]
                  initWithItems:@[NSLocalizedString(@"Quiet", @"Quiet"),
                                  NSLocalizedString(@"Manual", @"Manual"),
                                  NSLocalizedString(@"Significant", @"Significant"),
                                  NSLocalizedString(@"Move", @"Move")
                                  ]];
    self.modes.apportionsSegmentWidthsByContent = YES;
    self.modes.translatesAutoresizingMaskIntoConstraints = false;
    self.modes.backgroundColor = [UIColor colorWithRed:1.0
                                                 green:1.0
                                                  blue:1.0
                                                 alpha:0.5];
    [self.modes addTarget:self
                   action:@selector(modesChanged:)
         forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.modes];

    NSLayoutConstraint *top = [NSLayoutConstraint
                               constraintWithItem:self.modes
                               attribute:NSLayoutAttributeTop
                               relatedBy:NSLayoutRelationEqual
                               toItem:self.mapView
                               attribute:NSLayoutAttributeTopMargin
                               multiplier:1
                               constant:10];
    NSLayoutConstraint *leading = [NSLayoutConstraint
                                   constraintWithItem:self.modes
                                   attribute:NSLayoutAttributeLeading
                                   relatedBy:NSLayoutRelationEqual
                                   toItem:self.mapView
                                   attribute:NSLayoutAttributeLeading
                                   multiplier:1
                                   constant:10];

    [NSLayoutConstraint activateConstraints:@[top, leading]];

    [self setButtonMove];

    [[LocationManager sharedInstance] addObserver:self
                                       forKeyPath:@"monitoring"
                                          options:NSKeyValueObservingOptionNew
                                          context:nil];

    [[NSNotificationCenter defaultCenter]
     addObserverForName:@"reload"
     object:nil
     queue:[NSOperationQueue mainQueue]
     usingBlock:^(NSNotification *note){
         [self performSelectorOnMainThread:@selector(reloaded)
                                withObject:nil
                             waitUntilDone:NO];
     }];
}

- (IBAction)modesChanged:(UISegmentedControl *)segmentedControl {
    NSInteger monitoring;
    switch (segmentedControl.selectedSegmentIndex) {
        case 3:
            monitoring = LocationMonitoringMove;
            break;
        case 2:
            monitoring = LocationMonitoringSignificant;
            break;
        case 1:
            monitoring = LocationMonitoringManual;
            break;
        case 0:
        default:
            monitoring = LocationMonitoringQuiet;
            break;
    }
    if (monitoring != [LocationManager sharedInstance].monitoring) {
        [LocationManager sharedInstance].monitoring = monitoring;
        [Settings setInt:[LocationManager sharedInstance].monitoring forKey:@"monitoring_preference"
                   inMOC:CoreData.sharedInstance.mainMOC];
        [self setButtonMove];
    }
}

- (void)setButtonMove {
    switch ([LocationManager sharedInstance].monitoring) {
        case LocationMonitoringMove:
            self.modes.selectedSegmentIndex = 3;
            break;
        case LocationMonitoringSignificant:
            self.modes.selectedSegmentIndex = 2;
            break;
        case LocationMonitoringManual:
            self.modes.selectedSegmentIndex = 1;
            break;
        case LocationMonitoringQuiet:
        default:
            self.modes.selectedSegmentIndex = 0;
            break;
    }
}


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"monitoring"]) {
        [self setButtonMove];
    }
}

- (void)reloaded {
    self.frcFriends = nil;
    self.frcRegions = nil;
    [self setButtonMove];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    while (!self.frcFriends) {
        //
    }
    while (!self.frcRegions) {
        //
    }
}

- (void)setCenter:(id<MKAnnotation>)annotation {
    CLLocationCoordinate2D coordinate = annotation.coordinate;
    if (CLLocationCoordinate2DIsValid(coordinate)) {
        [self.mapView setVisibleMapRect:[self centeredRect:coordinate] animated:YES];
        self.mapView.userTrackingMode = MKUserTrackingModeNone;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"showWaypointFromMap"]) {
        if ([segue.destinationViewController respondsToSelector:@selector(setWaypoint:)]) {
            MKAnnotationView *view = (MKAnnotationView *)sender;
            Friend *friend  = (Friend *)view.annotation;
            Waypoint *waypoint = friend.newestWaypoint;
            if (waypoint) {
                [segue.destinationViewController performSelector:@selector(setWaypoint:) withObject:waypoint];
            }
        }
    }
}

#pragma centeredRect

#define INITIAL_RADIUS 600.0

- (MKMapRect)centeredRect:(CLLocationCoordinate2D)center {
    MKMapRect rect;
    
    double r = INITIAL_RADIUS * MKMapPointsPerMeterAtLatitude(center.latitude);
    
    rect.origin = MKMapPointForCoordinate(center);
    rect.origin.x -= r;
    rect.origin.y -= r;
    rect.size.width = 2*r;
    rect.size.height = 2*r;
    
    return rect;
}

#pragma MKMapViewDelegate

#define REUSE_ID_BEACON @"Annotation_beacon"
#define REUSE_ID_PICTURE @"Annotation_picture"
#define REUSE_ID_OTHER @"Annotation_other"

// This is a hack because the FriendAnnotationView did not erase it's callout after being dragged
- (void)mapView:(MKMapView *)mapView
 annotationView:(MKAnnotationView *)view
didChangeDragState:(MKAnnotationViewDragState)newState
   fromOldState:(MKAnnotationViewDragState)oldState {
    DDLogVerbose(@"didChangeDragState %lu", (unsigned long)newState);
    if (newState == MKAnnotationViewDragStateNone) {
        NSArray *annotations = mapView.annotations;
        [mapView removeAnnotations:annotations];
        [mapView addAnnotations:annotations];
    }
}

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {
    if (!self.initialCenter) {
        self.initialCenter = TRUE;
        [self.mapView setCenterCoordinate:userLocation.location.coordinate animated:TRUE];
    }

#ifdef GEOHASHING
    Neighbors *neighbors = [GeoHashing sharedInstance].neighbors;
    [self.mapView removeOverlay:neighbors.center];
    [self.mapView removeOverlay:neighbors.west];
    [self.mapView removeOverlay:neighbors.northWest];
    [self.mapView removeOverlay:neighbors.north];
    [self.mapView removeOverlay:neighbors.northEast];
    [self.mapView removeOverlay:neighbors.east];
    [self.mapView removeOverlay:neighbors.southEast];
    [self.mapView removeOverlay:neighbors.south];
    [self.mapView removeOverlay:neighbors.southWest];

    CLLocation *location = [[CLLocation alloc] initWithLatitude:userLocation.coordinate.latitude
                                                      longitude:userLocation.coordinate.longitude];
    [[GeoHashing sharedInstance] newLocation:location];

    neighbors = [GeoHashing sharedInstance].neighbors;
    [self.mapView addOverlay:neighbors.center];
    [self.mapView addOverlay:neighbors.west];
    [self.mapView addOverlay:neighbors.northWest];
    [self.mapView addOverlay:neighbors.north];
    [self.mapView addOverlay:neighbors.northEast];
    [self.mapView addOverlay:neighbors.east];
    [self.mapView addOverlay:neighbors.southEast];
    [self.mapView addOverlay:neighbors.south];
    [self.mapView addOverlay:neighbors.southWest];
#endif
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView
            viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    } else if ([annotation isKindOfClass:[Friend class]]) {
        Friend *friend = (Friend *)annotation;
        Waypoint *waypoint = friend.newestWaypoint;

        MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_PICTURE];
        FriendAnnotationV *friendAnnotationV;
        if (annotationView) {
            friendAnnotationV = (FriendAnnotationV *)annotationView;
        } else {
            friendAnnotationV = [[FriendAnnotationV alloc] initWithAnnotation:friend reuseIdentifier:REUSE_ID_PICTURE];
        }
        UIButton *refreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [refreshButton setImage:[UIImage imageNamed:@"Refresh"] forState:UIControlStateNormal];
        [refreshButton sizeToFit];
        annotationView.leftCalloutAccessoryView = refreshButton;
        friendAnnotationV.canShowCallout = YES;
        friendAnnotationV.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];

        NSData *data = friend.image;
        UIImage *image = [UIImage imageWithData:data];
        friendAnnotationV.personImage = image;
        friendAnnotationV.tid = friend.effectiveTid;
        friendAnnotationV.speed = (waypoint.vel).doubleValue;
        friendAnnotationV.course = (waypoint.cog).doubleValue;
        friendAnnotationV.me = [friend.topic isEqualToString:[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC]];
        [friendAnnotationV setNeedsDisplay];

        return friendAnnotationV;

    } else if ([annotation isKindOfClass:[Region class]]) {
        Region *region = (Region *)annotation;
        if ([region.CLregion isKindOfClass:[CLBeaconRegion class]]) {
            MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_BEACON];
            if (!annotationView) {
                annotationView = [[MKAnnotationView alloc] initWithAnnotation:region reuseIdentifier:REUSE_ID_BEACON];
            }
            annotationView.draggable = true;
            annotationView.canShowCallout = YES;

            if ([[LocationManager sharedInstance] insideBeaconRegion:region.name]) {
                annotationView.image = [UIImage imageNamed:@"iBeaconHot"];
            } else {
                annotationView.image = [UIImage imageNamed:@"iBeaconCold"];
            }
            [annotationView setNeedsDisplay];
            return annotationView;
        } else {
            MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_OTHER];
            if (!annotationView) {
                MKPinAnnotationView *pAV;
                pAV = [[MKPinAnnotationView alloc] initWithAnnotation:region reuseIdentifier:REUSE_ID_OTHER];
                pAV.pinTintColor = [UIColor greenColor];
                annotationView = pAV;
            }
            annotationView.draggable = true;
            annotationView.canShowCallout = YES;
            [annotationView setNeedsDisplay];
            return annotationView;

        }
    }
    return nil;
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    if ([overlay isKindOfClass:[Friend class]]) {
        Friend *friend = (Friend *)overlay;
        MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithPolyline:friend.polyLine];
        renderer.lineWidth = 3;
        renderer.strokeColor = [UIColor colorWithName:@"track" defaultColor:[UIColor redColor]];
        return renderer;
        
    } else if ([overlay isKindOfClass:[Region class]]) {
        Region *region = (Region *)overlay;
        MKCircleRenderer *renderer = [[MKCircleRenderer alloc] initWithCircle:region.circle];
        if ([region.name hasPrefix:@"+"]) {
            renderer.fillColor = [UIColor colorWithName:@"follow" defaultColor:[UIColor greenColor]];
        } else {
            if ([[LocationManager sharedInstance] insideCircularRegion:region.name]) {
                renderer.fillColor = [UIColor colorWithName:@"inside" defaultColor:[UIColor redColor]];
            } else {
                renderer.fillColor = [UIColor colorWithName:@"outside" defaultColor:[UIColor blueColor]];
            }
        }
        return renderer;
    } else {
        return nil;
    }
}

- (void)mapView:(MKMapView *)mapView
 annotationView:(MKAnnotationView *)view
calloutAccessoryControlTapped:(UIControl *)control {
    if (control == view.rightCalloutAccessoryView) {
        [self performSegueWithIdentifier:@"showWaypointFromMap" sender:view];
    } else if (control == view.leftCalloutAccessoryView) {
        Friend *friend = (Friend *)view.annotation;
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [delegate requestLocationFromFriend:friend];
        [delegate.navigationController alert:NSLocalizedString(@"Location",
                                                               @"Header of an alert message regarding a location")
                                     message:NSLocalizedString(@"requested from friend",
                                                               @"content of an alert message regarding publish request")
                                dismissAfter:1
         ];
    }
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
    if  ([view.annotation isKindOfClass:[Friend class]]) {
        Friend *friend = (Friend *)view.annotation;
        [mapView addOverlay:friend];
    }
}

- (void)mapView:(MKMapView *)mapView didDeselectAnnotationView:(MKAnnotationView *)view {
    if  ([view.annotation isKindOfClass:[Friend class]]) {
        Friend *friend = (Friend *)view.annotation;
        [mapView removeOverlay:friend];
    }
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)performFetch:(NSFetchedResultsController *)frc {
    if (frc) {
        NSError *error;
        [frc performFetch:&error];
        if (error) DDLogError(@"[%@ %@] %@ (%@)", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [error localizedDescription], [error localizedFailureReason]);
    }
}

- (NSFetchedResultsController *)frcFriends {
    if (!_frcFriends) {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Friend"];

        int ignoreStaleLocations = [Settings intForKey:@"ignorestalelocations_preference"
                                                 inMOC:CoreData.sharedInstance.mainMOC];
        if (ignoreStaleLocations) {
            NSTimeInterval stale = -ignoreStaleLocations * 24.0 * 3600.0;
            request.predicate = [NSPredicate predicateWithFormat:@"lastLocation > %@",
                                 [NSDate dateWithTimeIntervalSinceNow:stale]];
        }

        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"topic" ascending:TRUE]];
        _frcFriends = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                          managedObjectContext:CoreData.sharedInstance.mainMOC
                                                            sectionNameKeyPath:nil
                                                                     cacheName:nil];
        _frcFriends.delegate = self;
        [self performFetch:_frcFriends];
        [self.mapView addAnnotations:_frcFriends.fetchedObjects];
    }
    return _frcFriends;
}

- (NSFetchedResultsController *)frcRegions {
    if (!_frcRegions) {
        [[LocationManager sharedInstance] resetRegions];
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Region"];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:TRUE]];
        _frcRegions = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                          managedObjectContext:CoreData.sharedInstance.mainMOC
                                                            sectionNameKeyPath:nil
                                                                     cacheName:nil];
        _frcRegions.delegate = self;
        [self performFetch:_frcRegions];
        Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC]
                          inManagedObjectContext:CoreData.sharedInstance.mainMOC];
        [self.mapView addOverlays:[friend.hasRegions
                                   sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name"
                                                                                               ascending:YES]]]];
        for (Region *region in friend.hasRegions) {
            if (region.CLregion) {
                [[LocationManager sharedInstance] startRegion:region.CLregion];
            }
        }
        [self.mapView addAnnotations:[friend.hasRegions sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name"
                                                                                                                    ascending:YES]]]];
    }
    return _frcRegions;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    //
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type {
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
      newIndexPath:(NSIndexPath *)newIndexPath {
    if (!self.suspendAutomaticTrackingOfChangesInManagedObjectContext) {
        NSDictionary *d = @{@"object": anObject, @"type": @(type)};
        [self performSelectorOnMainThread:@selector(p:) withObject:d waitUntilDone:FALSE];
    }
}

- (void)p:(NSDictionary *)d {
    id anObject = d[@"object"];
    NSNumber *type = d[@"type"];
    if ([anObject isKindOfClass:[Friend class]]) {
        Friend *friend = (Friend *)anObject;
        Waypoint *waypoint = friend.newestWaypoint;
        switch(type.intValue) {
            case NSFetchedResultsChangeInsert:
                if (waypoint && (waypoint.lat).doubleValue != 0.0 && (waypoint.lon).doubleValue != 0.0) {
                    [self.mapView addAnnotation:friend];
                }
                break;

            case NSFetchedResultsChangeDelete:
                [self.mapView removeOverlay:friend];
                [self.mapView removeAnnotation:friend];
                break;

            case NSFetchedResultsChangeUpdate:
            case NSFetchedResultsChangeMove:
                [self.mapView removeOverlay:friend];
                [self.mapView removeAnnotation:friend];
                if (waypoint && (waypoint.lat).doubleValue != 0.0 && (waypoint.lon).doubleValue != 0.0) {
                    [self.mapView addAnnotation:friend];
                }
                break;
        }

    } else if ([anObject isKindOfClass:[Region class]]) {
        Region *region = (Region *)anObject;
        switch(type.intValue) {
            case NSFetchedResultsChangeInsert:
                [self.mapView addAnnotation:region];
                [self.mapView addOverlay:region];
                break;

            case NSFetchedResultsChangeDelete:
                [self.mapView removeOverlay:region];
                [self.mapView removeAnnotation:region];
                break;

            case NSFetchedResultsChangeUpdate:
            case NSFetchedResultsChangeMove:
                [self.mapView removeOverlay:region];
                [self.mapView removeAnnotation:region];
                [self.mapView addAnnotation:region];
                [self.mapView addOverlay:region];

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

- (IBAction)actionPressed:(UIBarButtonItem *)sender {
    [self sendNow];
}

- (IBAction)longDoublePress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        [self sendNow];
    }
}

- (void)sendNow {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;

    if (![Settings validIdsInMOC:CoreData.sharedInstance.mainMOC]) {
        NSString *message = NSLocalizedString(@"To publish your location userID and deviceID must be set",
                                              @"Warning displayed if necessary settings are missing");

        [delegate.navigationController alert:@"Settings" message:message];
    } else {
        [delegate sendNow];
        [delegate.navigationController alert:
         NSLocalizedString(@"Location",
                           @"Header of an alert message regarding a location")
                                     message:
         NSLocalizedString(@"publish queued on user request",
                           @"content of an alert message regarding user publish")
                                dismissAfter:1
         ];
    }
}

- (IBAction)longPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {

        Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] inManagedObjectContext:CoreData.sharedInstance.mainMOC];
        [[OwnTracking sharedInstance] addRegionFor:friend
                                              name:[NSString stringWithFormat:@"Center-%d",
                                                    (int)[NSDate date].timeIntervalSince1970]
                                              uuid:nil
                                             major:0
                                             minor:0
                                            radius:0
                                               lat:self.mapView.centerCoordinate.latitude
                                               lon:self.mapView.centerCoordinate.longitude
                                           context:CoreData.sharedInstance.mainMOC];
        [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];

        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [delegate.navigationController alert:NSLocalizedString(@"Region",
                                                               @"Header of an alert message regarding circular region")
                                     message:NSLocalizedString(@"created at center of map",
                                                               @"content of an alert message regarding circular region")
                                dismissAfter:1
         ];
    }
}
- (IBAction)buttonMovePressed:(UIBarButtonItem *)sender {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;

    switch ([LocationManager sharedInstance].monitoring) {
        case LocationMonitoringMove:
            [LocationManager sharedInstance].monitoring = LocationMonitoringSignificant;
            [delegate.navigationController alert:NSLocalizedString(@"Mode",
                                                                   @"Header of an alert message regarding monitoring mode")
                                         message:NSLocalizedString(@"significant changes mode enabled",
                                                                   @"content of an alert message regarding monitoring mode")
                                    dismissAfter:1
             ];
            break;

        case LocationMonitoringQuiet:
            [LocationManager sharedInstance].monitoring = LocationMonitoringMove;
            [delegate.navigationController alert:NSLocalizedString(@"Mode",
                                                                   @"Header of an alert message regarding monitoring mode")
                                         message:NSLocalizedString(@"move mode enabled",
                                                                   @"content of an alert message regarding monitoring mode")
                                    dismissAfter:1
             ];
            break;

        case LocationMonitoringManual:
            [LocationManager sharedInstance].monitoring = LocationMonitoringQuiet;
            [delegate.navigationController alert:NSLocalizedString(@"Mode",
                                                                   @"Header of an alert message regarding monitoring mode")
                                         message:NSLocalizedString(@"quiet mode enabled",
                                                                   @"content of an alert message regarding monitoring mode")
                                    dismissAfter:1
             ];
            break;

        case LocationMonitoringSignificant:
        default:
            [LocationManager sharedInstance].monitoring = LocationMonitoringManual;
            [delegate.navigationController alert:NSLocalizedString(@"Mode",
                                                                   @"Header of an alert message regarding monitoring mode")
                                         message:NSLocalizedString(@"manual mode enabled",
                                                                   @"content of an alert message regarding monitoring mode")
                                    dismissAfter:1
             ];

            break;
    }
    [Settings setInt:(int)[LocationManager sharedInstance].monitoring
              forKey:@"monitoring_preference"
               inMOC:CoreData.sharedInstance.mainMOC];
    [self setButtonMove];

}

@end
