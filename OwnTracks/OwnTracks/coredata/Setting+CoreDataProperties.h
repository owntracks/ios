//
//  Setting+CoreDataProperties.h
//  OwnTracks
//
//  Created by Christoph Krey on 28.09.15.
//  Copyright © 2015-2016 OwnTracks. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Setting.h"

NS_ASSUME_NONNULL_BEGIN

@interface Setting (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *key;
@property (nullable, nonatomic, retain) NSString *value;

@end

NS_ASSUME_NONNULL_END
