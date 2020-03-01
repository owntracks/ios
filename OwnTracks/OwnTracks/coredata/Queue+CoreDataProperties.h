//
//  Queue+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 26.07.19.
//  Copyright © 2019-2020 OwnTracks. All rights reserved.
//
//

#import "Queue+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface Queue (CoreDataProperties)

+ (NSFetchRequest<Queue *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *data;
@property (nullable, nonatomic, copy) NSDate *timestamp;
@property (nullable, nonatomic, copy) NSString *topic;

@end

NS_ASSUME_NONNULL_END
