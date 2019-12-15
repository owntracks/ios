//
//  FriendTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright © 2013 -2019 Christoph Krey. All rights reserved.
//

#import "OwnTracksAppDelegate.h"
#import "Settings.h"
#import "FriendsTVC.h"
#import "WaypointTVC.h"
#import "PersonTVC.h"
#import "Friend+CoreDataClass.h"
#import "FriendTableViewCell.h"
#import "Waypoint+CoreDataClass.h"
#import "CoreData.h"
#import "FriendAnnotationV.h"
#import "OwnTracking.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <Contacts/Contacts.h>

@interface FriendsTVC ()
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@end

@implementation FriendsTVC
static const DDLogLevel ddLogLevel = DDLogLevelInfo;

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    [[OwnTracking sharedInstance] addObserver:self
                                   forKeyPath:@"inQueue"
                                      options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                      context:nil];
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserverForName:@"reload"
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note){
                                                      self.fetchedResultsController = nil;
                                                  }];

    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    switch (status) {
        case CNAuthorizationStatusRestricted: {
            if (![[NSUserDefaults standardUserDefaults]
                  boolForKey:@"contactsAuthorization"]) {

                DDLogVerbose(@"CNAuthorizationStatus: CNAuthorizationStatusRestricted");
                UIAlertController *ac =
                [UIAlertController
                 alertControllerWithTitle:NSLocalizedString(@"Addressbook Access",
                                                            @"Headline in addressbook related error messages")
                 message:NSLocalizedString(@"has been restricted, possibly due to restrictions such as parental controls.",
                                           @"CNAuthorizationStatusRestricted")
                 preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *ok = [UIAlertAction
                                     actionWithTitle:NSLocalizedString(@"Continue",
                                                                       @"Continue button title")

                                     style:UIAlertActionStyleDefault
                                     handler:nil];
                [ac addAction:ok];
                [self presentViewController:ac animated:TRUE completion:nil];
                [[NSUserDefaults standardUserDefaults]
                 setBool:TRUE
                 forKey:@"contactsAuthorization"];
            }
            break;
        }
            
        case CNAuthorizationStatusDenied: {
            if (![[NSUserDefaults standardUserDefaults]
                  boolForKey:@"contactsAuthorization"]) {

                DDLogVerbose(@"CNAuthorizationStatus: CNAuthorizationStatusDenied");
                UIAlertController *ac =
                [UIAlertController
                 alertControllerWithTitle:NSLocalizedString(@"Addressbook Access",
                                                            @"Headline in addressbook related error messages")
                 message:NSLocalizedString(@"has been denied by user.\nIf you allow OwnTracks to access your contacts, you can link your devices to contacts.\nOwnTracks will then display the contact name and image instead of the device Id.\nNo information of your address book will be uploaded to any server.\nGo to Settings/Privacy/Contacts to change",
                                           @"CNAuthorizationStatusDenied")
                 preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *ok = [UIAlertAction
                                     actionWithTitle:NSLocalizedString(@"Continue",
                                                                       @"Continue button title")

                                     style:UIAlertActionStyleDefault
                                     handler:nil];
                [ac addAction:ok];
                [self presentViewController:ac animated:TRUE completion:nil];
                [[NSUserDefaults standardUserDefaults]
                 setBool:TRUE
                 forKey:@"contactsAuthorization"];
            }
            break;
        }
            
        case CNAuthorizationStatusAuthorized:
            DDLogVerbose(@"CNAuthorizationStatus: CNAuthorizationStatusAuthorized");
            break;

        case CNAuthorizationStatusNotDetermined:
        default:
            [[NSUserDefaults standardUserDefaults]
             setBool:FALSE
             forKey:@"contactsAuthorization"];

            DDLogVerbose(@"CNAuthorizationStatus: CNAuthorizationStatusNotDetermined");
            CNContactStore *contactStore = [[CNContactStore alloc] init];
            [contactStore requestAccessForEntityType:CNEntityTypeContacts
                                   completionHandler:^(BOOL granted, NSError * _Nullable error) {
                                       if (granted) {
                                           DDLogVerbose(@"requestAccessForEntityType granted");
                                       } else {
                                           DDLogVerbose(@"requestAccessForEntityType denied %@", error);
                                       }
                                   }];
            break;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    while (!self.fetchedResultsController) {
        //
    }
    [self.tableView reloadData];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    [self performSelectorOnMainThread:@selector(setBadge:)
                           withObject:[OwnTracking sharedInstance].inQueue
                        waitUntilDone:NO];
}

- (void)setBadge:(NSNumber *)number {
    unsigned long inQueue = number.unsignedLongValue;
    DDLogVerbose(@"inQueue %lu", inQueue);
    if (inQueue > 0) {
        (self.navigationController.tabBarItem).badgeValue = [NSString stringWithFormat:@"%lu", inQueue];
    } else {
        [self.navigationController.tabBarItem setBadgeValue:nil];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSIndexPath *indexPath = nil;
    
    if ([sender isKindOfClass:[UITableViewCell class]]) {
        indexPath = [self.tableView indexPathForCell:sender];
    }
    
    if (indexPath) {
        Friend *friend = [self.fetchedResultsController objectAtIndexPath:indexPath];

        if ([segue.identifier isEqualToString:@"showWaypointFromFriends"]) {
            if ([segue.destinationViewController respondsToSelector:@selector(setWaypoint:)]) {
                Waypoint *waypoint = friend.newestWaypoint;
                if (waypoint) {
                    [segue.destinationViewController performSelector:@selector(setWaypoint:) withObject:waypoint];
                }
            }
        }

    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
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
        [vc performSelector:@selector(setCenter:) withObject:friend];
        if (tbc) {
            tbc.selectedIndex = 0;
        }
    }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (self.fetchedResultsController).sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = (self.fetchedResultsController).sections[section];
    if (sectionInfo.numberOfObjects == 0) {
        [self empty];
    } else {
        [self nonempty];
    }
    return sectionInfo.numberOfObjects;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
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
        NSManagedObjectContext *context = (self.fetchedResultsController).managedObjectContext;
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        Friend *friend = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [delegate sendEmpty:friend.topic];
        [context deleteObject:friend];
        
        NSError *error = nil;
        if (![context save:&error]) {
            DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
        }
    }
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Friend"
                                              inManagedObjectContext:CoreData.sharedInstance.mainMOC];
    fetchRequest.entity = entity;
    fetchRequest.fetchBatchSize = 20;

    int ignoreStaleLocations = [Settings intForKey:@"ignorestalelocations_preference"
                                             inMOC:CoreData.sharedInstance.mainMOC];
    if (ignoreStaleLocations) {
        NSTimeInterval stale = -ignoreStaleLocations * 24.0 * 3600.0;
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"lastLocation > %@",
                                  [NSDate dateWithTimeIntervalSinceNow:stale]];
    }

    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@"topic" ascending:YES];
    NSArray *sortDescriptors = @[sortDescriptor1];
    fetchRequest.sortDescriptors = sortDescriptors;
    
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc]
                                                             initWithFetchRequest:fetchRequest
                                                             managedObjectContext:CoreData.sharedInstance.mainMOC
                                                             sectionNameKeyPath:nil
                                                             cacheName:nil];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
    NSError *error = nil;
    if (![self.fetchedResultsController performFetch:&error]) {
        DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    
    return _fetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self performSelectorOnMainThread:@selector(beginUpdates) withObject:nil waitUntilDone:TRUE];
}

