//
//  RegionTVC.h
//  OwnTracks
//
//  Created by Christoph Krey on 01.10.13.
//  Copyright © 2013-2022  Christoph Krey. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Region+CoreDataClass.h"

@interface RegionTVC : UITableViewController <UITextFieldDelegate>
@property (strong, nonatomic) Region *editRegion;

@end
