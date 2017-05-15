//
//  Region+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 28.09.15.
//  Copyright © 2015-2017 OwnTracks. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Region.h"

NS_ASSUME_NONNULL_BEGIN

@interface Region (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *lat;
@property (nullable, nonatomic, retain) NSNumber *lon;
@property (nullable, nonatomic, retain) NSNumber *major;
@property (nullable, nonatomic, retain) NSNumber *minor;
@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSNumber *radius;
@property (nullable, nonatomic, retain) NSNumber *share;
@property (nullable, nonatomic, retain) NSString *uuid;
@property (nullable, nonatomic, retain) NSDate *tst;
@property (nullable, nonatomic, retain) Friend *belongsTo;

@end

NS_ASSUME_NONNULL_END
