//
//  Waypoint+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 14.12.21.
//  Copyright © 2021 OwnTracks. All rights reserved.
//
//

#import "Waypoint+CoreDataProperties.h"

@implementation Waypoint (CoreDataProperties)

+ (NSFetchRequest<Waypoint *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"Waypoint"];
}

@dynamic acc;
@dynamic alt;
@dynamic cog;
@dynamic createdAt;
@dynamic lat;
@dynamic lon;
@dynamic placemark;
@dynamic trigger;
@dynamic tst;
@dynamic vac;
@dynamic vel;
@dynamic batt;
@dynamic belongsTo;

@end
