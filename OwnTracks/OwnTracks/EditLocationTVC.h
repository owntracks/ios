//
//  EditLocationTVC.h
//  OwnTracks
//
//  Created by Christoph Krey on 01.10.13.
//  Copyright (c) 2013-2015 Christoph Krey. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Location+Create.h"
#import <QRCodeReaderViewController.h>

@interface EditLocationTVC : UITableViewController <UITextFieldDelegate, QRCodeReaderDelegate>
@property (strong, nonatomic) Location *location;
@property (strong, nonatomic) MKMapView *mapView;

@end
