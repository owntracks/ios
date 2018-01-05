//
//  ViewController.h
//  OwnTracks
//
//  Created by Christoph Krey on 17.08.13.
//  Copyright © 2013-2018 Christoph Krey. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreData/CoreData.h>
#import <MapKit/MapKit.h>
#import "Connection.h"
#import "OwnTracksAppDelegate.h"

@interface ViewController : UIViewController <MKMapViewDelegate, NSFetchedResultsControllerDelegate>
@end
