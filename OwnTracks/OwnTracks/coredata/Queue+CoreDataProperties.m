//
//  Queue+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 08.01.21.
//  Copyright © 2021-2022 OwnTracks. All rights reserved.
//
//

#import "Queue+CoreDataProperties.h"

@implementation Queue (CoreDataProperties)

+ (NSFetchRequest<Queue *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"Queue"];
}

@dynamic data;
@dynamic timestamp;
@dynamic topic;

@end
