//
//  Info+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
//  Copyright © 2018 OwnTracks. All rights reserved.
//
//

#import "Info+CoreDataProperties.h"

@implementation Info (CoreDataProperties)

+ (NSFetchRequest<Info *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"Info"];
}

@dynamic circleEnd;
@dynamic circleStart;
@dynamic geohash;
@dynamic hand;
@dynamic identifier;
@dynamic image;
@dynamic lat;
@dynamic level;
@dynamic lon;
@dynamic name;
@dynamic ringColor;
@dynamic size;
@dynamic tid;
@dynamic tst;
@dynamic belongsTo;

@end
