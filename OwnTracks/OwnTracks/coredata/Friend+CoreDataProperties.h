//
//  Friend+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 08.12.16.
//  Copyright © 2016 OwnTracks. All rights reserved.
//

#import "Friend+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface Friend (CoreDataProperties)

+ (NSFetchRequest<Friend *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSNumber *abRecordId;
@property (nullable, nonatomic, retain) NSData *cardImage;
@property (nullable, nonatomic, copy) NSString *cardName;
@property (nullable, nonatomic, copy) NSDate *lastLocation;
@property (nullable, nonatomic, copy) NSString *tid;
@property (nullable, nonatomic, copy) NSString *topic;
@property (nullable, nonatomic, retain) NSSet<Location *> *hasLocations;
@property (nullable, nonatomic, retain) NSSet<Region *> *hasRegions;
@property (nullable, nonatomic, retain) NSSet<Waypoint *> *hasWaypoints;
@property (nullable, nonatomic, retain) NSSet<Subscription *> *hasSubscriptions;

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

- (void)addHasSubscriptionsObject:(Subscription *)value;
- (void)removeHasSubscriptionsObject:(Subscription *)value;
- (void)addHasSubscriptions:(NSSet<Subscription *> *)values;
- (void)removeHasSubscriptions:(NSSet<Subscription *> *)values;

@end

NS_ASSUME_NONNULL_END
