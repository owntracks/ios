//
//  FriendTableViewCell.m
//  OwnTracks
//
//  Created by Christoph Krey on 30.06.15.
//  Copyright © 2015-2022  OwnTracks. All rights reserved.
//

#import "FriendTableViewCell.h"
#import "CoreData.h"

@implementation FriendTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)deferredReverseGeoCode:(Waypoint *)waypoint {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(reverseGeoCode:) withObject:waypoint afterDelay:1];
}

- (void)reverseGeoCode:(Waypoint *)waypoint {
    if (waypoint) {
        if (!waypoint.isDeleted) {
            if ([[NSUserDefaults standardUserDefaults] integerForKey:@"noRevgeo"] > 0) {
                [waypoint getReverseGeoCode];
            } else {
                waypoint.placemark = waypoint.defaultPlacemark;
                waypoint.belongsTo.topic = waypoint.belongsTo.topic;
                [CoreData.sharedInstance sync:waypoint.managedObjectContext];
            }
        }
    }
}

@end
