//
//  LocationTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright (c) 2013-2015 Christoph Krey. All rights reserved.
//

#import "LocationTVC.h"
#import "EditLocationTVC.h"
#import "Location+Create.h"
#import "PersonTVC.h"
#import "FriendAnnotationV.h"
#import "OwnTracksAppDelegate.h"

#ifdef DEBUG
#define DEBUGLOC FALSE
#else
#define DEBUGLOC FALSE
#endif

@interface LocationTVC ()

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@end

@implementation LocationTVC

- (void)viewDidLoad {
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self
                            action:@selector(commandReportLocation)
                  forControlEvents:UIControlEventValueChanged];

}

- (void)commandReportLocation
{
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate requestLocationFromFriend:self.friend];

    [self.refreshControl endRefreshing];
}

- (void)setFriend:(Friend *)friend
{
    if (_friend != friend) {
        _friend = friend;
    }
    self.title = [self.friend name] ? [self.friend name] : self.friend.topic;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSIndexPath *indexPath = nil;
    
    if ([sender isKindOfClass:[UITableViewCell class]]) {
        indexPath = [self.tableView indexPathForCell:sender];
    }
    
    if (indexPath) {
        if ([segue.identifier isEqualToString:@"setLocation:"]) {
            Location *location = [self.fetchedResultsController objectAtIndexPath:indexPath];
            if ([segue.destinationViewController respondsToSelector:@selector(setLocation:)]) {
                [segue.destinationViewController performSelector:@selector(setLocation:) withObject:location];
            }
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    Location *location = [self.fetchedResultsController objectAtIndexPath:indexPath];
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
                 withObject:location];
        if (tbc) {
            tbc.selectedIndex = 0;
        }
    }
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return [self.fetchedResultsController sectionForSectionIndexTitle:title atIndex:index];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return section ? @"Location Updates" : @"Waypoints and Regions";
}

- (IBAction)setPerson:(UIStoryboardSegue *)segue {
    if ([segue.sourceViewController isKindOfClass:[PersonTVC class]]) {
        PersonTVC *personTVC = (PersonTVC *)segue.sourceViewController;
        [self.friend linkToAB:personTVC.person];
        [self.tableView reloadData];
        self.title = self.friend.name ? self.friend.name : self.friend.topic;
    }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (DEBUGLOC) NSLog(@"numberOfSectionsInTableView=%lu", (unsigned long)[[self.fetchedResultsController sections] count]);
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    if (DEBUGLOC) NSLog(@"numberOfRowsInSection %ld=%lu", (long)section, (unsigned long)[sectionInfo numberOfObjects]);
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"location" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
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
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Location"
                                              inManagedObjectContext:self.friend.managedObjectContext];
    [fetchRequest setEntity:entity];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"belongsTo = %@", self.friend];
    
    [fetchRequest setFetchBatchSize:20];
    
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@"automatic" ascending:YES];
    NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO];
    
    NSArray *sortDescriptors = @[sortDescriptor1, sortDescriptor2];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc]
                                                             initWithFetchRequest:fetchRequest
                                                             managedObjectContext:self.friend.managedObjectContext
                                                             sectionNameKeyPath:@"automatic"
                                                             cacheName:nil];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
    NSError *error = nil;
    if (![self.fetchedResultsController performFetch:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    if (DEBUGLOC) NSLog(@"fetchedResultsControllser %@", _fetchedResultsController);
    return _fetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    if (DEBUGLOC) NSLog(@"didChangeSection atIndex:%lu forChangeType:%lu ", (unsigned long)sectionIndex, (unsigned long)type);
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
    if (DEBUGLOC) NSLog(@"didChangeObject:%@ atIndexPath:%ld/%ld forChangeType:%lu newIndexPath:%ld/%ld",
          anObject,
          (long)indexPath.section, (long)indexPath.row,
          (unsigned long)type,
          (long)newIndexPath.section, (long)newIndexPath.row);
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            if (newIndexPath) {
                [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            }
            break;
            
        case NSFetchedResultsChangeDelete:
            if (indexPath) {
                [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            }
            break;
            
        case NSFetchedResultsChangeUpdate:
            if (newIndexPath) {
                [self configureCell:[tableView cellForRowAtIndexPath:newIndexPath] atIndexPath:newIndexPath];
            }
            break;
            
        case NSFetchedResultsChangeMove:
            if (indexPath && newIndexPath) {
                [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            }
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    if (DEBUGLOC) NSLog(@"configureCell %ld/%ld", (long)indexPath.section, (long)indexPath.row);
    Location *location = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    UIFont *fontBold = [UIFont boldSystemFontOfSize:[UIFont systemFontSize] + 2];
    NSDictionary *attributesBold = [NSDictionary dictionaryWithObject:fontBold
                                                               forKey:NSFontAttributeName];
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc]
                                     initWithString:(![location.automatic boolValue] && location.remark) ? location.remark :
                                     location.timestamp ?
                                     [NSDateFormatter localizedStringFromDate:location.timestamp
                                                                    dateStyle:NSDateFormatterShortStyle
                                                                    timeStyle:NSDateFormatterMediumStyle] : @"???"
                                     attributes:attributesBold];
    
    if (![location.automatic boolValue]) {
        UIFont *fontLight = [UIFont systemFontOfSize:[UIFont smallSystemFontSize]];
        NSDictionary *attributesLight = [NSDictionary dictionaryWithObject:fontLight
                                                                    forKey:NSFontAttributeName];
        
        [as appendAttributedString:[[NSAttributedString alloc]
                                    initWithString:[NSString stringWithFormat:@": %@ %@",
                                                    location.regionradius,
                                                    [location sharedWaypoint] ? @"✔︎" : @"✘"]
                                    attributes:attributesLight]];
    }
    cell.textLabel.attributedText = as;
    
    cell.detailTextLabel.text = [location locationText];
    
    FriendAnnotationV *friendAnnotationView = [[FriendAnnotationV alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    friendAnnotationView.personImage = self.friend.image ? [UIImage imageWithData:self.friend.image] : nil;
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    friendAnnotationView.me = [self.friend.topic isEqualToString:[delegate.settings theGeneralTopic]];
    friendAnnotationView.automatic = [location.automatic boolValue];
    friendAnnotationView.speed = [location.speed doubleValue];
    friendAnnotationView.course = [location.course doubleValue];
    friendAnnotationView.tid = [self.friend getEffectiveTid];
    [friendAnnotationView getImage];
    cell.imageView.image = [friendAnnotationView getImage];
}

@end
