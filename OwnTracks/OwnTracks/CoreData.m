//
//  CoreData.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright © 2013-2025  Christoph Krey. All rights reserved.
//

#import "CoreData.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface CoreData ()
@property (strong, nonatomic) NSManagedObjectContext *mainMOC;
@property (strong, nonatomic) NSManagedObjectContext *queuedMOC;
@property (strong, nonatomic) NSPersistentStoreCoordinator *PSC;
@end

@implementation CoreData
static const DDLogLevel ddLogLevel = DDLogLevelInfo;

+ (CoreData *)sharedInstance {
    static dispatch_once_t once = 0;
    static id sharedInstance = nil;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];

    self.PSC = [self createPersistentStoreCoordinator];

    self.mainMOC = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    self.mainMOC.name = @"mainMOC";
    self.mainMOC.persistentStoreCoordinator = self.PSC;

    // Fix: Use separate contexts instead of parent-child relationship to prevent deadlocks
    self.queuedMOC = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    self.queuedMOC.name = @"queuedMOC";
    self.queuedMOC.persistentStoreCoordinator = self.PSC;
    self.queuedMOC.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;

    return self;
}

- (void)sync:(NSManagedObjectContext *)context {
    DDLogVerbose(@"[CoreData] sync: %ld,%ld,%ld %@ %@",
              context.insertedObjects.count,
              context.updatedObjects.count,
              context.deletedObjects.count,
              context.name, context.parentContext ? context.parentContext.name : @"nil");

    if (context.hasChanges) {
        NSError *error = nil;
        if (![context save:&error]) {
            DDLogError(@"[CoreData] save error: %@", error);
            
            // Handle merge conflicts by refreshing the context
            if (error.code == 133020) { // NSCocoaErrorDomain merge conflict
                DDLogWarn(@"[CoreData] Merge conflict detected, refreshing context");
                [context performBlock:^{
                    [context refreshAllObjects];
                }];
                
                // If we get multiple merge conflicts, trigger recovery
                static int conflictCount = 0;
                conflictCount++;
                if (conflictCount > 5) {
                    DDLogError(@"[CoreData] Too many merge conflicts, triggering recovery");
                    [self recoverFromStuckContexts];
                    conflictCount = 0;
                }
            }
        }
        
        // Post notification to trigger UI updates since we're using separate contexts
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"CoreDataDidSaveNotification" 
                                                                object:nil 
                                                              userInfo:@{@"context": context}];
        });
    }
}

#pragma mark - Core Data stack
- (NSPersistentStoreCoordinator *)createPersistentStoreCoordinator {
    NSURL *persistentStoreURLOld = [self.applicationDocumentsDirectory
                                 URLByAppendingPathComponent:@"OwnTracks/StoreContent/persistentStore"];
    DDLogDebug(@"[MQTTPersistence] Persistent store old: %@", persistentStoreURLOld.path);

    NSURL *persistentStoreURLNew = [self.applicationDocumentsDirectory
                                 URLByAppendingPathComponent:@"OwnTracks"];
    DDLogDebug(@"[MQTTPersistence] Persistent store new: %@", persistentStoreURLNew.path);

    NSError *error = nil;
    NSPersistentStoreCoordinator *persistentStoreCoordinator =
    [[NSPersistentStoreCoordinator alloc]
     initWithManagedObjectModel:self.managedObjectModel];

    NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                              NSInferMappingModelAutomaticallyOption: @YES,
                              NSSQLiteAnalyzeOption: @YES,
                              NSSQLiteManualVacuumOption: @YES
                              };

    if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                  configuration:nil
                                                            URL:persistentStoreURLOld
                                                        options:options
                                                          error:&error]) {
        DDLogDebug(@"[MQTTPersistence] managedObjectContext save old: %@", error);
        if (error) {
            if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                          configuration:nil
                                                                    URL:persistentStoreURLNew
                                                                options:options
                                                                  error:&error]) {
                DDLogError(@"[MQTTPersistence] managedObjectContext save new: %@", error);
                persistentStoreCoordinator = nil;
            }
        }
    }
    return persistentStoreCoordinator;
}

- (NSURL *)applicationDocumentsDirectory {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray <NSURL *> *directories = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *directory = directories.lastObject;
    return directory;
}

- (NSManagedObjectModel *)managedObjectModel {
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *URL = [bundle URLForResource:@"Model" withExtension:@"momd"];
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:URL];
    return model;
}

// Add method to merge changes from queued context to main context
- (void)mergeChangesFromQueuedContext {
    [self.mainMOC performBlock:^{
        // Use merge policy to handle conflicts
        self.mainMOC.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        
        // Refresh the main context to see changes from queued context
        [self.mainMOC refreshAllObjects];
        
        // Post notification to trigger UI updates
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"CoreDataDidSaveNotification" 
                                                                object:nil 
                                                              userInfo:nil];
        });
    }];
}

// Add recovery method for stuck contexts
- (void)recoverFromStuckContexts {
    DDLogWarn(@"[CoreData] Attempting to recover from stuck contexts");
    
    // Reset queued context
    [self.queuedMOC performBlock:^{
        [self.queuedMOC reset];
    }];
    
    // Reset main context
    [self.mainMOC performBlock:^{
        [self.mainMOC reset];
    }];
    
    DDLogInfo(@"[CoreData] Contexts reset, recovery complete");
}

@end
