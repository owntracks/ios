//
//  Waypoint+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 11.06.25.
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
@dynamic bs;
@dynamic bssid;
@dynamic cog;
@dynamic conn;
@dynamic createdAt;
@dynamic image;
@dynamic imageName;
@dynamic inRegions;
@dynamic inRids;
@dynamic lat;
@dynamic lon;
@dynamic m;
@dynamic placemark;
@dynamic poi;
@dynamic ssid;
@dynamic tag;
@dynamic trigger;
@dynamic tst;
@dynamic vac;
@dynamic vel;
@dynamic pressure;
@dynamic motionActivities;
@dynamic belongsTo;

@end
