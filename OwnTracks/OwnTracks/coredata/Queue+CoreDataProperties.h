//
//  Queue+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
//  Copyright © 2018-2019 OwnTracks. All rights reserved.
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
