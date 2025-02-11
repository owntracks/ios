//
//  History+CoreDataClass.h
//  OwnTracks
//
//  Created by Christoph Krey on 26.08.19.
//  Copyright © 2019-2025 OwnTracks. All rights reserved.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface History : NSManagedObject
+ (void)historyInGroup:(nonnull NSString *)group
              withText:(nonnull NSString *)text
                    at:(nullable NSDate *)date
                 inMOC:(nonnull NSManagedObjectContext *)context
               maximum:(int)maximum;

- (NSString *)timestampText;

+ (NSArray *)allHistoriesInManagedObjectContext:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END

#import "History+CoreDataProperties.h"
