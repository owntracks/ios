//
//  Friend.h
//  OwnTracks
//
//  Created by Christoph Krey on 30.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Region, Waypoint;

@interface Friend : NSManagedObject

@property (nonatomic, retain) NSNumber * abRecordId;
@property (nonatomic, retain) NSData * cardImage;
@property (nonatomic, retain) NSString * cardName;
@property (nonatomic, retain) NSString * tid;
@property (nonatomic, retain) NSString * topic;
@property (nonatomic, retain) NSSet *hasRegions;
@property (nonatomic, retain) NSSet *hasWaypoints;
@end

@interface Friend (CoreDataGeneratedAccessors)

- (void)addHasRegionsObject:(Region *)value;
- (void)removeHasRegionsObject:(Region *)value;
- (void)addHasRegions:(NSSet *)values;
- (void)removeHasRegions:(NSSet *)values;

- (void)addHasWaypointsObject:(Waypoint *)value;
- (void)removeHasWaypointsObject:(Waypoint *)value;
- (void)addHasWaypoints:(NSSet *)values;
- (void)removeHasWaypoints:(NSSet *)values;

@end
