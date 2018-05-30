//
//  Setting+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
//  Copyright © 2018 OwnTracks. All rights reserved.
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
