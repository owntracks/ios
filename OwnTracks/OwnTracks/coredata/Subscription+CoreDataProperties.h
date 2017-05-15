//
//  Subscription+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 08.12.16.
//  Copyright © 2016-2017 OwnTracks. All rights reserved.
//

#import "Subscription+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface Subscription (CoreDataProperties)

+ (NSFetchRequest<Subscription *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, copy) NSNumber *level;
@property (nullable, nonatomic, retain) Friend *belongsTo;
@property (nullable, nonatomic, retain) NSSet<Info *> *hasInfos;

@end

@interface Subscription (CoreDataGeneratedAccessors)

- (void)addHasInfosObject:(Info *)value;
- (void)removeHasInfosObject:(Info *)value;
- (void)addHasInfos:(NSSet<Info *> *)values;
- (void)removeHasInfos:(NSSet<Info *> *)values;

@end

NS_ASSUME_NONNULL_END
