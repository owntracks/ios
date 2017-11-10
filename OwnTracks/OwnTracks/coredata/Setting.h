//
//  Setting.h
//  OwnTracks
//
//  Created by Christoph Krey on 28.09.15.
//  Copyright © 2015-2017 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface Setting : NSManagedObject

+ (Setting *)existsSettingWithKey:(NSString *)key;
+ (Setting *)settingWithKey:(NSString *)key;
+ (NSArray *)allSettings;

@end

NS_ASSUME_NONNULL_END

#import "Setting+CoreDataProperties.h"
