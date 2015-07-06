//
//  CertificatesTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.07.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "CertificatesTVC.h"

@interface CertificatesTVC ()
@property (strong, nonatomic) NSMutableArray *contents;
@property (strong, nonatomic) NSString *path;
@end

@implementation CertificatesTVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSArray *)contents {
    if (!_contents) {
        
        NSError *error;
        NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                     inDomain:NSUserDomainMask
                                                            appropriateForURL:nil
                                                                       create:YES
                                                                        error:&error];
        self.path = directoryURL.path;
        _contents =[[[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.path error:&error] mutableCopy];

    }
    return _contents;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return self.contents.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"certificate" forIndexPath:indexPath];
    
    NSString *file = self.contents[indexPath.row];
    cell.textLabel.text = file;
    
    if (self.selectedFileName && [file isEqualToString:self.selectedFileName]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSString *fileToDelete = self.contents[indexPath.row];
        NSString *pathToDelete = [self.path stringByAppendingPathComponent:fileToDelete];
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:pathToDelete error:&error];
        [self.contents removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *selectedFile = self.contents[indexPath.row];
    if ([self.selectedFileName isEqualToString:selectedFile]) {
        self.selectedFileName = @"";
    } else {
        self.selectedFileName = selectedFile;
    }
    return indexPath;
}

@end
