//
//  Setting+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 26.07.19.
//  Copyright © 2019-2020 OwnTracks. All rights reserved.
//
//

#import "Setting+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface Setting (CoreDataProperties)

+ (NSFetchRequest<Setting *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *key;
@property (nullable, nonatomic, copy) NSString *value;

@end

NS_ASSUME_NONNULL_END
