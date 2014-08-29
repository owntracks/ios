//
//  FriendTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
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

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Friend"];
    
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"topic" ascending:YES]];
    request.includesSubentities = YES;
    
    if ([CoreData theManagedObjectContext]) {
        self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                            managedObjectContext:[CoreData theManagedObjectContext]
                                                                              sectionNameKeyPath:nil
                                                                                       cacheName:nil];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"friend"];
    
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
    
    return cell;
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

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Friend *friend = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [self.fetchedResultsController.managedObjectContext deleteObject:friend];
        
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [delegate sendEmpty:friend];
    }
}

@end
