//
//  CoreData.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright (c) 2013-2015 Christoph Krey. All rights reserved.
//

#import "CoreData.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

static NSManagedObjectContext *theManagedObjectContext = nil;

@implementation CoreData
static const DDLogLevel ddLogLevel = DDLogLevelError;

- (id)init
{
    NSURL *url = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    url = [url URLByAppendingPathComponent:@"OwnTracks"];

    self = [super initWithFileURL:url];
    DDLogVerbose(@"ddLogLevel %lu", (unsigned long)ddLogLevel);
        
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                             nil];
    self.persistentStoreOptions = options;
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
        DDLogVerbose(@"Document creation %@\n", [url path]);
        [self saveToURL:url forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success){
            if (success) {
                DDLogVerbose(@"Document created %@\n", [url path]);
                theManagedObjectContext = self.managedObjectContext;
            }
        }];
    } else {
        if (self.documentState == UIDocumentStateClosed) {
            DDLogVerbose(@"Document opening %@\n", [url path]);
            [self openWithCompletionHandler:^(BOOL success){
                if (success) {
                    DDLogVerbose(@"Document opened %@\n", [url path]);
                    theManagedObjectContext = self.managedObjectContext;
                }
            }];
        } else {
            DDLogVerbose(@"Document used %@\n", [url path]);
            theManagedObjectContext = self.managedObjectContext;
        }
    }

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                      object:nil queue:nil usingBlock:^(NSNotification *note){
                                                          DDLogVerbose(@"UIApplicationWillResignActiveNotification");
                                                          [CoreData saveContext];
                                                      }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                      object:nil queue:nil usingBlock:^(NSNotification *note){
                                                          DDLogVerbose(@"UIApplicationWillTerminateNotification");
                                                          [CoreData saveContext];
                                                      }];

    return self;
}

- (void)handleError:(NSError *)error userInteractionPermitted:(BOOL)userInteractionPermitted
{
    DDLogVerbose(@"CoreData handleError: %@", error);
    [self finishedHandlingError:error recovered:NO];
}

- (void)userInteractionNoLongerPermittedForError:(NSError *)error
{
    DDLogVerbose(@"CoreData userInteractionNoLongerPermittedForError: %@", error);
}

+ (NSManagedObjectContext *)theManagedObjectContext
{
    return theManagedObjectContext;
}

+ (void)saveContext {
    [CoreData saveContext:theManagedObjectContext];
}

+ (void)saveContext:(NSManagedObjectContext *)context {
    if (context != nil) {
        if ([context hasChanges]) {
            NSError *error = nil;
            DDLogVerbose(@"managedObjectContext save");
            if (![context save:&error]) {
                NSString *message = [NSString stringWithFormat:@"%@ %@", error.localizedDescription, error.userInfo];
                DDLogError(@"managedObjectContext save error: %@", message);
            }
        }
    }
}



@end
