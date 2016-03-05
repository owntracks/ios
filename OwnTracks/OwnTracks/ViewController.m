//
//  ViewController.m
//  OwnTracks
//
//  Created by Christoph Krey on 17.08.13.
//  Copyright © 2013-2016 Christoph Krey. All rights reserved.
//

#import "ViewController.h"
#import "StatusTVC.h"
#import "FriendAnnotationV.h"
#import "FriendsTVC.h"
#import "RegionsTVC.h"
#import "WaypointTVC.h"
#import "CoreData.h"
#import "Friend+Create.h"
#import "Region+Create.h"
#import "Waypoint.h"
#import "UIColor+WithName.h"
#import "LocationManager.h"
#import "OwnTracking.h"
#import "AlertView.h"
#import "ModeBarButtonItem.h"

#import <CocoaLumberjack/CocoaLumberjack.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@property (strong, nonatomic) NSFetchedResultsController *frcFriends;
@property (strong, nonatomic) NSFetchedResultsController *frcRegions;
@property (nonatomic) BOOL suspendAutomaticTrackingOfChangesInManagedObjectContext;

@end

@implementation ViewController
static const DDLogLevel ddLogLevel = DDLogLevelError;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.mapView.delegate = self;
    
    self.mapView.mapType = MKMapTypeStandard;
    self.mapView.showsUserLocation = TRUE;
    
    NSMutableArray *leftButtonItems = [self.navigationItem.leftBarButtonItems mutableCopy];
    [leftButtonItems addObject:[[MKUserTrackingBarButtonItem alloc] initWithMapView:self.mapView]];
    self.navigationItem.leftBarButtonItems = leftButtonItems;

    NSMutableArray *rightButtonItems = [self.navigationItem.rightBarButtonItems mutableCopy];
    [rightButtonItems insertObject:[[ModeBarButtonItem alloc] init] atIndex:0];
    self.navigationItem.rightBarButtonItems = rightButtonItems;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if ([CoreData theManagedObjectContext]) {
        if (!self.frcFriends) {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Friend"];
            request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"topic" ascending:TRUE]];
            self.frcFriends = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                  managedObjectContext:[CoreData theManagedObjectContext]
                                                                    sectionNameKeyPath:nil
                                                                             cacheName:nil];
            self.frcFriends.delegate = self;
        }
        if (!self.frcRegions) {
            [[LocationManager sharedInstance] resetRegions];
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Region"];
            request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:TRUE]];
            self.frcRegions = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                  managedObjectContext:[CoreData theManagedObjectContext]
                                                                    sectionNameKeyPath:nil
                                                                             cacheName:nil];
            self.frcRegions.delegate = self;
        }
    }
}

