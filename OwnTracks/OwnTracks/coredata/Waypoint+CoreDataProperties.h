//
//  Waypoint+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 28.09.15.
//  Copyright © 2015-2018 OwnTracks. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Waypoint.h"

NS_ASSUME_NONNULL_BEGIN

@interface Waypoint (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *acc;
@property (nullable, nonatomic, retain) NSNumber *alt;
@property (nullable, nonatomic, retain) NSNumber *cog;
@property (nullable, nonatomic, retain) NSNumber *lat;
@property (nullable, nonatomic, retain) NSNumber *lon;
@property (nullable, nonatomic, retain) NSString *placemark;
@property (nullable, nonatomic, retain) NSString *trigger;
@property (nullable, nonatomic, retain) NSDate *tst;
@property (nullable, nonatomic, retain) NSNumber *vac;
@property (nullable, nonatomic, retain) NSNumber *vel;
@property (nullable, nonatomic, retain) Friend *belongsTo;

@end

NS_ASSUME_NONNULL_END
