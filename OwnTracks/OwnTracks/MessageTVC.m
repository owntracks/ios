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
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

@interface MessageTVC ()
@property (strong, nonatomic) UIAlertView *alertView;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@end

@implementation MessageTVC
static const DDLogLevel ddLogLevel = DDLogLevelError;

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    DDLogVerbose(@"ddLogLevel %lu", (unsigned long)ddLogLevel);
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate.lbs addObserver:self
                   forKeyPath:@"lastGeoHash"
                      options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                      context:nil];
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate.lbs removeObserver:self forKeyPath:@"lastGeoHash"];
    [super viewWillDisappear:animated];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
    /*
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    self.title = delegate.lbs.lastGeoHash;
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:[LocationManager sharedInstance].location completionHandler:
     ^(NSArray *placemarks, NSError *error) {
         if ([placemarks count] > 0) {
             CLPlacemark *placemark = placemarks[0];
             NSArray *address = placemark.addressDictionary[@"FormattedAddressLines"];
             if (address && [address count] >= 1) {
                 self.title = address[0];
                 for (int i = 1; i < [address count]; i++) {
                     self.title = [NSString stringWithFormat:@"%@, %@", self.title, address[i]];
                 }
             }
         }
     }];
     */
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    Message *message = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSURL *url = [NSURL URLWithString:message.url];
    DDLogError(@"openURL %@ %@", url, message.url);
    [[UIApplication sharedApplication] openURL:url];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self.fetchedResultsController.sections[section] name];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
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
    
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@"channel" ascending:YES];
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor1, sortDescriptor2];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc]
                                                             initWithFetchRequest:fetchRequest
                                                             managedObjectContext:[CoreData theManagedObjectContext]
                                                             sectionNameKeyPath:@"channel"
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

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    DDLogVerbose(@"configureCell %ld/%ld", (long)indexPath.section, (long)indexPath.row);
    Message *message = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    double distanceDouble = [message.distance doubleValue];
    NSString *distanceString;
    if (distanceDouble > 1000.0) {
        distanceString = [NSString stringWithFormat:@"%.0fkm", distanceDouble / 1000.0];
    } else {
        distanceString = [NSString stringWithFormat:@"%.0fm", distanceDouble];
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

    cell.textLabel.text = [NSString stringWithFormat:@"%@ (%@/%@)", message.title, distanceString, intervalString];
    cell.detailTextLabel.text = message.desc;
    NSURL *iconurl = [NSURL URLWithString:message.iconurl];
    NSData *iconData = [NSData dataWithContentsOfURL:iconurl];
    cell.imageView.image = [UIImage imageWithData:iconData];
}

- (IBAction)trash:(UIBarButtonItem *)sender {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate.lbs reset:[CoreData theManagedObjectContext]];
}

@end
