//
//  Info+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 08.12.16.
//  Copyright © 2016 OwnTracks. All rights reserved.
//

#import "Info+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface Info (CoreDataProperties)

+ (NSFetchRequest<Info *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSNumber *circleEnd;
@property (nullable, nonatomic, retain) NSData *image;
@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, copy) NSString *tid;
@property (nullable, nonatomic, copy) NSNumber *circleStart;
@property (nullable, nonatomic, copy) NSNumber *level;
@property (nullable, nonatomic, copy) NSNumber *hand;
@property (nullable, nonatomic, copy) NSNumber *ringColor;
@property (nullable, nonatomic, copy) NSNumber *lat;
@property (nullable, nonatomic, copy) NSNumber *lon;
@property (nullable, nonatomic, copy) NSNumber *size;
@property (nullable, nonatomic, copy) NSString *geohash;
@property (nullable, nonatomic, copy) NSDate *tst;
@property (nullable, nonatomic, copy) NSString *identifier;
@property (nullable, nonatomic, retain) Subscription *belongsTo;

@end

NS_ASSUME_NONNULL_END
