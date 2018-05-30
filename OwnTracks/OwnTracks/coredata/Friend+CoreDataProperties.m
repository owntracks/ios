//
//  Friend+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
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
@dynamic contactId;
@dynamic lastLocation;
@dynamic tid;
@dynamic topic;
@dynamic hasRegions;
@dynamic hasSubscriptions;
@dynamic hasWaypoints;

@end
