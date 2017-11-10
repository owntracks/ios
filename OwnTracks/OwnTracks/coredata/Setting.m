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

+ (Setting *)existsSettingWithKey:(NSString *)key {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Setting"];
    request.predicate = [NSPredicate predicateWithFormat:@"key = %@", key];

    Setting *setting = nil;
    NSError *error = nil;
    NSArray *matches = [CoreData.sharedInstance.managedObjectContext executeFetchRequest:request error:&error];

    if (!matches) {
        // handle error
    } else {
        if (matches.count) {
            setting = matches.lastObject;
        }
    }

    return setting;
}

+ (Setting *)settingWithKey:(NSString *)key {
    Setting *setting = [Setting existsSettingWithKey:key];

    if (!setting) {
        setting = [NSEntityDescription insertNewObjectForEntityForName:@"Setting"
                                                inManagedObjectContext:CoreData.sharedInstance.managedObjectContext];
        setting.key = key;
    }

    return setting;
}

+ (NSArray *)allSettings {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Setting"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"key" ascending:YES]];

    NSArray *matches = nil;
    NSError *error = nil;
    matches = [CoreData.sharedInstance.managedObjectContext executeFetchRequest:request error:&error];
    return matches;
}


@end