- (void)beginUpdates {
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
    [self performSelectorOnMainThread:@selector(endUpdates) withObject:nil waitUntilDone:TRUE];
}

- (void)endUpdates {
    [self.tableView endUpdates];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    FriendTableViewCell *friendTableViewCell = (FriendTableViewCell *)cell;
    
    Friend *friend = [self.fetchedResultsController objectAtIndexPath:indexPath];

    friendTableViewCell.name.text = friend.name ? friend.name : friend.tid;
    
    FriendAnnotationV *friendAnnotationView = [[FriendAnnotationV alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    friendAnnotationView.personImage = friend.image ? [UIImage imageWithData:friend.image] : nil;
    friendAnnotationView.me = [friend.topic isEqualToString:[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC]];
    friendAnnotationView.tid = friend.effectiveTid;

    Waypoint *waypoint = friend.newestWaypoint;
    if (waypoint) {
        [friendTableViewCell deferredReverseGeoCode:waypoint];

        if (waypoint.placemark) {
            friendTableViewCell.address.text = waypoint.placemark;
        } else {
            DDLogVerbose(@"[FriendsTVC] configureCell resolving %@", waypoint);
            friendTableViewCell.address.text = NSLocalizedString(@"resolving...",
                                                                 @"temporary display while resolving address");
        }
        friendAnnotationView.speed = (waypoint.vel).doubleValue;
        friendAnnotationView.course = (waypoint.cog).doubleValue;
    } else {
        friendTableViewCell.address.text = @"";
        friendAnnotationView.speed = -1;
        friendAnnotationView.course = -1;
    }
    
    NSDateComponents *dateComponents = [[NSCalendar currentCalendar]
                                        components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
                                        fromDate:[NSDate date]];
    NSDate *thisMorning = [[NSCalendar currentCalendar] dateFromComponents:dateComponents];
    if ([waypoint.tst timeIntervalSinceDate:thisMorning] > 0) {
        friendTableViewCell.timestamp.text = [NSDateFormatter localizedStringFromDate:waypoint.tst
                                                                            dateStyle:NSDateFormatterNoStyle
                                                                            timeStyle:NSDateFormatterShortStyle];
    } else {
        friendTableViewCell.timestamp.text = [NSDateFormatter localizedStringFromDate:waypoint.tst
                                                                            dateStyle:NSDateFormatterShortStyle
                                                                            timeStyle:NSDateFormatterNoStyle];
    }

    friendTableViewCell.image.image = [friendAnnotationView getImage];
}

@end
