//
//  Friend+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 08.12.16.
//  Copyright © 2016-2017 OwnTracks. All rights reserved.
//

#import "Friend+CoreDataProperties.h"

@implementation Friend (CoreDataProperties)

+ (NSFetchRequest<Friend *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"Friend"];
}

@dynamic abRecordId;
@dynamic cardImage;
@dynamic cardName;
@dynamic lastLocation;
@dynamic tid;
@dynamic topic;
@dynamic hasLocations;
@dynamic hasRegions;
@dynamic hasWaypoints;
@dynamic hasSubscriptions;

@end
