//
//  ViewController.m
//  OwnTracks
//
//  Created by Christoph Krey on 17.08.13.
//  Copyright © 2013-2024  Christoph Krey. All rights reserved.
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
#import "LocationManager.h"
#import "OwnTracking.h"

#import "OwnTracksChangeMonitoringIntent.h"

#import <CocoaLumberjack/CocoaLumberjack.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *accuracyButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *actionButton;

@property (strong, nonatomic) NSFetchedResultsController *frcFriends;
@property (strong, nonatomic) NSFetchedResultsController *frcRegions;
@property (strong, nonatomic) NSFetchedResultsController *frcWaypoints;
@property (nonatomic) BOOL suspendAutomaticTrackingOfChangesInManagedObjectContext;
@property (strong, nonatomic) MKUserTrackingBarButtonItem *userTracker;

@property (nonatomic) BOOL initialCenter;
@property (strong, nonatomic) UISegmentedControl *modes;
@property (strong, nonatomic) UISegmentedControl *mapMode;
@property (strong, nonatomic) MKUserTrackingButton *trackingButton;
@property (strong, nonatomic) MKScaleView *scaleView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *askForMapButton;
@property (nonatomic) BOOL warning;
@end


@implementation ViewController
static const DDLogLevel ddLogLevel = DDLogLevelInfo;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.warning = FALSE;
    self.mapView.delegate = self;
    self.mapView.mapType = MKMapTypeStandard;
    
    self.mapView.showsScale = FALSE;
    
#if TARGET_OS_MACCATALYST
    self.mapView.showsCompass = TRUE;
#endif
    
    DDLogInfo(@"[ViewController] viewDidLoad mapView region %g %g %g %g",
              self.mapView.region.center.latitude,
              self.mapView.region.center.longitude,
              self.mapView.region.span.latitudeDelta,
              self.mapView.region.span.longitudeDelta);
    
    [self setupModes];
    [self updateMoveButton];
    [self setupMapMode];
    [self setupScaleView];
    
    [[LocationManager sharedInstance] addObserver:self
                                       forKeyPath:@"monitoring"
                                          options:NSKeyValueObservingOptionNew
                                          context:nil];

    [self.mapView addObserver:self
                   forKeyPath:@"userLocation"
                      options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                      context:nil];
    [self.mapView addObserver:self
                   forKeyPath:@"userLocation.location"
                      options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
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
    
    [self noMap];
}

- (void)setupModes {
    self.modes = [[UISegmentedControl alloc]
                  initWithItems:@[NSLocalizedString(@"Quiet", @"Quiet"),
                                  NSLocalizedString(@"Manual", @"Manual"),
                                  NSLocalizedString(@"Significant", @"Significant"),
                                  NSLocalizedString(@"Move", @"Move")
                                  ]];
    self.modes.apportionsSegmentWidthsByContent = YES;
    self.modes.translatesAutoresizingMaskIntoConstraints = false;
    self.modes.backgroundColor = [UIColor colorNamed:@"modesColor"];
    [self.modes addTarget:self
                   action:@selector(modesChanged:)
         forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.modes];

    NSLayoutConstraint *topModes = [NSLayoutConstraint
                               constraintWithItem:self.modes
                               attribute:NSLayoutAttributeTop
                               relatedBy:NSLayoutRelationEqual
                               toItem:self.mapView
                               attribute:NSLayoutAttributeTop
                               multiplier:1
                               constant:10];
    NSLayoutConstraint *leadingModes = [NSLayoutConstraint
                                   constraintWithItem:self.modes
                                   attribute:NSLayoutAttributeLeading
                                   relatedBy:NSLayoutRelationEqual
                                   toItem:self.mapView
                                   attribute:NSLayoutAttributeLeading
                                   multiplier:1
                                   constant:10];
    
    [NSLayoutConstraint activateConstraints:@[topModes, leadingModes]];
}

