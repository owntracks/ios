//
//  Setting+CoreDataClass.h
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
//  Copyright © 2018-2025 OwnTracks. All rights reserved.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface Setting : NSManagedObject

+ (Setting * _Nullable)existsSettingWithKey:(NSString *)key inMOC:(NSManagedObjectContext *)context;
+ (Setting *)settingWithKey:(NSString *)key inMOC:(NSManagedObjectContext *)context;
+ (NSArray *)allSettingsInMOC:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END

#import "Setting+CoreDataProperties.h"
