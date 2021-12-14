//
//  Waypoint+CoreDataClass.h
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
//  Copyright © 2018-2021 OwnTracks. All rights reserved.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Friend;

NS_ASSUME_NONNULL_BEGIN

@interface Waypoint : NSManagedObject

- (void) getReverseGeoCode;
- (CLLocationDistance) getDistanceFrom:(CLLocation *)location;
+ (NSString *)distanceText:(CLLocationDistance)distance;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * _Nonnull shortCoordinateText;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * _Nonnull coordinateText;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * _Nonnull timestampText;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * _Nonnull createdAtText;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDate * _Nonnull effectiveTimestamp;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * _Nonnull infoText;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * _Nonnull batteryLevelText;

@end

NS_ASSUME_NONNULL_END

#import "Waypoint+CoreDataProperties.h"
