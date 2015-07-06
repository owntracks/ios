//
//  Waypoint.h
//  OwnTracks
//
//  Created by Christoph Krey on 30.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Friend;

@interface Waypoint : NSManagedObject

@property (nonatomic, retain) NSNumber * acc;
@property (nonatomic, retain) NSNumber * alt;
@property (nonatomic, retain) NSNumber * cog;
@property (nonatomic, retain) NSNumber * lat;
@property (nonatomic, retain) NSNumber * lon;
@property (nonatomic, retain) NSString * placemark;
@property (nonatomic, retain) NSString * trigger;
@property (nonatomic, retain) NSDate * tst;
@property (nonatomic, retain) NSNumber * vac;
@property (nonatomic, retain) NSNumber * vel;
@property (nonatomic, retain) Friend *belongsTo;

@end