- (void)setupMapMode {
    self.mapMode = [[UISegmentedControl alloc]
                  initWithItems:@[NSLocalizedString(@"Std", @"Std"),
                                  NSLocalizedString(@"Sat", @"Sat"),
                                  NSLocalizedString(@"Hyb", @"Hyb"),
                                  NSLocalizedString(@"Fly", @"Fly"),
                                  NSLocalizedString(@"HybFly", @"HybFly"),
                                  NSLocalizedString(@"Mute", @"Mute")
                                  ]];
    self.mapMode.apportionsSegmentWidthsByContent = YES;
    self.mapMode.translatesAutoresizingMaskIntoConstraints = false;
    self.mapMode.backgroundColor = [UIColor colorNamed:@"modesColor"];
    [self.mapMode addTarget:self
                   action:@selector(mapModeChanged:)
         forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.mapMode];
    self.mapMode.selectedSegmentIndex =
    [[NSUserDefaults standardUserDefaults] integerForKey:@"mapMode"];
    [self mapModeChanged:self.mapMode];

    NSLayoutConstraint *bottomMapMode = [NSLayoutConstraint
                               constraintWithItem:self.mapMode
                               attribute:NSLayoutAttributeBottom
                               relatedBy:NSLayoutRelationEqual
                               toItem:self.mapView
                               attribute:NSLayoutAttributeBottomMargin
                               multiplier:1
                               constant:-30];
    NSLayoutConstraint *leadingMapMode = [NSLayoutConstraint
                                   constraintWithItem:self.mapMode
                                   attribute:NSLayoutAttributeLeading
                                   relatedBy:NSLayoutRelationEqual
                                   toItem:self.mapView
                                   attribute:NSLayoutAttributeLeading
                                   multiplier:1
                                   constant:10];

    [NSLayoutConstraint activateConstraints:@[bottomMapMode, leadingMapMode]];
}

- (void)setupScaleView {
    self.scaleView = [MKScaleView scaleViewWithMapView:self.mapView];
    self.scaleView.translatesAutoresizingMaskIntoConstraints = false;
    [self.view addSubview:self.scaleView];
    
    NSLayoutConstraint *bottomScale = [NSLayoutConstraint constraintWithItem:self.scaleView
                                                                   attribute:NSLayoutAttributeBottom
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:self.mapView
                                                                   attribute:NSLayoutAttributeBottomMargin
                                                                  multiplier:1
                                                                    constant:-10];
    NSLayoutConstraint *leadingScale = [NSLayoutConstraint constraintWithItem:self.scaleView
                                                                    attribute:NSLayoutAttributeCenterXWithinMargins
                                                                    relatedBy:NSLayoutRelationEqual
                                                                       toItem:self.mapView
                                                                    attribute:NSLayoutAttributeCenterXWithinMargins
                                                                   multiplier:1
                                                                     constant:0];
    
    [NSLayoutConstraint activateConstraints:@[bottomScale, leadingScale]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"monitoring"]) {
        [self updateMoveButton];
    }
    if ([keyPath isEqualToString:@"userLocation"] ||
        [keyPath isEqualToString:@"userLocation.location"]) {
        [self updateAccuracyButton];
    }
}

- (IBAction)modesChanged:(UISegmentedControl *)segmentedControl {
    int monitoring;
    OwnTracksEnum intentMonitoring;
    switch (segmentedControl.selectedSegmentIndex) {
        case 3:
            monitoring = LocationMonitoringMove;
            intentMonitoring = OwnTracksEnumMove;
            break;
        case 2:
            monitoring = LocationMonitoringSignificant;
            intentMonitoring = OwnTracksEnumSignificant;
            break;
        case 1:
            monitoring = LocationMonitoringManual;
            intentMonitoring = OwnTracksEnumManual;
            break;
        case 0:
        default:
            monitoring = LocationMonitoringQuiet;
            intentMonitoring = OwnTracksEnumQuiet;
            break;
    }
    if (monitoring != [LocationManager sharedInstance].monitoring) {
        [LocationManager sharedInstance].monitoring = monitoring;
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
        [Settings setInt:(int)[LocationManager sharedInstance].monitoring forKey:@"monitoring_preference"
                   inMOC:CoreData.sharedInstance.mainMOC];
        [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
        [self updateMoveButton];
    }
}

- (void)updateMoveButton {
    BOOL locked = [Settings theLockedInMOC:CoreData.sharedInstance.mainMOC];
    self.modes.enabled = !locked;

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

    for (NSInteger index = 0; index < self.modes.numberOfSegments; index++) {
        NSString *title = [self.modes titleForSegmentAtIndex:index];
        if ([title hasSuffix:@"!"]) {
            title = [title substringToIndex:title.length-1];
        }
        [self.modes setTitle:title forSegmentAtIndex:index];

    }
    
    NSInteger index = self.modes.selectedSegmentIndex;
    NSString *title = [self.modes titleForSegmentAtIndex:index];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"downgraded"]) {
        if (![title hasSuffix:@"!"]) {
            title = [title stringByAppendingString:@"!"];
        }
    }
    [self.modes setTitle:title forSegmentAtIndex:index];

}

