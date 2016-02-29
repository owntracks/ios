//
//  FriendTableViewCell.h
//  OwnTracks
//
//  Created by Christoph Krey on 30.06.15.
//  Copyright © 2015-2016 OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Waypoint+Create.h"

@interface FriendTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (weak, nonatomic) IBOutlet UILabel *timestamp;
- (void)deferredReverseGeoCode:(Waypoint *)waypoint;
- (void)reverseGeoCode:(Waypoint *)waypoint;
@property (weak, nonatomic) IBOutlet UILabel *name;
@property (weak, nonatomic) IBOutlet UILabel *address;

@end