- (void)setCenter:(id<MKAnnotation>)annotation {
    CLLocationCoordinate2D coordinate = annotation.coordinate;
    [self.mapView setVisibleMapRect:[self centeredRect:coordinate] animated:YES];
    self.mapView.userTrackingMode = MKUserTrackingModeNone;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"showWaypointFromMap"]) {
        if ([segue.destinationViewController respondsToSelector:@selector(setWaypoint:)]) {
            MKAnnotationView *view = (MKAnnotationView *)sender;
            Friend *friend  = (Friend *)view.annotation;
            Waypoint *waypoint = [friend newestWaypoint];
            if (waypoint) {
                [segue.destinationViewController performSelector:@selector(setWaypoint:) withObject:waypoint];
            }
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

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    } else if ([annotation isKindOfClass:[Friend class]]) {
        Friend *friend = (Friend *)annotation;
        Waypoint *waypoint = [friend newestWaypoint];
        
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
        
        NSData *data = [friend image];
        UIImage *image = [UIImage imageWithData:data];
        friendAnnotationV.personImage = image;
        friendAnnotationV.tid = [friend getEffectiveTid];
        friendAnnotationV.speed = [waypoint.vel doubleValue];
        friendAnnotationV.course = [waypoint.cog doubleValue];
        friendAnnotationV.me = [friend.topic isEqualToString:[Settings theGeneralTopic]];
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
                pAV.pinColor = MKPinAnnotationColorGreen;
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

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[Friend class]]) {
        Friend *friend = (Friend *)overlay;
        MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithPolyline:friend.polyLine];
        [renderer setLineWidth:3];
        [renderer setStrokeColor:[UIColor colorWithName:@"track" defaultColor:[UIColor redColor]]];
        return renderer;
        
    } else if ([overlay isKindOfClass:[Region class]]) {
        Region *region = (Region *)overlay;
        MKCircleRenderer *renderer = [[MKCircleRenderer alloc] initWithCircle:region.circle];
        if ([[LocationManager sharedInstance] insideCircularRegion:region.name]) {
            renderer.fillColor = [UIColor colorWithName:@"inside" defaultColor:[UIColor redColor]];
        } else {
            renderer.fillColor = [UIColor colorWithName:@"outside" defaultColor:[UIColor blueColor]];
        }
        return renderer;
        
    } else {
        return nil;
    }
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
    if (control == view.rightCalloutAccessoryView) {
        [self performSegueWithIdentifier:@"showWaypointFromMap" sender:view];
    } else if (control == view.leftCalloutAccessoryView) {
        Friend *friend = (Friend *)view.annotation;
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[[UIApplication sharedApplication] delegate];
        [delegate requestLocationFromFriend:friend];
        [AlertView alert:NSLocalizedString(@"Location",
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

- (void)performFetch:(NSFetchedResultsController *)frc
{
    if (frc) {
        NSError *error;
        [frc performFetch:&error];
        if (error) DDLogError(@"[%@ %@] %@ (%@)", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [error localizedDescription], [error localizedFailureReason]);
    }
}

- (void)setFrcFriends:(NSFetchedResultsController *)newfrc
{
    NSFetchedResultsController *oldfrc = _frcFriends;
    if (newfrc != oldfrc) {
        _frcFriends = newfrc;
        newfrc.delegate = self;
        if (newfrc) {
            [self performFetch:newfrc];
        }
    }
    [self.mapView addAnnotations:[Friend allFriendsInManagedObjectContext:[CoreData theManagedObjectContext]]];
}

- (void)setFrcRegions:(NSFetchedResultsController *)newfrc
{
    NSFetchedResultsController *oldfrc = _frcRegions;
    if (newfrc != oldfrc) {
        _frcRegions = newfrc;
        newfrc.delegate = self;
        if (newfrc) {
            [self performFetch:newfrc];
        }
    }
    
    Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopic]
                            inManagedObjectContext:[CoreData theManagedObjectContext]];
    [self.mapView addOverlays:[friend.hasRegions
                               sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name"
                                                                                           ascending:YES]]]];
    for (Region *region in friend.hasRegions) {
        if (region.CLregion) {
            [[LocationManager sharedInstance] startRegion:region.CLregion];
        }
    }
    [self.mapView addAnnotations:[friend.hasRegions
                                  sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name"
                                                                                              ascending:YES]]]];
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
        if ([anObject isKindOfClass:[Friend class]]) {
            Friend *friend = (Friend *)anObject;
            Waypoint *waypoint = [friend newestWaypoint];
            switch(type)
            {
                case NSFetchedResultsChangeInsert:
                    if (waypoint && [waypoint.lat doubleValue] != 0.0 && [waypoint.lon doubleValue] != 0.0) {
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
                    if (waypoint && [waypoint.lat doubleValue] != 0.0 && [waypoint.lon doubleValue] != 0.0) {
                        [self.mapView addAnnotation:friend];
                    }
                    break;
            }
            
        } else if ([anObject isKindOfClass:[Region class]]) {
            Region *region = (Region *)anObject;
            switch(type)
            {
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
    [delegate sendNow];
    [AlertView alert:NSLocalizedString(@"Location",
                                       @"Header of an alert message regarding a location")
             message:NSLocalizedString(@"publish queued on user request",
                                       @"content of an alert message regarding user publish")
        dismissAfter:1
     ];
}

- (IBAction)longPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        
        Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopic] inManagedObjectContext:[CoreData theManagedObjectContext]];
        [[OwnTracking sharedInstance] addRegionFor:friend
                                              name:[NSString stringWithFormat:@"Center-%d",
                                                    (int)[[NSDate date] timeIntervalSince1970]]
                                              uuid:nil
                                             major:0
                                             minor:0
                                             share:NO
                                            radius:0
                                               lat:self.mapView.centerCoordinate.latitude
                                               lon:self.mapView.centerCoordinate.longitude
                                           context:[CoreData theManagedObjectContext]];
        [AlertView alert:NSLocalizedString(@"Region",
                                           @"Header of an alert message regarding circular region")
                 message:NSLocalizedString(@"created at center of map",
                                           @"content of an alert message regarding circular region")
            dismissAfter:1
         ];
    }
}

@end
