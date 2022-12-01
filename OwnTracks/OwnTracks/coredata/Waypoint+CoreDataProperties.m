//
//  Waypoint+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 17.11.22.
//  Copyright © 2022 OwnTracks. All rights reserved.
//
//

#import "Waypoint+CoreDataProperties.h"

@implementation Waypoint (CoreDataProperties)

+ (NSFetchRequest<Waypoint *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"Waypoint"];
}

@dynamic acc;
@dynamic alt;
@dynamic batt;
@dynamic cog;
@dynamic createdAt;
@dynamic lat;
@dynamic lon;
@dynamic placemark;
@dynamic poi;
@dynamic tag;
@dynamic trigger;
@dynamic tst;
@dynamic vac;
@dynamic vel;
@dynamic belongsTo;

@end
