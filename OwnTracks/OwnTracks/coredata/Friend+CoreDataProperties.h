//
//  Friend+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 26.07.19.
//  Copyright © 2019-2021 OwnTracks. All rights reserved.
//
//

#import "Friend+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface Friend (CoreDataProperties)

+ (NSFetchRequest<Friend *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *cardImage;
@property (nullable, nonatomic, copy) NSString *cardName;
@property (nullable, nonatomic, copy) NSString *contactId;
@property (nullable, nonatomic, copy) NSDate *lastLocation;
@property (nullable, nonatomic, copy) NSString *tid;
@property (nullable, nonatomic, copy) NSString *topic;
@property (nullable, nonatomic, retain) NSSet<Region *> *hasRegions;
@property (nullable, nonatomic, retain) NSSet<Waypoint *> *hasWaypoints;

@end

@interface Friend (CoreDataGeneratedAccessors)

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
