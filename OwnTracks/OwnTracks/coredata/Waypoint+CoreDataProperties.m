//
//  Waypoint+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 06.02.25.
//  Copyright © 2025 OwnTracks. All rights reserved.
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
@dynamic image;
@dynamic imageName;
@dynamic lat;
@dynamic lon;
@dynamic placemark;
@dynamic poi;
@dynamic tag;
@dynamic trigger;
@dynamic tst;
@dynamic vac;
@dynamic vel;
@dynamic inRegions;
@dynamic inRids;
@dynamic bs;
@dynamic m;
@dynamic conn;
@dynamic bssid;
@dynamic ssid;
@dynamic belongsTo;

@end
