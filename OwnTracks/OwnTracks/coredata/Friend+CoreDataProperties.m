//
//  Friend+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 05.05.18.
//  Copyright © 2018 OwnTracks. All rights reserved.
//
//

#import "Friend+CoreDataProperties.h"

@implementation Friend (CoreDataProperties)

+ (NSFetchRequest<Friend *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"Friend"];
}

@dynamic cardImage;
@dynamic cardName;
@dynamic lastLocation;
@dynamic tid;
@dynamic topic;
@dynamic contactId;
@dynamic hasLocations;
@dynamic hasRegions;
@dynamic hasSubscriptions;
@dynamic hasWaypoints;

@end
