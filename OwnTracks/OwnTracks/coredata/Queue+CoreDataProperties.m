//
//  Queue+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
//  Copyright © 2018 OwnTracks. All rights reserved.
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
