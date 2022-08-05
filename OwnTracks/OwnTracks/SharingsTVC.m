//
//  SharingsTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.08.22.
//  Copyright © 2022 OwnTracks. All rights reserved.
//

#import "SharingsTVC.h"
#import "Shares.h"
#import "OwnTracksAppDelegate.h"
#import "CreateSharingTVC.h"
#import "StatusCell.h"

@interface SharingsTVC ()
@property (strong, nonatomic) UIRefreshControl *refreshControl;
@end

@implementation SharingsTVC
@dynamic refreshControl;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    self.emptyText = NSLocalizedString(@"No or empty sharings list received from Backend",
                                       @"No or empty sharings list received from Backend");
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.attributedTitle =
    [[NSAttributedString alloc]
     initWithString: NSLocalizedString(@"Fetching sharings list from Backend",
                                       @"Fetching sharings list from Backend")];
    [self.refreshControl addTarget:self
                            action:@selector(refresh)
                  forControlEvents:UIControlEventValueChanged];

    [self.tableView addSubview:self.refreshControl];
}

- (IBAction)refreshPressed:(UIBarButtonItem *)sender {
    [[Shares sharedInstance] refresh];
}

- (void)refresh {
    [[Shares sharedInstance] refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    Shares *shares = [Shares sharedInstance];
    [shares addObserver:self
             forKeyPath:@"timestamp"
                options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                context:nil];
    [shares addObserver:self
             forKeyPath:@"message"
                options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                context:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    Shares *shares = [Shares sharedInstance];
    [shares removeObserver:self
                forKeyPath:@"message"
                   context:nil];
    [shares removeObserver:self
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

- (IBAction)shareSaved:(UIStoryboardSegue *)segue {
    if ([segue.sourceViewController isKindOfClass:[CreateSharingTVC class]]) {
        CreateSharingTVC *createShareTVC = (CreateSharingTVC *)segue.sourceViewController;
        Share *share = [[Share alloc] init];
        share.label = createShareTVC.label.text;
        share.from = createShareTVC.from.date;
        share.to = createShareTVC.to.date;
        
        [[Shares sharedInstance] requestShare:share];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    Shares *shares = [Shares sharedInstance];
    if (shares.count == 0) {
        [self empty];
    } else {
        [self nonempty];
    }

    if (section == 0) {
        return shares.count;
    } else {
        return 1;
    }

}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"shareCell" forIndexPath:indexPath];

        Share *share = [[Shares sharedInstance] shareAtIndex:indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"%@",
                               share.label];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterShortStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@",
                                     [formatter stringFromDate:share.from],
                                     [formatter stringFromDate:share.to]];
        return cell;

    } else {
        StatusCell *statusCell = [tableView dequeueReusableCellWithIdentifier:@"statusCell" forIndexPath:indexPath];

        if ([[Shares sharedInstance].activity boolValue]) {
            [statusCell.activity startAnimating];
        } else {
            [statusCell.activity stopAnimating];
        }
        statusCell.label.text = [Shares sharedInstance].message;
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
        [[Shares sharedInstance] removeShareAtIndex:indexPath.row];
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
        Share *share = [[Shares sharedInstance] shareAtIndex:indexPath.row];
        if (share.uuid) {
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
    Share *share = [[Shares sharedInstance] shareAtIndex:indexPath.row];
    if (share.uuid) {
        UIPasteboard *generalPasteboard = [UIPasteboard generalPasteboard];
        [generalPasteboard setString:share.url];

        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [delegate.navigationController alert:NSLocalizedString(@"Response",
                                                               @"Alert message header for Request Response")
                                     message:[NSString stringWithFormat:@"%@ %@\n",
                                              NSLocalizedString(@"URL copied to Clipboard",
                                                                @"URL copied to Clipboard"),
                                              share.url]
                                dismissAfter:0.0
        ];
    }
}

- (NSString *)tableView:(UITableView *)tableView
titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return NSLocalizedString(@"Sharings", @"Sharings List Header");
    } else {
        return NSLocalizedString(@"Status", @"Sharings Status Header");
    }
}

@end
