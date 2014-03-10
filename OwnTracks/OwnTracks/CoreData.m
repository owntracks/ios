//
//  CoreData.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "CoreData.h"

@interface CoreData()

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@end

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
        NSLog(@"Document creation %@\n", [url path]);
        [self saveToURL:url forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success){
            if (success) {
                NSLog(@"Document created %@\n", [url path]);
                theManagedObjectContext = self.managedObjectContext;
            }
        }];
    } else {
        if (self.documentState == UIDocumentStateClosed) {
            NSLog(@"Document opening %@\n", [url path]);
            [self openWithCompletionHandler:^(BOOL success){
                if (success) {
                    NSLog(@"Document opened %@\n", [url path]);
                    theManagedObjectContext = self.managedObjectContext;
                }
            }];
        } else {
            NSLog(@"Document used %@\n", [url path]);
            theManagedObjectContext = self.managedObjectContext;
        }
    }

    return self;
}

- (void)handleError:(NSError *)error userInteractionPermitted:(BOOL)userInteractionPermitted
{
    NSLog(@"CoreData handleError: %@", error);
    [self finishedHandlingError:error recovered:NO];
}

- (void)userInteractionNoLongerPermittedForError:(NSError *)error
{
    NSLog(@"CoreData userInteractionNoLongerPermittedForError: %@", error);
}

+ (NSManagedObjectContext *)theManagedObjectContext
{
    return theManagedObjectContext;
}


@end
