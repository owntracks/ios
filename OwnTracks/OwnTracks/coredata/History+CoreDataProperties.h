//
//  History+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 26.08.19.
//  Copyright © 2019-2024 OwnTracks. All rights reserved.
//
//

#import "History+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface History (CoreDataProperties)

+ (NSFetchRequest<History *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSDate *timestamp;
@property (nullable, nonatomic, copy) NSString *text;
@property (nullable, nonatomic, copy) NSString *group;
@property (nullable, nonatomic, copy) NSNumber *seen;

@end

NS_ASSUME_NONNULL_END
