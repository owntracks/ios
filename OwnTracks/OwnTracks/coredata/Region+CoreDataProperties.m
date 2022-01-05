//
//  Region+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 08.01.21.
//  Copyright © 2021-2022 OwnTracks. All rights reserved.
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
@dynamic rid;
@dynamic belongsTo;

@end
