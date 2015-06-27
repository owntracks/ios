//
//  MessageTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 20.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "MessageTVC.h"
#import "OwnTracksAppDelegate.h"
#import "MEssage+Create.h"
#import "CoreData.h"
#import "MessageTableViewCell.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import <FontAwesomeTools/FontAwesome.h>
#import <FontAwesome/NSString+FontAwesome.h>

@interface MessageTVC ()
@property (strong, nonatomic) UIAlertView *alertView;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@property (strong, nonatomic) UIFont *fontAwesome;

@end

@implementation MessageTVC
static const DDLogLevel ddLogLevel = DDLogLevelError;

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    DDLogVerbose(@"ddLogLevel %lu", (unsigned long)ddLogLevel);
    self.fontAwesome = [FontAwesome fontWithSize:30.0f];
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate addObserver:self
               forKeyPath:@"inQueue"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:nil];
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.tableView.estimatedRowHeight = 150;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate.messaging addObserver:self
                         forKeyPath:@"lastGeoHash"
                            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                            context:nil];

    [Message expireMessages:[CoreData theManagedObjectContext]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.tableView reloadData];
    [self showCount];
}

- (void)viewWillDisappear:(BOOL)animated {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate.messaging removeObserver:self forKeyPath:@"lastGeoHash"];

    [super viewWillDisappear:animated];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    if (delegate.messaging.lastGeoHash) {
        self.title = [NSString stringWithFormat:@"Messaging - %@", delegate.messaging.lastGeoHash];
    }
    if ([CoreData theManagedObjectContext]) {
        [self showCount];
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    Message *message = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSURL *url = [NSURL URLWithString:message.url];
    DDLogError(@"openURL %@ %@", url, message.url);
    [[UIApplication sharedApplication] openURL:url];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.fetchedResultsController sections] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self.fetchedResultsController.sections[section] name];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"message" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        Message *message = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [context deleteObject:message];
        
        NSError *error = nil;
        if (![context save:&error]) {
            DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
            [[Crashlytics sharedInstance] setObjectValue:@"deleteMessage" forKey:@"CrashType"];
            [[Crashlytics sharedInstance] crash];
        }
    }
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Message"
                                              inManagedObjectContext:[CoreData theManagedObjectContext]];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchBatchSize:20];
    
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor1];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc]
                                                             initWithFetchRequest:fetchRequest
                                                             managedObjectContext:[CoreData theManagedObjectContext]
                                                             sectionNameKeyPath:nil
                                                             cacheName:nil];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
    NSError *error = nil;
    if (![self.fetchedResultsController performFetch:&error]) {
        DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
        [[Crashlytics sharedInstance] setObjectValue:@"fetchFriends" forKey:@"CrashType"];
        [[Crashlytics sharedInstance] crash];
    }
    
    return _fetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
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
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [tableView reloadRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
            [tableView insertRowsAtIndexPaths:@[newIndexPath]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
    [self showCount];
}

- (void)showCount {
    NSUInteger count = self.fetchedResultsController.fetchedObjects.count;
    if (count) {
        self.navigationController.tabBarItem.badgeValue = [NSString stringWithFormat:@"%lu",
                                                           (unsigned long)self.fetchedResultsController.fetchedObjects.count];
    } else {
        self.navigationController.tabBarItem.badgeValue = nil;
        
    }
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    DDLogVerbose(@"configureCell %ld/%ld", (long)indexPath.section, (long)indexPath.row);
    Message *message = [self.fetchedResultsController objectAtIndexPath:indexPath];
    MessageTableViewCell *messageTableViewCell = nil;
    if ([cell isKindOfClass:[MessageTableViewCell class]]) {
        messageTableViewCell = (MessageTableViewCell *)cell;
    }
    
    NSTimeInterval interval = -[message.timestamp timeIntervalSinceNow];
    NSString *intervalString;
    if (interval < 60) {
        intervalString = [NSString stringWithFormat:@"%0.fsec", interval];
    } else if (interval < 3600) {
        intervalString = [NSString stringWithFormat:@"%0.fmin", interval / 60];
    } else if (interval < 24 * 3600) {
        intervalString = [NSString stringWithFormat:@"%0.fh", interval / 3600];
    } else {
        intervalString = [NSString stringWithFormat:@"%0.fd", interval / (24 * 3600)];
    }
    
    if (messageTableViewCell) {
        messageTableViewCell.title.text = message.title;
        messageTableViewCell.info.text = [NSString stringWithFormat:@"@%@ in #%@ ttl=%lu",
                                          [NSDateFormatter localizedStringFromDate:message.timestamp
                                                                         dateStyle:NSDateFormatterShortStyle
                                                                         timeStyle:NSDateFormatterMediumStyle],
                                          message.channel,
                                          (unsigned long)[message.ttl unsignedIntegerValue]];
        messageTableViewCell.desc.text = message.desc;
        if (message.icon) {
            UIColor *color = [UIColor colorWithRed:71.0/255.0 green:141.0/255.0 blue:178.0/255.0 alpha:1.0];
            if ([message.prio intValue] == 1) {
                color = [UIColor orangeColor];
            } else if ([message.prio intValue] == 2) {
                color = [UIColor redColor];
            }
            UIImage *icon = [FontAwesome imageWithIcon:[NSString fontAwesomeIconStringForIconIdentifier:message.icon]
                                             iconColor:color
                                              iconSize:40.0f
                                             imageSize:CGSizeMake(44.0f, 44.0f)];
            messageTableViewCell.icon.image = icon;
        } else if (message.iconurl) {
            NSURL *iconurl = [NSURL URLWithString:message.iconurl];
            NSData *iconData = [NSData dataWithContentsOfURL:iconurl];
            messageTableViewCell.icon.image = [UIImage imageWithData:iconData];
        }
    }
    
    if (message.url) {
        cell.accessoryType = UITableViewCellAccessoryDetailButton;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
}

- (IBAction)trash:(UIBarButtonItem *)sender {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate.messaging reset:[CoreData theManagedObjectContext]];
    
}

@end
