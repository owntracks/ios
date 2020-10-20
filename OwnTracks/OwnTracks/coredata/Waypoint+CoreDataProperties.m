//
//  Waypoint+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 19.10.20.
//  Copyright © 2020 OwnTracks. All rights reserved.
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
@dynamic lat;
@dynamic lon;
@dynamic placemark;
@dynamic trigger;
@dynamic tst;
@dynamic vac;
@dynamic vel;
@dynamic createdAt;
@dynamic belongsTo;

@end
