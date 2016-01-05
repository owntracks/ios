//
//  Location+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 28.09.15.
//  Copyright © 2015-2016 OwnTracks. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Location.h"

NS_ASSUME_NONNULL_BEGIN

@interface Location (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *accuracy;
@property (nullable, nonatomic, retain) NSNumber *altitude;
@property (nullable, nonatomic, retain) NSNumber *automatic;
@property (nullable, nonatomic, retain) NSNumber *course;
@property (nullable, nonatomic, retain) NSNumber *justcreated;
@property (nullable, nonatomic, retain) NSNumber *latitude;
@property (nullable, nonatomic, retain) NSNumber *longitude;
@property (nullable, nonatomic, retain) NSString *placemark;
@property (nullable, nonatomic, retain) NSNumber *regionradius;
@property (nullable, nonatomic, retain) NSString *remark;
@property (nullable, nonatomic, retain) NSNumber *share;
@property (nullable, nonatomic, retain) NSNumber *speed;
@property (nullable, nonatomic, retain) NSDate *timestamp;
@property (nullable, nonatomic, retain) NSNumber *verticalaccuracy;
@property (nullable, nonatomic, retain) Friend *belongsTo;

@end

NS_ASSUME_NONNULL_END
