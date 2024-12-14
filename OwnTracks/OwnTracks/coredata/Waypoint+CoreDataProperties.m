//
//  Waypoint+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 03.12.24.
//  Copyright © 2024 OwnTracks. All rights reserved.
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
@dynamic image;
@dynamic imageName;
@dynamic belongsTo;

@end
