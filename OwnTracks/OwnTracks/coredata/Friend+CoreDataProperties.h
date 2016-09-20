//
//  Friend+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 10.09.16.
//  Copyright © 2016 OwnTracks. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Friend.h"

NS_ASSUME_NONNULL_BEGIN

@interface Friend (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *abRecordId;
@property (nullable, nonatomic, retain) NSData *cardImage;
@property (nullable, nonatomic, retain) NSString *cardName;
@property (nullable, nonatomic, retain) NSString *tid;
@property (nullable, nonatomic, retain) NSString *topic;
@property (nullable, nonatomic, retain) NSDate *lastLocation;
@property (nullable, nonatomic, retain) NSSet<Location *> *hasLocations;
@property (nullable, nonatomic, retain) NSSet<Region *> *hasRegions;
@property (nullable, nonatomic, retain) NSSet<Waypoint *> *hasWaypoints;

@end

@interface Friend (CoreDataGeneratedAccessors)

- (void)addHasLocationsObject:(Location *)value;
- (void)removeHasLocationsObject:(Location *)value;
- (void)addHasLocations:(NSSet<Location *> *)values;
- (void)removeHasLocations:(NSSet<Location *> *)values;

- (void)addHasRegionsObject:(Region *)value;
- (void)removeHasRegionsObject:(Region *)value;
- (void)addHasRegions:(NSSet<Region *> *)values;
- (void)removeHasRegions:(NSSet<Region *> *)values;

- (void)addHasWaypointsObject:(Waypoint *)value;
- (void)removeHasWaypointsObject:(Waypoint *)value;
- (void)addHasWaypoints:(NSSet<Waypoint *> *)values;
- (void)removeHasWaypoints:(NSSet<Waypoint *> *)values;

@end

NS_ASSUME_NONNULL_END
