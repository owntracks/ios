//
//  Setting.m
//  OwnTracks
//
//  Created by Christoph Krey on 28.09.15.
//  Copyright © 2015-2017 OwnTracks. All rights reserved.
//

#import "Setting.h"
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