- (void)updateAccuracyButton {
    CLLocation *location = self.mapView.userLocation.location;
    self.accuracyButton.title = [Waypoint CLLocationAccuracyText:location];
    self.actionButton.enabled = ![self.accuracyButton.title isEqualToString:@"-"];
}

- (void)reloaded {
    self.frcFriends = nil;
    self.frcRegions = nil;
    self.frcWaypoints = nil;
    [self updateMoveButton];
}

- (NSInteger)noMap {
    BOOL locked = [Settings theLockedInMOC:CoreData.sharedInstance.mainMOC];
    self.askForMapButton.enabled = !locked;


    NSInteger noMap =
    [[NSUserDefaults standardUserDefaults] integerForKey:@"noMap"];
    
    if (noMap > 0) {
        self.mapView.showsUserLocation = TRUE;
        self.mapView.zoomEnabled = TRUE;
        self.mapView.scrollEnabled = TRUE;
        self.mapView.pitchEnabled = TRUE;
        self.mapView.rotateEnabled = TRUE;
#if TARGET_OS_MACCATALYST
        self.mapView.showsZoomControls = TRUE;
        if (@available(macCatalyst 14.0, *)) {
            self.mapView.showsPitchControl = TRUE;
        } else {
            // Fallback on earlier versions
        }
#endif
        if (!self.trackingButton) {
            self.trackingButton = [MKUserTrackingButton userTrackingButtonWithMapView:self.mapView];
            self.trackingButton.translatesAutoresizingMaskIntoConstraints = false;
            [self.view addSubview:self.trackingButton];
            
            NSLayoutConstraint *topTracking = [NSLayoutConstraint
                                                  constraintWithItem:self.trackingButton
                                                  attribute:NSLayoutAttributeTop
                                                  relatedBy:NSLayoutRelationEqual
                                                  toItem:self.modes
                                                  attribute:NSLayoutAttributeBottom
                                                  multiplier:1
                                                  constant:8];
            NSLayoutConstraint *leadingTracking = [NSLayoutConstraint
                                                   constraintWithItem:self.trackingButton
                                                   attribute:NSLayoutAttributeLeading
                                                   relatedBy:NSLayoutRelationEqual
                                                   toItem:self.mapView
                                                   attribute:NSLayoutAttributeLeading
                                                   multiplier:1
                                                   constant:10];
            
            [NSLayoutConstraint activateConstraints:@[topTracking, leadingTracking]];
        }
    } else {
        self.mapView.showsUserLocation = FALSE;
        self.mapView.zoomEnabled = FALSE;
        self.mapView.scrollEnabled = FALSE;
        self.mapView.pitchEnabled = FALSE;
        self.mapView.rotateEnabled = FALSE;
#if TARGET_OS_MACCATALYST
        self.mapView.showsZoomControls = FALSE;
        if (@available(macCatalyst 14.0, *)) {
            self.mapView.showsPitchControl = FALSE;
        } else {
            // Fallback on earlier versions
        }
#endif
        if (self.trackingButton) {
            [self.trackingButton removeFromSuperview];
            self.trackingButton = nil;
        }
    }


    return noMap;
}
- (IBAction)askForMap:(UIBarButtonItem *)sender {
    UIAlertController *ac =
    [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Map Interaction",
                                                                  @"Title map interaction")
                                        message:NSLocalizedString(@"Do you want the map to allow interaction? If you choose yes, the map provider may analyze your tile requests",
                                                                  @"Message map interaction")
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *yes = [UIAlertAction
                          actionWithTitle:NSLocalizedString(@"Yes",
                                                            @"Yes button title")
                          
                          style:UIAlertActionStyleDefault
                          handler:^(UIAlertAction * action) {
        [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"noMap"];
        [self noMap];
        [self askForRevgeo:nil];
    }];
    UIAlertAction *no = [UIAlertAction
                         actionWithTitle:NSLocalizedString(@"No",
                                                           @"No button title")
                         
                         style:UIAlertActionStyleDestructive
                         handler:^(UIAlertAction * action) {
        [[NSUserDefaults standardUserDefaults] setInteger:-1 forKey:@"noMap"];
        [self noMap];
        [self askForRevgeo:nil];
    }];
    
    [ac addAction:yes];
    [ac addAction:no];
    if (self.presentedViewController) {
        [self performSelector:@selector(askForMap:) withObject:sender afterDelay:1];
    } else {
        [self presentViewController:ac animated:TRUE completion:nil];
    }
}

