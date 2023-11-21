//
//  LogsTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 14.11.23.
//  Copyright © 2023 OwnTracks. All rights reserved.
//

#import "LogsTVC.h"

#import "OwnTracksAppDelegate.h"

#import <CocoaLumberjack/CocoaLumberjack.h>

@interface LogsTVC ()
@property (weak, nonatomic) IBOutlet UIBarButtonItem *actionButton;

@property (strong, nonatomic) UIDocumentInteractionController *dic;

@end

@implementation LogsTVC

static const DDLogLevel ddLogLevel = DDLogLevelInfo;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidAppear:(BOOL)animated {
    self.actionButton.enabled = FALSE;
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    DDLogVerbose(@"[LogsTVC] #logs:%lu max#:%lu]",
                 (unsigned long)ad.fl.logFileManager.sortedLogFileInfos.count,
                 (unsigned long)ad.fl.logFileManager.maximumNumberOfLogFiles);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    return ad.fl.logFileManager.sortedLogFileInfos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LogCell" forIndexPath:indexPath];

    cell.textLabel.text = ad.fl.logFileManager.sortedLogFileInfos[indexPath.row].fileName;

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Size: %llu - Created: %@",
                                 ad.fl.logFileManager.sortedLogFileInfos[indexPath.row].fileSize,
                                 [formatter stringFromDate:ad.fl.logFileManager.sortedLogFileInfos[indexPath.row].creationDate]];
    return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.actionButton.enabled = TRUE;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/
- (IBAction)actionPressed:(UIBarButtonItem *)sender {
    NSIndexPath *indexPath = self.tableView.indexPathForSelectedRow;
    
    if (!indexPath) {
        return;
    }
    
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    NSURL *fileURL =
    [NSURL fileURLWithPath:ad.fl.logFileManager.sortedLogFilePaths[indexPath.row]];
    
#if TARGET_OS_MACCATALYST
    if (@available(macCatalyst 14.0, *)) {
        UIDocumentPickerViewController *dpvc =
        [[UIDocumentPickerViewController alloc] initForExportingURLs:@[fileURL] asCopy:TRUE];
        dpvc.shouldShowFileExtensions = TRUE;
        [self presentViewController:dpvc animated:TRUE completion:^{
            //
        }];
    } else {
        UIAlertController *ac = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"Export", @"Export")
                                 message:NSLocalizedString(@"Mac Catalyst does not support export yet",
                                                           @"content of an alert message regarging missing Mac Catalyst Export")
                                 preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *ok = [UIAlertAction
                             actionWithTitle:NSLocalizedString(@"Continue",
                                                               @"Continue button title")
                             
                             style:UIAlertActionStyleDefault
                             handler:nil];
        [ac addAction:ok];
        [self presentViewController:ac animated:TRUE completion:nil];
    }
#else

    self.dic = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    self.dic.delegate = self;

    [self.dic presentOptionsMenuFromRect:self.navigationController.navigationBar.frame inView:self.tableView animated:TRUE];
#endif
}

@end
