//
//  Region+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
//  Copyright © 2018 OwnTracks. All rights reserved.
//
//

#import "Region+CoreDataProperties.h"

@implementation Region (CoreDataProperties)

+ (NSFetchRequest<Region *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"Region"];
}

@dynamic lat;
@dynamic lon;
@dynamic major;
@dynamic minor;
@dynamic name;
@dynamic radius;
@dynamic tst;
@dynamic uuid;
@dynamic belongsTo;

@end
