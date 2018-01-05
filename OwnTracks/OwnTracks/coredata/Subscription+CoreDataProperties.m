//
//  Subscription+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 08.12.16.
//  Copyright © 2016-2018 OwnTracks. All rights reserved.
//

#import "Subscription+CoreDataProperties.h"

@implementation Subscription (CoreDataProperties)

+ (NSFetchRequest<Subscription *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"Subscription"];
}

@dynamic name;
@dynamic level;
@dynamic belongsTo;
@dynamic hasInfos;

@end
