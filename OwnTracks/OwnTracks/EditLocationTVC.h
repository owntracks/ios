//
//  EditLocationTVC.h
//  OwnTracks
//
//  Created by Christoph Krey on 01.10.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Location+Create.h"

@interface EditLocationTVC : UITableViewController
@property (strong, nonatomic) Location *location;
@property (strong, nonatomic) MKMapView *mapView;

@end
