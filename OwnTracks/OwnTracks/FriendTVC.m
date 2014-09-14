//
//  FriendTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright (c) 2013, 2014 Christoph Krey. All rights reserved.
//

#import "OwnTracksAppDelegate.h"
#import "FriendTVC.h"
#import "LocationTVC.h"
#import "Friend+Create.h"
#import "Location+Create.h"
#import "CoreData.h"
#import "FriendAnnotationV.h"

@interface FriendTVC ()
@property (strong, nonatomic) UIAlertView *alertView;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@end

@implementation FriendTVC


- (void)viewDidLoad
{
    [super viewDidLoad];

    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    
#ifdef DEBUG
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
#endif
    
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
            NSLog(@"ABAddressBookGetAuthorizationStatus: kABAuthorizationStatusNotDetermined");
            ABAddressBookRef ab = ABAddressBookCreateWithOptions(NULL, NULL);
            ABAddressBookRequestAccessWithCompletion(ab, ^(bool granted, CFErrorRef error) {
#ifdef DEBUG
                if (granted) {
                    NSLog(@"ABAddressBookRequestAccessCompletionHandler granted");
                } else {
                    NSLog(@"ABAddressBookRequestAccessCompletionHandler denied");
                }
#endif
            });
            break;
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

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        Friend *friend = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [delegate sendEmpty:friend];

        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
        
        NSError *error = nil;
        if (![context save:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
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
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _fetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
        default:
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
#ifdef DEBUG
    NSLog(@"configureCell %@", indexPath);
#endif
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