- (IBAction)askForRevgeo:(UIBarButtonItem *)sender {
    UIAlertController *ac =
    [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Reverse Geocoding Address Resolution",
                                                                  @"Title Revgeo")
                                        message:NSLocalizedString(@"Do you want to resolve adresses? If you choose yes, the geocoding provider may analyze your requests",
                                                                  @"Message Revgeo")
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *yes = [UIAlertAction
                          actionWithTitle:NSLocalizedString(@"Yes",
                                                            @"Yes button title")
                          
                          style:UIAlertActionStyleDefault
                          handler:^(UIAlertAction * action) {
        [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"noRevgeo"];
    }];
    UIAlertAction *no = [UIAlertAction
                         actionWithTitle:NSLocalizedString(@"No",
                                                           @"No button title")
                         
                         style:UIAlertActionStyleDestructive
                         handler:^(UIAlertAction * action) {
        [[NSUserDefaults standardUserDefaults] setInteger:-1 forKey:@"noRevgeo"];
    }];
    
    [ac addAction:yes];
    [ac addAction:no];
    if (self.presentedViewController) {
        [self performSelector:@selector(askForMap:) withObject:sender afterDelay:1];
    } else {
        [self presentViewController:ac animated:TRUE completion:nil];
    }
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    while (!self.frcFriends) {
        //
    }
    while (!self.frcRegions) {
        //
    }
    while (!self.frcWaypoints) {
        //
    }
    
    if (!self.warning &&
        ![Setting existsSettingWithKey:@"mode" inMOC:CoreData.sharedInstance.mainMOC]) {
        self.warning = TRUE;
        OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [ad.navigationController alert:
         NSLocalizedString(@"Setup",
                           @"Header of an alert message regarding missing setup")
                               message:
         NSLocalizedString(@"You need to setup your own OwnTracks server and edit your configuration for full privacy protection. Detailed info on https://owntracks.org/booklet",
                           @"Text explaining the Setup")
        ];
    }
    
    if (self.noMap == 0) {
        [self askForMap:nil];
    }
}

