//
//  Setting.h
//  OwnTracks
//
//  Created by Christoph Krey on 28.09.15.
//  Copyright © 2015-2018 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface Setting : NSManagedObject

+ (Setting *)existsSettingWithKey:(NSString *)key inMOC:(NSManagedObjectContext *)context;
+ (Setting *)settingWithKey:(NSString *)key inMOC:(NSManagedObjectContext *)context;
+ (NSArray *)allSettingsInMOC:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END

#import "Setting+CoreDataProperties.h"
