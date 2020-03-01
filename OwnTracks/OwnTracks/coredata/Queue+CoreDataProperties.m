//
//  Queue+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 26.07.19.
//  Copyright © 2019-2020 OwnTracks. All rights reserved.
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