- (void)setCenter:(id<MKAnnotation>)annotation {
    if (self.noMap > 0) {
        CLLocationCoordinate2D coordinate = annotation.coordinate;
        if (CLLocationCoordinate2DIsValid(coordinate)) {
            [self.mapView setVisibleMapRect:[self centeredRect:coordinate] animated:YES];
            self.mapView.userTrackingMode = MKUserTrackingModeNone;
        }
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

- (IBAction)mapModeChanged:(UISegmentedControl *)sender {
    switch (sender.selectedSegmentIndex) {
        case 5:
            self.mapView.mapType = MKMapTypeMutedStandard;
            break;
        case 4:
            self.mapView.mapType = MKMapTypeHybridFlyover;
            break;
        case 3:
            self.mapView.mapType = MKMapTypeSatelliteFlyover;
            break;
        case 2:
            self.mapView.mapType = MKMapTypeHybrid;
            break;
        case 1:
            self.mapView.mapType = MKMapTypeSatellite;
            break;
        case 0:
        default:
            self.mapView.mapType = MKMapTypeStandard;
            break;
    }
    [self.mapView setNeedsLayout];
    [[NSUserDefaults standardUserDefaults] setInteger:self.mapView.mapType
                                               forKey:@"mapMode"];

}

#pragma MKMapViewDelegate

#define REUSE_ID_BEACON @"Annotation_beacon"
#define REUSE_ID_PICTURE @"Annotation_picture"
#define REUSE_ID_POI @"Annotation_poi"
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
        friendAnnotationV.displayPriority = MKFeatureDisplayPriorityRequired;
        friendAnnotationV.zPriority = MKFeatureDisplayPriorityDefaultHigh;
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

    } else if ([annotation isKindOfClass:[Waypoint class]]) {
        Waypoint *waypoint = (Waypoint *)annotation;
        MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_POI];
        MKMarkerAnnotationView *mAV;
        if (!annotationView) {
            mAV = [[MKMarkerAnnotationView alloc] initWithAnnotation:waypoint reuseIdentifier:REUSE_ID_POI];
        } else {
            mAV = (MKMarkerAnnotationView *)annotationView;
        }
        mAV.displayPriority = MKFeatureDisplayPriorityRequired;
        annotationView = mAV;
        [annotationView setNeedsDisplay];
        return annotationView;
    } else if ([annotation isKindOfClass:[Region class]]) {
        Region *region = (Region *)annotation;
        if ([region.CLregion isKindOfClass:[CLBeaconRegion class]]) {
            MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_BEACON];
#if TRUE
            MKMarkerAnnotationView *mAV;
            if (!annotationView) {
                mAV = [[MKMarkerAnnotationView alloc] initWithAnnotation:region reuseIdentifier:REUSE_ID_BEACON];
            } else {
                mAV = (MKMarkerAnnotationView *)annotationView;
            }
            mAV.displayPriority = MKFeatureDisplayPriorityRequired;
            if ([[LocationManager sharedInstance] insideBeaconRegion:region.name]) {
                mAV.markerTintColor = [UIColor colorNamed:@"beaconHotColor"];
                mAV.glyphImage = [UIImage imageNamed:@"iBeaconHot"];
            } else {
                mAV.markerTintColor = [UIColor colorNamed:@"beaconColdColor"];
                mAV.glyphImage = [UIImage imageNamed:@"iBeaconCold"];
            }
            annotationView = mAV;
#else
            if (!annotationView) {
                annotationView = [[MKAnnotationView alloc] initWithAnnotation:region reuseIdentifier:REUSE_ID_BEACON];
            }
            if ([[LocationManager sharedInstance] insideBeaconRegion:region.name]) {
                annotationView.image = [UIImage imageNamed:@"iBeaconHot"];
            } else {
                annotationView.image = [UIImage imageNamed:@"iBeaconCold"];
            }
#endif
            annotationView.draggable = true;
            annotationView.canShowCallout = YES;
            [annotationView setNeedsDisplay];
            return annotationView;
        } else {
            if (region.CLregion.isFollow) {
                return nil;
            }
            MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_OTHER];
#if TRUE
            MKMarkerAnnotationView *mAV;
            if (!annotationView) {
                mAV = [[MKMarkerAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:REUSE_ID_OTHER];
            } else {
                mAV = (MKMarkerAnnotationView *)annotationView;
            }
            mAV.displayPriority = MKFeatureDisplayPriorityRequired;
            mAV.markerTintColor = [UIColor colorNamed:@"pinColor"];
            annotationView = mAV;
#else
            MKPinAnnotationView *pAV;
            if (!annotationView) {
                pAV = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:REUSE_ID_OTHER];
            } else {
                pAV = (MKPinAnnotationView *)annotationView;
            }
            pAV.pinTintColor = [UIColor colorNamed:@"pinColor"];
            annotationView = pAV;
#endif
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
        renderer.strokeColor = [UIColor colorNamed:@"trackColor"];
        return renderer;
        
    } else if ([overlay isKindOfClass:[Region class]]) {
        Region *region = (Region *)overlay;
        if (region.CLregion && [region.CLregion isKindOfClass:[CLCircularRegion class]]) {
            MKCircleRenderer *renderer = [[MKCircleRenderer alloc] initWithCircle:region.circle];
            if (region.CLregion.isFollow) {
                renderer.fillColor = [UIColor colorNamed:@"followColor"];
            } else {
                if ([[LocationManager sharedInstance] insideCircularRegion:region.name]) {
                    renderer.fillColor = [UIColor colorNamed:@"insideColor"];
                } else {
                    renderer.fillColor = [UIColor colorNamed:@"outsideColor"];
                }
            }
            return renderer;
        } else {
            return nil;
        }
    } else {
        return nil;
    }
}

