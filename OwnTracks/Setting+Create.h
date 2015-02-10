//
//  Setting+Create.h
//  OwnTracks
//
//  Created by Christoph Krey on 27.03.14.
//  Copyright (c) 2014-2015 OwnTracks. All rights reserved.
//

#import "Setting.h"

@interface Setting (Create)
+ (Setting *)existsSettingWithKey:(NSString *)key inManagedObjectContext:(NSManagedObjectContext *)context;
+ (Setting *)settingWithKey:(NSString *)key inManagedObjectContext:(NSManagedObjectContext *)context;

@end
