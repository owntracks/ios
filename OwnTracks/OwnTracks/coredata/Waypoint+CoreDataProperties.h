//
//  Waypoint+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 08.10.22.
//  Copyright © 2022 OwnTracks. All rights reserved.
//
//

#import "Waypoint+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface Waypoint (CoreDataProperties)

+ (NSFetchRequest<Waypoint *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nullable, nonatomic, copy) NSNumber *acc;
@property (nullable, nonatomic, copy) NSNumber *alt;
@property (nullable, nonatomic, copy) NSNumber *batt;
@property (nullable, nonatomic, copy) NSNumber *cog;
@property (nullable, nonatomic, copy) NSDate *createdAt;
@property (nullable, nonatomic, copy) NSNumber *lat;
@property (nullable, nonatomic, copy) NSNumber *lon;
@property (nullable, nonatomic, copy) NSString *placemark;
@property (nullable, nonatomic, copy) NSString *trigger;
@property (nullable, nonatomic, copy) NSDate *tst;
@property (nullable, nonatomic, copy) NSNumber *vac;
@property (nullable, nonatomic, copy) NSNumber *vel;
@property (nullable, nonatomic, copy) NSString *poi;
@property (nullable, nonatomic, copy) NSString *tag;
@property (nullable, nonatomic, retain) Friend *belongsTo;

@end

NS_ASSUME_NONNULL_END
