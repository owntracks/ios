//
//  SharesTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.08.22.
//  Copyright © 2022 OwnTracks. All rights reserved.
//

#import "SharesTVC.h"
#import "Shares.h"
#import "OwnTracksAppDelegate.h"

@interface SharesTVC ()
@property (strong, nonatomic) UIRefreshControl *refreshControl;
@end

@implementation SharesTVC
@dynamic refreshControl;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self
                            action:@selector(refresh)
                  forControlEvents:UIControlEventValueChanged];

    [self.tableView addSubview:self.refreshControl];
}

- (void)refresh {
    [[Shares sharedInstance] refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    Shares *shares = [Shares sharedInstance];
    [shares addObserver:self
             forKeyPath:@"timestamp"
                options:NSKeyValueObservingOptionNew
                context:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    Shares *shares = [Shares sharedInstance];
    [shares removeObserver:self
                forKeyPath:@"timestamp"
                   context:nil];
    [super viewWillDisappear:animated];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    [self.refreshControl endRefreshing];
    [self performSelectorOnMainThread:@selector(update)
                           withObject:nil
                        waitUntilDone:NO];
}

- (void)update {
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    Shares *shares = [Shares sharedInstance];
    return shares.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
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
}

- (BOOL)tableView:(UITableView *)tableView
canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
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
    Share *share = [[Shares sharedInstance] shareAtIndex:indexPath.row];
    if (share.uuid) {
        return indexPath;
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
                                     message:[NSString stringWithFormat:@"URL copied to Clipboard %@\n",
                                              share.url]
                                dismissAfter:0.0
        ];
    }
}
@end
