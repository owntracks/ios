//
//  Location.h
//  OwnTracks
//
//  Created by Christoph Krey on 03.02.14.
//  Copyright (c) 2014 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Friend;

@interface Location : NSManagedObject

@property (nonatomic, retain) NSNumber * accuracy;
@property (nonatomic, retain) NSNumber * automatic;
@property (nonatomic, retain) NSNumber * justcreated;
@property (nonatomic, retain) NSNumber * latitude;
@property (nonatomic, retain) NSNumber * longitude;
@property (nonatomic, retain) NSString * placemark;
@property (nonatomic, retain) NSNumber * regionradius;
@property (nonatomic, retain) NSString * remark;
@property (nonatomic, retain) NSNumber * share;
@property (nonatomic, retain) NSDate * timestamp;
@property (nonatomic, retain) Friend *belongsTo;

@end
