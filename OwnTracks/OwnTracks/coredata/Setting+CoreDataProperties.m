//
//  Setting+CoreDataProperties.m
//  OwnTracks
//
//  Created by Christoph Krey on 26.07.19.
//  Copyright © 2019-2024 OwnTracks. All rights reserved.
//
//

#import "Setting+CoreDataProperties.h"

@implementation Setting (CoreDataProperties)

+ (NSFetchRequest<Setting *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"Setting"];
}

@dynamic key;
@dynamic value;

@end
