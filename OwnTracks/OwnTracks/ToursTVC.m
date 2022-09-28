//
//  ToursTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.08.22.
//  Copyright © 2022 OwnTracks. All rights reserved.
//

#import "ToursTVC.h"
#import "Tours.h"
#import "OwnTracksAppDelegate.h"
#import "CreateTourTVC.h"
#import "ToursStatusCell.h"

@interface ToursTVC ()
@property (strong, nonatomic) UIRefreshControl *refreshControl;
@end

@implementation ToursTVC
@dynamic refreshControl;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    self.emptyText = NSLocalizedString(@"No or empty tour list received from backend",
                                       @"No or empty tour list received from backend");
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.attributedTitle =
    [[NSAttributedString alloc]
     initWithString: NSLocalizedString(@"Fetching tour list from backend",
                                       @"Fetching tour list from backend")];
    [self.refreshControl addTarget:self
                            action:@selector(refresh)
                  forControlEvents:UIControlEventValueChanged];

    [self.tableView addSubview:self.refreshControl];
}

- (IBAction)refreshPressed:(UIBarButtonItem *)sender {
    [[Tours sharedInstance] refresh];
}

- (void)refresh {
    [[Tours sharedInstance] refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    Tours *tours = [Tours sharedInstance];
    [tours addObserver:self
             forKeyPath:@"timestamp"
                options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                context:nil];
    [tours addObserver:self
             forKeyPath:@"message"
                options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                context:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    Tours *tours = [Tours sharedInstance];
    [tours removeObserver:self
                forKeyPath:@"message"
                   context:nil];
    [tours removeObserver:self
                forKeyPath:@"timestamp"
                   context:nil];
    [super viewWillDisappear:animated];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    [self performSelectorOnMainThread:@selector(update)
                           withObject:nil
                        waitUntilDone:NO];
}

- (void)update {
    [self.refreshControl endRefreshing];
    [self.tableView reloadData];
}

- (IBAction)tourSaved:(UIStoryboardSegue *)segue {
    if ([segue.sourceViewController isKindOfClass:[CreateTourTVC class]]) {
        CreateTourTVC *createTourTVC = (CreateTourTVC *)segue.sourceViewController;
        Tour *tour = [[Tour alloc] init];
        tour.label = createTourTVC.label.text;
        tour.from = createTourTVC.from.date;
        tour.to = createTourTVC.to.date;
        
        [[Tours sharedInstance] requestTour:tour];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    Tours *tours = [Tours sharedInstance];
    if (tours.count == 0) {
        [self empty];
    } else {
        [self nonempty];
    }

    if (section == 0) {
        return tours.count;
    } else {
        return 1;
    }

}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TourCell" forIndexPath:indexPath];

        Tour *tour = [[Tours sharedInstance] tourAtIndex:indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"%@",
                               tour.label];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterShortStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@",
                                     [formatter stringFromDate:tour.from],
                                     [formatter stringFromDate:tour.to]];
        return cell;

    } else {
        ToursStatusCell *statusCell = [tableView dequeueReusableCellWithIdentifier:@"ToursStatusCell" forIndexPath:indexPath];

        if ([[Tours sharedInstance].activity boolValue]) {
            [statusCell.activity startAnimating];
        } else {
            [statusCell.activity stopAnimating];
        }
        statusCell.label.text = [Tours sharedInstance].message;
        return statusCell;
    }
}

- (BOOL)tableView:(UITableView *)tableView
canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return YES;
    } else {
        return NO;
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [[Tours sharedInstance] removeTourAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (NSIndexPath *)tableView:(UITableView *)tableView
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        Tour *tour = [[Tours sharedInstance] tourAtIndex:indexPath.row];
        if (tour.uuid) {
            return indexPath;
        } else {
            return nil;
        }
    } else {
        return nil;
    }
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Tour *tour = [[Tours sharedInstance] tourAtIndex:indexPath.row];
    if (tour.uuid) {
        UIPasteboard *generalPasteboard = [UIPasteboard generalPasteboard];
        [generalPasteboard setString:tour.url];

        OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [ad.navigationController alert:
             NSLocalizedString(@"Copied",
                               @"Alert message header for copy")
                               message:
             [NSString stringWithFormat:@"%@ %@\n",
              NSLocalizedString(@"URL copied to Clipboard",
                                @"URL copied to Clipboard"),
              tour.url]
                                   url:tour.url
        ];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:TRUE];
}

- (NSString *)tableView:(UITableView *)tableView
titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return NSLocalizedString(@"Tours", @"Tour list header");
    } else {
        return NSLocalizedString(@"Tours status", @"Tours status header");
    }
}

@end
