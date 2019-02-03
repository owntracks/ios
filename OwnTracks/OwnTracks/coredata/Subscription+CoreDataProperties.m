//
//  Subscription+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
//  Copyright © 2018-2019 OwnTracks. All rights reserved.
//
//

#import "Subscription+CoreDataProperties.h"

@implementation Subscription (CoreDataProperties)

+ (NSFetchRequest<Subscription *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"Subscription"];
}

@dynamic level;
@dynamic name;
@dynamic belongsTo;
@dynamic hasInfos;

@end
