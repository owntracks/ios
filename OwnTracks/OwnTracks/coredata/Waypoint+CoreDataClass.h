//
//  Waypoint+CoreDataClass.h
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
//  Copyright © 2018-2020 OwnTracks. All rights reserved.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Friend;

NS_ASSUME_NONNULL_BEGIN

@interface Waypoint : NSManagedObject

- (void) getReverseGeoCode;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * _Nonnull shortCoordinateText;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * _Nonnull coordinateText;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * _Nonnull timestampText;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * _Nonnull infoText;

@end

NS_ASSUME_NONNULL_END

#import "Waypoint+CoreDataProperties.h"
