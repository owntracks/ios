//
//  Waypoint+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
//  Copyright © 2018-2019 OwnTracks. All rights reserved.
//
//

#import "Waypoint+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface Waypoint (CoreDataProperties)

+ (NSFetchRequest<Waypoint *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSNumber *acc;
@property (nullable, nonatomic, copy) NSNumber *alt;
@property (nullable, nonatomic, copy) NSNumber *cog;
@property (nullable, nonatomic, copy) NSNumber *lat;
@property (nullable, nonatomic, copy) NSNumber *lon;
@property (nullable, nonatomic, copy) NSString *placemark;
@property (nullable, nonatomic, copy) NSString *trigger;
@property (nullable, nonatomic, copy) NSDate *tst;
@property (nullable, nonatomic, copy) NSNumber *vac;
@property (nullable, nonatomic, copy) NSNumber *vel;
@property (nullable, nonatomic, retain) Friend *belongsTo;

@end

NS_ASSUME_NONNULL_END
