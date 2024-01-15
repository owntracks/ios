//
//  Region+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 08.01.21.
//  Copyright © 2021-2024 OwnTracks. All rights reserved.
//
//

#import "Region+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface Region (CoreDataProperties)

+ (NSFetchRequest<Region *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSNumber *lat;
@property (nullable, nonatomic, copy) NSNumber *lon;
@property (nullable, nonatomic, copy) NSNumber *major;
@property (nullable, nonatomic, copy) NSNumber *minor;
@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, copy) NSNumber *radius;
@property (nullable, nonatomic, copy) NSDate *tst;
@property (nullable, nonatomic, copy) NSString *uuid;
@property (nullable, nonatomic, copy) NSString *rid;
@property (nullable, nonatomic, retain) Friend *belongsTo;

@end

NS_ASSUME_NONNULL_END
