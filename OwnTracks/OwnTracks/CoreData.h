//
//  CoreData.h
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright (c) 2013, 2014 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface CoreData : UIManagedDocument
+ (NSManagedObjectContext *)theManagedObjectContext;
@end
