//
//  History+CoreDataClass.m
//  OwnTracks
//
//  Created by Christoph Krey on 26.08.19.
//  Copyright © 2019-2024 OwnTracks. All rights reserved.
//
//

#import "History+CoreDataClass.h"

@implementation History

+ (void)historyInGroup:(NSString *)group
              withText:(NSString *)text
                    at:(NSDate *)date
                 inMOC:(NSManagedObjectContext *)context
               maximum:(int)maximum {

    History *history = [NSEntityDescription insertNewObjectForEntityForName:@"History"
                                            inManagedObjectContext:context];
    if (date) {
        history.timestamp = date;
    } else {
        history.timestamp = [NSDate date];
    }
    history.seen = [NSNumber numberWithBool:FALSE];
    history.group = group;
    history.text = text;

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"History"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];

    NSArray *matches = [context executeFetchRequest:request error:nil];
    if (matches) {
        for (int toDelete = (int)matches.count - maximum; toDelete > 0; toDelete--) {
            [context deleteObject:[matches objectAtIndex:toDelete - 1]];
        }
    }
}

- (NSString *)timestampText {
    return [NSDateFormatter localizedStringFromDate:self.timestamp
                                          dateStyle:NSDateFormatterShortStyle
                                          timeStyle:NSDateFormatterMediumStyle];
}

+ (NSArray *)allHistoriesInManagedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"History"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];

    NSError *error = nil;

    NSArray *matches = [context executeFetchRequest:request error:&error];

    return matches;
}



@end
