//
//  HistoryTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 26.08.19.
//  Copyright © 2019-2025 OwnTracks. All rights reserved.
//

#import "HistoryTVC.h"
#import "History+CoreDataClass.h"
#import "CoreData.h"
#import "Settings.h"
#import "OwnTracksAppDelegate.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface HistoryTVC ()

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

@end

@implementation HistoryTVC

static const DDLogLevel ddLogLevel = DDLogLevelInfo;

- (IBAction)trashPressed:(UIBarButtonItem *)sender {
    NSArray *histories = [History allHistoriesInManagedObjectContext:CoreData.sharedInstance.mainMOC];
    for (History *history in histories) {
        [CoreData.sharedInstance.mainMOC deleteObject:history];
    }
    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];

}

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note){
                                                      [self reset];
                                                  }];

}

- (void)viewWillAppear:(BOOL)animated {
    self.tableView.sectionIndexMinimumDisplayRowCount = 4;
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self reset];
}

- (void)reset {
    self.fetchedResultsController = nil;
    if (self.tableView) {
        [self.tableView reloadData];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if ((self.fetchedResultsController).sections.count == 0) {
        [self empty];
    } else {
        [self nonempty];
    }

    return (self.fetchedResultsController).sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = (self.fetchedResultsController).sections[section];
    return sectionInfo.numberOfObjects;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return self.fetchedResultsController.sectionIndexTitles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return [self.fetchedResultsController sectionForSectionIndexTitle:title
                                                           atIndex:index];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"historyCell"
                                                            forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = (self.fetchedResultsController).managedObjectContext;
        History *history = [self.fetchedResultsController objectAtIndexPath:indexPath];
        if (history) {
            [context deleteObject:history];
            [CoreData.sharedInstance sync:context];
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = (self.fetchedResultsController).sections[section];
    return sectionInfo.name;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    History *history = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (!history.seen.boolValue) {
        history.seen = [NSNumber numberWithBool:TRUE];
        [[CoreData sharedInstance] sync:history.managedObjectContext];
    }
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"History"
                                              inManagedObjectContext:CoreData.sharedInstance.mainMOC];
    fetchRequest.entity = entity;
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@"group" ascending:NO];
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor1, sortDescriptor2];
    fetchRequest.sortDescriptors = sortDescriptors;

    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc]
                                                             initWithFetchRequest:fetchRequest
                                                             managedObjectContext:CoreData.sharedInstance.mainMOC
                                                             sectionNameKeyPath:@"group"
                                                             cacheName:nil];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;

    NSError *error = nil;
    if (![self.fetchedResultsController performFetch:&error]) {
        DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
    }

    DDLogVerbose(@"[HistoryTVC]fetchedResultsControllser %@", _fetchedResultsController);
    return _fetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    DDLogVerbose(@"[HistoryTVC][controllerWillChangeContent]");
    [self performSelectorOnMainThread:@selector(beginUpdates) withObject:nil waitUntilDone:TRUE];
}

- (void)beginUpdates {
    DDLogVerbose(@"[HistoryTVC][beginUpdates]");
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type {
    NSDictionary *d = @{@"type": @(type),
                        @"sectionIndex": @(sectionIndex)};
    [self performSelectorOnMainThread:@selector(didChangeSection:) withObject:d waitUntilDone:TRUE];
}

- (void)didChangeSection:(NSDictionary *)d {
    NSNumber *type = d[@"type"];
    NSNumber *sectionIndex = d[@"sectionIndex"];

    switch(type.intValue) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex.intValue]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
            break;

        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex.intValue]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        default:
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    DDLogVerbose(@"[HistoryTVC][controller didChangeObject] %lu/%lu %lu %lu/%lu",
                 indexPath.section, indexPath.row,
                 (unsigned long)type,
                 newIndexPath.section, newIndexPath.row);

    NSMutableDictionary *d = [@{@"type": @(type)}
                              mutableCopy];
    if (indexPath) {
        d[@"indexPath"] = indexPath;
    }
    if (newIndexPath) {
        d[@"newIndexPath"] = newIndexPath;
    }
    [self performSelectorOnMainThread:@selector(didChangeObject:) withObject:d waitUntilDone:TRUE];
}

- (void)didChangeObject:(NSDictionary *)d {
    NSNumber *type = d[@"type"];
    NSIndexPath *indexPath = d[@"indexPath"];
    NSIndexPath *newIndexPath = d[@"newIndexPath"];

    DDLogVerbose(@"[HistoryTVC][didChangeObject] %lu/%lu %@ %lu/%lu %lu",
                 indexPath.section, indexPath.row,
                 type,
                 newIndexPath.section, newIndexPath.row,
                 [self.tableView numberOfRowsInSection:0]);

    switch(type.intValue) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            break;

        case NSFetchedResultsChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            break;

        case NSFetchedResultsChangeUpdate:
            [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            break;

        case NSFetchedResultsChangeMove:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    DDLogVerbose(@"[HistoryTVC][controllerDidChangeContent]");
    [self performSelectorOnMainThread:@selector(endUpdates) withObject:nil waitUntilDone:TRUE];
}

- (void)endUpdates {
    DDLogVerbose(@"[HistoryTVC][endUpdates]");
    [self.tableView endUpdates];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    History *history = [self.fetchedResultsController objectAtIndexPath:indexPath];

    cell.textLabel.text = [NSString stringWithFormat:@"%c%@",
                           history.seen.boolValue ? ' ' : '*',
                           history.text];
    cell.detailTextLabel.text = history.timestampText;
}

@end
