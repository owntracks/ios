//
//  CoreData.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright (c) 2013-2015 Christoph Krey. All rights reserved.
//

#import "CoreData.h"

#ifdef DEBUG
#define DEBUGCORE FALSE
#else
#define DEBUGCORE FALSE
#endif

static NSManagedObjectContext *theManagedObjectContext = nil;

@implementation CoreData

- (id)init
{
    NSURL *url = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    url = [url URLByAppendingPathComponent:@"OwnTracks"];

    self = [super initWithFileURL:url];
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                             nil];
    self.persistentStoreOptions = options;
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
        if (DEBUGCORE) NSLog(@"Document creation %@\n", [url path]);
        [self saveToURL:url forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success){
            if (success) {
                if (DEBUGCORE) NSLog(@"Document created %@\n", [url path]);
                theManagedObjectContext = self.managedObjectContext;
            }
        }];
    } else {
        if (self.documentState == UIDocumentStateClosed) {
            if (DEBUGCORE) NSLog(@"Document opening %@\n", [url path]);
            [self openWithCompletionHandler:^(BOOL success){
                if (success) {
                    if (DEBUGCORE) NSLog(@"Document opened %@\n", [url path]);
                    theManagedObjectContext = self.managedObjectContext;
                }
            }];
        } else {
            if (DEBUGCORE) NSLog(@"Document used %@\n", [url path]);
            theManagedObjectContext = self.managedObjectContext;
        }
    }

    return self;
}

- (void)handleError:(NSError *)error userInteractionPermitted:(BOOL)userInteractionPermitted
{
    if (DEBUGCORE) NSLog(@"CoreData handleError: %@", error);
    [self finishedHandlingError:error recovered:NO];
}

- (void)userInteractionNoLongerPermittedForError:(NSError *)error
{
    if (DEBUGCORE) NSLog(@"CoreData userInteractionNoLongerPermittedForError: %@", error);
}

+ (NSManagedObjectContext *)theManagedObjectContext
{
    return theManagedObjectContext;
}


@end