- (void)mapView:(MKMapView *)mapView
 annotationView:(MKAnnotationView *)view
calloutAccessoryControlTapped:(UIControl *)control {
    if (control == view.rightCalloutAccessoryView) {
        [self performSegueWithIdentifier:@"showWaypointFromMap" sender:view];
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

        double ignoreStaleLocations = [Settings doubleForKey:@"ignorestalelocations_preference"
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

- (NSFetchedResultsController *)frcWaypoints {
    if (!_frcWaypoints) {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Waypoint"];
        request.predicate = [NSPredicate predicateWithFormat:@"poi <> NULL"];

        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"tst" ascending:TRUE]];
        _frcWaypoints = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                            managedObjectContext:CoreData.sharedInstance.mainMOC
                                                              sectionNameKeyPath:nil
                                                                       cacheName:nil];
        _frcWaypoints.delegate = self;
        [self performFetch:_frcWaypoints];
        [self.mapView addAnnotations:_frcWaypoints.fetchedObjects];
    }
    return _frcWaypoints;
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
    } else if ([anObject isKindOfClass:[Waypoint class]]) {
        Waypoint *waypoint = (Waypoint *)anObject;
        switch(type.intValue) {
            case NSFetchedResultsChangeInsert:
                [self.mapView addAnnotation:waypoint];
                break;

            case NSFetchedResultsChangeDelete:
                [self.mapView removeAnnotation:waypoint];
                break;

            case NSFetchedResultsChangeUpdate:
            case NSFetchedResultsChangeMove:
                [self.mapView removeAnnotation:waypoint];
                [self.mapView addAnnotation:waypoint];

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
    UIAlertController *ac = [UIAlertController
                             alertControllerWithTitle:NSLocalizedString(@"Choose action", @"Choose action title")
                             message:nil
                             preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *sendNow = [UIAlertAction actionWithTitle:NSLocalizedString(@"Send location now",
                                                                              @"Send location now button")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
        [self sendNow:nil];
    }];
    UIAlertAction *setPoi = [UIAlertAction actionWithTitle:NSLocalizedString(@"Set POI",
                                                                             @"Set POI button")
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
        [self setPOI:nil];

    }];
    UIAlertAction *setTag = [UIAlertAction actionWithTitle:NSLocalizedString(@"Set tag",
                                                                             @"Set tag button")
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
        [self setTag:nil];
        
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",
                                                                             @"Cancel button title")
                                                     style:UIAlertActionStyleCancel
                                                   handler:^(UIAlertAction * _Nonnull action) {
        //
    }];
    [ac addAction:sendNow];
    [ac addAction:setPoi];
    [ac addAction:setTag];
    [ac addAction:cancel];
    [self presentViewController:ac
                       animated:TRUE
                     completion:^{
        //
    }];
}

