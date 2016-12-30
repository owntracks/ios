//
//  Info+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 08.12.16.
//  Copyright © 2016 OwnTracks. All rights reserved.
//

#import "Info+CoreDataProperties.h"

@implementation Info (CoreDataProperties)

+ (NSFetchRequest<Info *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"Info"];
}

@dynamic circleEnd;
@dynamic image;
@dynamic name;
@dynamic tid;
@dynamic circleStart;
@dynamic level;
@dynamic hand;
@dynamic ringColor;
@dynamic lat;
@dynamic lon;
@dynamic size;
@dynamic geohash;
@dynamic tst;
@dynamic identifier;
@dynamic belongsTo;

@end
