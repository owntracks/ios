//
//  CoreData.h
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright © 2013 -2019 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface CoreData : NSObject
@property (readonly, strong, nonatomic) NSManagedObjectContext *mainMOC;
@property (readonly, strong, nonatomic) NSManagedObjectContext *queuedMOC;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *PSC;

+ (CoreData *)sharedInstance;
- (void)sync:(NSManagedObjectContext *)context;
@end
