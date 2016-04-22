//
//  Setting+Create.h
//  OwnTracks
//
//  Created by Christoph Krey on 27.03.14.
//  Copyright © 2014-2016 OwnTracks. All rights reserved.
//

#import "Setting+CoreDataProperties.h"

@interface Setting (Create)
+ (Setting *)existsSettingWithKey:(NSString *)key inManagedObjectContext:(NSManagedObjectContext *)context;
+ (Setting *)settingWithKey:(NSString *)key inManagedObjectContext:(NSManagedObjectContext *)context;
+ (NSArray *)allSettingsInManagedObjectContext:(NSManagedObjectContext *)context;

@end
