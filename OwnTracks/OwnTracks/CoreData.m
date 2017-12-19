//
//  CoreData.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright © 2013-2017 Christoph Krey. All rights reserved.
//

#import "CoreData.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface CoreData ()
@property (strong, nonatomic) NSManagedObjectContext *mainMOC;
@property (strong, nonatomic) NSManagedObjectContext *queuedMOC;
@property (strong, nonatomic) NSPersistentStoreCoordinator *PSC;
@end

@implementation CoreData
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;

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
    self.mainMOC.persistentStoreCoordinator = self.PSC;

    self.queuedMOC = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    self.queuedMOC.persistentStoreCoordinator = self.PSC;

    return self;
}

- (void)sync:(NSManagedObjectContext *)context {
    if (context.hasChanges) {
        NSError *error = nil;
        if (![context save:&error]) {
            DDLogError(@"[CoreData] save error: %@", error);
        }
    }
}

#pragma mark - Core Data stack
- (NSPersistentStoreCoordinator *)createPersistentStoreCoordinator {
    NSURL *persistentStoreURLOld = [self.applicationDocumentsDirectory
                                 URLByAppendingPathComponent:@"OwnTracks/StoreContent/persistentStore"];
    DDLogInfo(@"[MQTTPersistence] Persistent store old: %@", persistentStoreURLOld.path);

    NSURL *persistentStoreURLNew = [self.applicationDocumentsDirectory
                                 URLByAppendingPathComponent:@"OwnTracks"];
    DDLogInfo(@"[MQTTPersistence] Persistent store new: %@", persistentStoreURLNew.path);

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
        DDLogError(@"[MQTTPersistence] managedObjectContext save old: %@", error);
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


@end
