//
//  Queue+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 20.02.16.
//  Copyright © 2016-2017 OwnTracks. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Queue.h"

NS_ASSUME_NONNULL_BEGIN

@interface Queue (CoreDataProperties)

@property (nullable, nonatomic, retain) NSDate *timestamp;
@property (nullable, nonatomic, retain) NSData *data;
@property (nullable, nonatomic, retain) NSString *topic;

@end

NS_ASSUME_NONNULL_END
