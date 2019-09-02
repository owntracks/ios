//
//  History+CoreDataClass.h
//  OwnTracks
//
//  Created by Christoph Krey on 26.08.19.
//  Copyright © 2019 OwnTracks. All rights reserved.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface History : NSManagedObject
+ (void)historyInGroup:(NSString *)group
              withText:(NSString *)text
                 inMOC:(NSManagedObjectContext *)context
               maximum:(int)maximum;

- (NSString *)timestampText;

+ (NSArray *)allHistoriesInManagedObjectContext:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END

#import "History+CoreDataProperties.h"
