//
//  MessageTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 20.06.15.
//  Copyright © 2015-2016 OwnTracks. All rights reserved.
//

#import "MessageTVC.h"
#import "OwnTracksAppDelegate.h"
#import "Message+Create.h"
#import "CoreData.h"
#import "MessageTableViewCell.h"
#import "UIColor+WithName.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import "FontAwesome.h"

@interface MessageTVC ()
@property (strong, nonatomic) UIAlertView *alertView;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@end

@implementation MessageTVC
static const DDLogLevel ddLogLevel = DDLogLevelError;

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    [[Messaging sharedInstance] addObserver:self
                                 forKeyPath:@"messages"
                                    options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                    context:nil];
    
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    [[Messaging sharedInstance] updateCounter:[CoreData theManagedObjectContext]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.tableView reloadData];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    [self performSelectorOnMainThread:@selector(setBadge) withObject:nil waitUntilDone:NO];
}

- (void)setBadge {
    NSUInteger count = [[Messaging sharedInstance].messages unsignedIntValue];
    DDLogVerbose(@"count %lu", (unsigned long)count);
    if (count > 0) {
        [self.navigationController.tabBarItem setBadgeValue:[NSString stringWithFormat:@"%lu", (unsigned long)count]];
    } else {
        [self.navigationController.tabBarItem setBadgeValue:nil];
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    Message *message = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSURL *url = [NSURL URLWithString:message.url];
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

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        Message *message = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [context deleteObject:message];
        [CoreData saveContext:context];
        [[Messaging sharedInstance] updateCounter:context];
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
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    Message *message = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (message.title.length + message.desc.length < 100) {
        return 128;
    } else {
        return 256;
    }
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    Message *message = [self.fetchedResultsController objectAtIndexPath:indexPath];
    MessageTableViewCell *messageTableViewCell = nil;
    if ([cell isKindOfClass:[MessageTableViewCell class]]) {
        messageTableViewCell = (MessageTableViewCell *)cell;
    }
    
    if (messageTableViewCell) {
        messageTableViewCell.info.text = [NSString stringWithFormat:@"@%@ in #%@ ttl=%lu",
                                          [NSDateFormatter localizedStringFromDate:message.timestamp
                                                                         dateStyle:NSDateFormatterShortStyle
                                                                         timeStyle:NSDateFormatterMediumStyle],
                                          message.channel,
                                          [message.ttl unsignedLongValue]];
        
        messageTableViewCell.webView.delegate = self;
        [messageTableViewCell.webView loadHTMLString:[NSString stringWithFormat:@"<p><strong>%@</strong></p>\n%@",
                                                      message.title,
                                                      message.desc]
                                             baseURL:[NSURL URLWithString:@""]];
        
        messageTableViewCell.icon.image = nil;
        messageTableViewCell.label.text = nil;
        messageTableViewCell.label.backgroundColor = [UIColor clearColor];
        
        if (message.icon) {
            UIColor *color = [UIColor colorWithName:[NSString stringWithFormat:@"priority%d", [message.prio intValue]]
                                       defaultColor:[UIColor blackColor]];            
            NSString *iconCode = [FontAwesome codeFromName:message.icon];
            messageTableViewCell.label.backgroundColor = color;
            messageTableViewCell.label.textColor = [UIColor whiteColor];
            messageTableViewCell.label.text = iconCode;
        
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

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    DDLogVerbose(@"webViewDidFinishLoad %@", webView);
}

- (IBAction)trash:(UIBarButtonItem *)sender {
    [[Messaging sharedInstance] reset:[CoreData theManagedObjectContext]];
}

@end
