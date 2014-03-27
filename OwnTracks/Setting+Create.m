//
//  Setting+Create.m
//  OwnTracks
//
//  Created by Christoph Krey on 27.03.14.
//  Copyright (c) 2014 OwnTracks. All rights reserved.
//

#import "Setting+Create.h"

@implementation Setting (Create)

+ (Setting *)existsSettingWithKey:(NSString *)key inManagedObjectContext:(NSManagedObjectContext *)context
{
    Setting *setting = nil;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Setting"];
    request.predicate = [NSPredicate predicateWithFormat:@"key = %@", key];
    
    NSError *error = nil;
    
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (!matches) {
        // handle error
    } else {
        if ([matches count]) {
            setting = [matches lastObject];
        }
    }
    
    return setting;
}

+ (Setting *)settingWithKey:(NSString *)key inManagedObjectContext:(NSManagedObjectContext *)context
{
    Setting *setting = [Setting existsSettingWithKey:key inManagedObjectContext:context];
    
    if (!setting) {
        
        setting = [NSEntityDescription insertNewObjectForEntityForName:@"Setting" inManagedObjectContext:context];
        
        setting.key = key;
    }
    
    return setting;
}

@end
