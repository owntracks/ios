//
//  Setting+CoreDataClass.m
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
//  Copyright © 2018-2022 OwnTracks. All rights reserved.
//
//

#import "Setting+CoreDataClass.h"
#import "CoreData.h"

@implementation Setting

+ (Setting *)existsSettingWithKey:(NSString *)key inMOC:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Setting"];
    request.predicate = [NSPredicate predicateWithFormat:@"key = %@", key];

    Setting *setting = nil;
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];

    if (!matches) {
        // handle error
    } else {
        if (matches.count) {
            setting = matches.lastObject;
        }
    }

    return setting;
}

+ (Setting *)settingWithKey:(NSString *)key inMOC:(NSManagedObjectContext *)context {
    Setting *setting = [Setting existsSettingWithKey:key inMOC:context];

    if (!setting) {
        setting = [NSEntityDescription insertNewObjectForEntityForName:@"Setting"
                                                inManagedObjectContext:context];
        setting.key = key;
    }

    return setting;
}

+ (NSArray *)allSettingsInMOC:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Setting"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"key" ascending:YES]];

    NSArray *matches = nil;
    NSError *error = nil;
    matches = [context executeFetchRequest:request error:&error];
    return matches;
}

@end
