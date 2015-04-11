//
//  FriendTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright (c) 2013-2015 Christoph Krey. All rights reserved.
//

#import "OwnTracksAppDelegate.h"
#import "FriendTVC.h"
#import "LocationTVC.h"
#import "Friend+Create.h"
#import "Location+Create.h"
#import "CoreData.h"
#import "FriendAnnotationV.h"

#ifdef DEBUG
#define DEBUGFRIEND FALSE
#else
#define DEBUGFRIEND FALSE
#endif

@interface FriendTVC ()
@property (strong, nonatomic) UIAlertView *alertView;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@end

@implementation FriendTVC

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate addObserver:self
               forKeyPath:@"inQueue"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:nil];
    
    return self;
}
- (void)viewDidLoad
{
    [super viewDidLoad];

    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    
    if (DEBUGFRIEND) {
        switch (status) {
            case kABAuthorizationStatusRestricted:
                NSLog(@"ABAddressBookGetAuthorizationStatus: kABAuthorizationStatusRestricted");
                break;
                
            case kABAuthorizationStatusDenied:
                NSLog(@"ABAddressBookGetAuthorizationStatus: kABAuthorizationStatusDenied");
                break;
                
            case kABAuthorizationStatusAuthorized:
                NSLog(@"ABAddressBookGetAuthorizationStatus: kABAuthorizationStatusAuthorized");
                break;
                
            case kABAuthorizationStatusNotDetermined:
            default:
                NSLog(@"ABAddressBookGetAuthorizationStatus: kABAuthorizationStatusNotDetermined");
                break;
        }
    }
    switch (status) {
        case kABAuthorizationStatusRestricted:
            self.alertView = [[UIAlertView alloc] initWithTitle:@"Addressbook Access"
                                                        message:@"has been restricted, possibly due to restrictions such as parental controls."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
            [self.alertView show];
            break;
            
        case kABAuthorizationStatusDenied:
            self.alertView = [[UIAlertView alloc] initWithTitle:@"Addressbook Access"
                                                        message:@"has been denied by user. Go to Settings/Privacy/Contacts to change"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
            [self.alertView show];
            break;
            
        case kABAuthorizationStatusAuthorized:
            break;
            
        case kABAuthorizationStatusNotDetermined:
        default:
            if (DEBUGFRIEND) NSLog(@"ABAddressBookGetAuthorizationStatus: kABAuthorizationStatusNotDetermined");
            ABAddressBookRef ab = ABAddressBookCreateWithOptions(NULL, NULL);
            ABAddressBookRequestAccessWithCompletion(ab, ^(bool granted, CFErrorRef error) {
                if (DEBUGFRIEND) {
                    if (granted) {
                        NSLog(@"ABAddressBookRequestAccessCompletionHandler granted");
                    } else {
                        NSLog(@"ABAddressBookRequestAccessCompletionHandler denied");
                    }
                }            });
            break;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [self performSelectorOnMainThread:@selector(setBadge:) withObject:delegate.inQueue waitUntilDone:NO];
}

- (void)setBadge:(NSNumber *)number {
    unsigned long inQueue = [number unsignedLongValue];
    if (DEBUGFRIEND) NSLog(@"inQueue %lu", inQueue);
    if (inQueue > 0) {
        [self.navigationController.tabBarItem setBadgeValue:[NSString stringWithFormat:@"%lu", inQueue]];
    } else {
        [self.navigationController.tabBarItem setBadgeValue:nil];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSIndexPath *indexPath = nil;
    
    if ([sender isKindOfClass:[UITableViewCell class]]) {
        indexPath = [self.tableView indexPathForCell:sender];
    }
    
    if (indexPath) {
        Friend *friend = [self.fetchedResultsController objectAtIndexPath:indexPath];

        if ([segue.identifier isEqualToString:@"setFriend:"]) {
            if ([segue.destinationViewController respondsToSelector:@selector(setFriend:)]) {
                [segue.destinationViewController performSelector:@selector(setFriend:) withObject:friend];
            }
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    Friend *friend = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    UITabBarController *tbc;
    UINavigationController *nc;

    if (self.splitViewController) {
        UISplitViewController *svc = self.splitViewController;
        nc = svc.viewControllers[1];
    } else {
        tbc = self.tabBarController;
        NSArray *vcs = tbc.viewControllers;
        nc = vcs[0];
    }
    
    UIViewController *vc = nc.topViewController;

    if ([vc respondsToSelector:@selector(setCenter:)]) {
        [vc performSelector:@selector(setCenter:)
                 withObject:[friend newestLocation]];
        if (tbc) {
            tbc.selectedIndex = 0;
        }
    }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"friend" forIndexPath:indexPath];
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
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        Friend *friend = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [delegate sendEmpty:friend.topic];
        [context deleteObject:friend];
        
        NSError *error = nil;
        if (![context save:&error]) {
            if (DEBUGFRIEND) NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
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
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Friend"
                                              inManagedObjectContext:[CoreData theManagedObjectContext]];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchBatchSize:20];
    
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@"topic" ascending:YES];
    
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
        if (DEBUGFRIEND) NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
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
    if (DEBUGFRIEND) NSLog(@"configureCell %ld/%ld", (long)indexPath.section, (long)indexPath.row);
    Friend *friend = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = friend.name ? friend.name : friend.topic;
    
    Location *location = [friend newestLocation];
    
    cell.detailTextLabel.text = location ? [location subtitle] : @"???";
    
    FriendAnnotationV *friendAnnotationView = [[FriendAnnotationV alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    friendAnnotationView.personImage = friend.image ? [UIImage imageWithData:friend.image] : nil;
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    friendAnnotationView.me = [friend.topic isEqualToString:[delegate.settings theGeneralTopic]];
    friendAnnotationView.automatic = [location.automatic boolValue];
    friendAnnotationView.speed = [location.speed doubleValue];
    friendAnnotationView.course = [location.course doubleValue];
    friendAnnotationView.tid = [friend getEffectiveTid];
    [friendAnnotationView getImage];
    cell.imageView.image = [friendAnnotationView getImage];
}

@end
