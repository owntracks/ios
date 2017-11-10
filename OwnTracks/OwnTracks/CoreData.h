//
//  CoreData.h
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright © 2013-2017 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface CoreData : NSObject
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
+ (CoreData *)sharedInstance;
- (void)sync;
@end
