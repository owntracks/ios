//
//  Friend+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 26.07.19.
//  Copyright © 2019-2025 OwnTracks. All rights reserved.
//
//

#import "Friend+CoreDataProperties.h"

@implementation Friend (CoreDataProperties)

+ (NSFetchRequest<Friend *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"Friend"];
}

@dynamic cardImage;
@dynamic cardName;
@dynamic contactId;
@dynamic lastLocation;
@dynamic tid;
@dynamic topic;
@dynamic hasRegions;
@dynamic hasWaypoints;

@end