- (void)sendNow:(nullable NSString *)poi {
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    BOOL validIds = [Settings validIdsInMOC:CoreData.sharedInstance.mainMOC];
    int ignoreInaccurateLocations = [Settings intForKey:@"ignoreinaccuratelocations_preference"
                                                      inMOC:CoreData.sharedInstance.mainMOC];
    CLLocation *location = self.mapView.userLocation.location;

    DDLogVerbose(@"[ViewController] sendNow %dm %d %@ %@",
                 ignoreInaccurateLocations, validIds, location, poi);

    if (!validIds) {
        NSString *message = NSLocalizedString(@"To publish your location userID and deviceID must be set",
                                              @"Warning displayed if necessary settings are missing");

        [ad.navigationController alert:@"Settings" message:message];
        return;
    }

    if (!location ||
        !CLLocationCoordinate2DIsValid(location.coordinate) ||
        (location.coordinate.latitude == 0.0 &&
         location.coordinate.longitude == 0.0)
        ) {
        [ad.navigationController alert:
         NSLocalizedString(@"Location",
                           @"Header of an alert message regarding a location")
                                     message:
         NSLocalizedString(@"No location available",
                           @"Warning displayed if not location available")
         ];
        return;
    }

    if (ignoreInaccurateLocations != 0 && location.horizontalAccuracy > ignoreInaccurateLocations) {
        [ad.navigationController alert:
         NSLocalizedString(@"Location",
                           @"Header of an alert message regarding a location")
                                     message:
         NSLocalizedString(@"Inaccurate or old location information",
                           @"Warning displayed if location is inaccurate or old")
         ];
        return;
    }

    if ([ad sendNow:location withPOI:poi]) {
        [ad.navigationController alert:
         NSLocalizedString(@"Location",
                           @"Header of an alert message regarding a location")
                                     message:
         NSLocalizedString(@"publish queued on user request",
                           @"content of an alert message regarding user publish")
                                dismissAfter:1
         ];
    } else {
        [ad.navigationController alert:
         NSLocalizedString(@"Location",
                           @"Header of an alert message regarding a location")
                                     message:
         NSLocalizedString(@"publish queued on user request",
                           @"content of an alert message regarding user publish")];
    }
}

- (IBAction)longPress:(UILongPressGestureRecognizer *)sender {
    if ([Settings theLockedInMOC:CoreData.sharedInstance.mainMOC]) {
        return;
    }

    if (sender.state == UIGestureRecognizerStateBegan) {
        Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] inManagedObjectContext:CoreData.sharedInstance.mainMOC];
        NSString *rid = Region.newRid;
        [[OwnTracking sharedInstance] addRegionFor:rid
                                            friend:friend
                                              name:[NSString stringWithFormat:@"Center-%@",
                                                    rid]
                                               tst:[NSDate date]
                                              uuid:nil
                                             major:0
                                             minor:0
                                            radius:0
                                               lat:self.mapView.centerCoordinate.latitude
                                               lon:self.mapView.centerCoordinate.longitude];
        [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];

        OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [ad.navigationController alert:
             NSLocalizedString(@"Region",
                               @"Header of an alert message regarding circular region")
                               message:
             NSLocalizedString(@"created at center of map",
                               @"content of an alert message regarding circular region")
                          dismissAfter:1
        ];
    }
}

- (IBAction)setPOI:(UIBarButtonItem *)sender {
    UIAlertController *ac = [UIAlertController
                             alertControllerWithTitle:NSLocalizedString(@"Set POI", @"Set POI title")
                             message:nil
                             preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *send = [UIAlertAction actionWithTitle:NSLocalizedString(@"Send",
                                                                           @"Send button title")
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        [self sendNow:ac.textFields[0].text];
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",
                                                                             @"Cancel button title")
                                                     style:UIAlertActionStyleCancel
                                                   handler:^(UIAlertAction * _Nonnull action) {
        //
    }];
    [ac addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = nil;
    }];
    [ac addAction:send];
    [ac addAction:cancel];
    [self presentViewController:ac
                       animated:TRUE
                     completion:^{
        //
    }];
}

- (IBAction)setTag:(UIBarButtonItem *)sender {
    UIAlertController *ac = [UIAlertController
                             alertControllerWithTitle:NSLocalizedString(@"Set Tag", @"Set Tag title")
                             message:nil
                             preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *send = [UIAlertAction actionWithTitle:NSLocalizedString(@"Send",
                                                                           @"Send button title")
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        if (!ac.textFields[0].text.length) {
            [[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"tag"];
        } else {
            [[NSUserDefaults standardUserDefaults] setObject:ac.textFields[0].text forKey:@"tag"];
        }
        [self sendNow:nil];
    }];
    UIAlertAction *remove = [UIAlertAction actionWithTitle:NSLocalizedString(@"Remove",
                                                                             @"Remove button title")
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"tag"];

    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",
                                                                             @"Cancel button title")
                                                     style:UIAlertActionStyleCancel
                                                   handler:^(UIAlertAction * _Nonnull action) {
        //
    }];
    [ac addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"tag"];
    }];
    [ac addAction:send];
    [ac addAction:remove];
    [ac addAction:cancel];
    [self presentViewController:ac
                       animated:TRUE
                     completion:^{
        //
    }];

}

@end
