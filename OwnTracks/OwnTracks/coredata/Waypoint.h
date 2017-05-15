//
//  Waypoint.h
//  OwnTracks
//
//  Created by Christoph Krey on 28.09.15.
//  Copyright © 2015-2017 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Friend;

NS_ASSUME_NONNULL_BEGIN

@interface Waypoint : NSManagedObject

- (void) getReverseGeoCode;
- (NSString *)coordinateText;
- (NSString *)timestampText;
- (NSString *)infoText;

@end

NS_ASSUME_NONNULL_END

#import "Waypoint+CoreDataProperties.h"
