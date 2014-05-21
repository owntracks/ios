//
//  LocationTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "LocationTVC.h"
#import "EditLocationTVC.h"
#import "Location+Create.h"
#import "PersonTVC.h"

@interface LocationTVC ()
@end

@implementation LocationTVC 

- (void)setFriend:(Friend *)friend
{
    _friend = friend;
    
    self.title = [friend name] ? [friend name] : friend.topic;
    
    if (friend && friend.managedObjectContext) {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Location"];
        
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"automatic" ascending:YES],
                                    [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO]];
        request.predicate = [NSPredicate predicateWithFormat:@"belongsTo = %@", friend];

        self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                            managedObjectContext:friend.managedObjectContext
                                                                              sectionNameKeyPath:@"automatic"
                                                                                       cacheName:nil];
    } else {
        self.fetchedResultsController = nil;
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"location"];
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
    
    cell.imageView.image = location.belongsTo.image ? [UIImage imageWithData:[location.belongsTo image]] : [UIImage imageNamed:@"TableView"];
    
    return cell;
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
    UITabBarController *tbc = self.tabBarController;
    NSArray *vcs = tbc.viewControllers;
    UINavigationController *nc = vcs[0];
    UIViewController *vc = nc.topViewController;
    
    
    if ([vc respondsToSelector:@selector(setCenter:)]) {
        [vc performSelector:@selector(setCenter:)
                 withObject:location];
        tbc.selectedIndex = 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if ([self numberOfSectionsInTableView:tableView] > 1) {
        return section ? @"Location Updates" : @"Waypoints and Regions";
    } else {
        return nil;
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Location *location = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [self.fetchedResultsController.managedObjectContext deleteObject:location];
    }
}

- (IBAction)setPerson:(UIStoryboardSegue *)segue {
    if ([segue.sourceViewController isKindOfClass:[PersonTVC class]]) {
        PersonTVC *personTVC = (PersonTVC *)segue.sourceViewController;
        [self.friend linkToAB:personTVC.person];
        [self.tableView reloadData];
        self.title = self.friend.name ? self.friend.name : self.friend.topic;
    }
}


@end
