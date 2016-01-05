//
//  RegionsTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright © 2013-2016 Christoph Krey. All rights reserved.
//

#import "RegionsTVC.h"
#import "WaypointTVC.h"
#import "Region+Create.h"
#import "RegionTVC.h"
#import "CoreData.h"
#import "Settings.h"
#import "AlertView.h"
#import "OwnTracksAppDelegate.h"
#import "OwnTracking.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

@interface RegionsTVC ()

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

@end

@implementation RegionsTVC
static const DDLogLevel ddLogLevel = DDLogLevelError;

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
    [super viewWillAppear:animated];
    [self reset];
}

- (void)reset {
    self.fetchedResultsController = nil;
    if (self.tableView) {
        [self.tableView reloadData];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSIndexPath *indexPath = nil;
    
    if ([sender isKindOfClass:[UITableViewCell class]]) {
        indexPath = [self.tableView indexPathForCell:sender];
    }
    
    if (indexPath) {
        if ([segue.identifier isEqualToString:@"setRegion:"]) {
            Region *region = [self.fetchedResultsController objectAtIndexPath:indexPath];
            if ([segue.destinationViewController respondsToSelector:@selector(setEditRegion:)]) {
                [segue.destinationViewController performSelector:@selector(setEditRegion:) withObject:region];
            }
        }
    }
    
    if ([segue.identifier isEqualToString:@"newRegion:"]) {
        Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopic] inManagedObjectContext:[CoreData theManagedObjectContext]];
        CLLocation *location = [LocationManager sharedInstance].location;
        Region *newRegion = [[OwnTracking sharedInstance] addRegionFor:friend
                                                                  name:[NSString stringWithFormat:@"Here-%d",
                                                                        (int)[[NSDate date] timeIntervalSince1970]]
                                                                  uuid:nil
                                                                 major:0
                                                                 minor:0
                                                                 share:NO
                                                                radius:0
                                                                   lat:location.coordinate.latitude
                                                                   lon:location.coordinate.longitude
                                                               context:[CoreData theManagedObjectContext]];
        if ([segue.destinationViewController respondsToSelector:@selector(setEditRegion:)]) {
            [segue.destinationViewController performSelector:@selector(setEditRegion:) withObject:newRegion];
        }
    }
}

- (IBAction)addPressed:(UIBarButtonItem *)sender {
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"region" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    Region *region = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
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
        [vc performSelector:@selector(setCenter:) withObject:region];
        if (tbc) {
            tbc.selectedIndex = 0;
        }
    }
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        Region *region = [self.fetchedResultsController objectAtIndexPath:indexPath];
        if (region) {
            [[OwnTracking sharedInstance] removeRegion:region context:context];
            [CoreData saveContext:context];
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}



#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    Friend *friend = [Friend existsFriendWithTopic:[Settings theGeneralTopic]
                            inManagedObjectContext:[CoreData theManagedObjectContext]];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Region"
                                              inManagedObjectContext:[CoreData theManagedObjectContext]];
    [fetchRequest setEntity:entity];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"belongsTo = %@", friend];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
    NSArray *sortDescriptors = @[sortDescriptor];
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
        [[Crashlytics sharedInstance] setObjectValue:@"fetchRegions" forKey:@"CrashType"];
        [[Crashlytics sharedInstance] crash];
    }
    
    DDLogVerbose(@"fetchedResultsControllser %@", _fetchedResultsController);
    return _fetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type {
    DDLogVerbose(@"didChangeSection atIndex:%lu forChangeType:%lu ", (unsigned long)sectionIndex, (unsigned long)type);
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
      newIndexPath:(NSIndexPath *)newIndexPath {
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

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    Region *region = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    cell.textLabel.text = region.name;
    cell.detailTextLabel.text = region.subtitle;
    
    if  ([region.CLregion isKindOfClass:[CLCircularRegion class]]) {
        if ([[LocationManager sharedInstance] insideCircularRegion:region.CLregion.identifier]) {
            cell.imageView.image = [UIImage imageNamed:@"RegionHot"];
        } else {
            cell.imageView.image = [UIImage imageNamed:@"RegionCold"];
        }
    } else if ([region.CLregion isKindOfClass:[CLBeaconRegion class]]){
        if ([[LocationManager sharedInstance] insideBeaconRegion:region.CLregion.identifier]) {
            cell.imageView.image = [UIImage imageNamed:@"iBeaconHot"];
        } else {
            cell.imageView.image = [UIImage imageNamed:@"iBeaconCold"];
        }
    } else {
        cell.imageView.image = [UIImage imageNamed:@"Friend"];
    }
}

@end
