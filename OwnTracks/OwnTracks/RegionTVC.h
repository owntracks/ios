//
//  RegionTVC.h
//  OwnTracks
//
//  Created by Christoph Krey on 01.10.13.
//  Copyright (c) 2013-2015 Christoph Krey. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Region+Create.h"

@interface RegionTVC : UITableViewController <UITextFieldDelegate>
@property (strong, nonatomic) Region *editRegion;

@end
