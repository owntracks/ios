//
//  CertificatesTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.07.15.
//  Copyright © 2015-2022  OwnTracks. All rights reserved.
//

#import "CertificatesTVC.h"

@interface CertificatesTVC ()
@property (strong, nonatomic) NSMutableArray *contents;
@property (strong, nonatomic) NSString *path;
@end

@implementation CertificatesTVC

- (NSArray *)contents {
    if (!_contents) {
        
        NSError *error;
        NSURL *directoryURL = [[NSFileManager defaultManager]
                               URLForDirectory:NSDocumentDirectory
                               inDomain:NSUserDomainMask
                               appropriateForURL:nil
                               create:YES
                               error:&error];
        self.path = directoryURL.path;
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.path error:&error];
        _contents = [[NSMutableArray alloc] init];
        for (NSString *file in contents) {
            if (([self.fileNameIdentifier isEqualToString:@"clientpkcs"] &&
                 [file.pathExtension isEqualToString:@"otrp"]) ||
                ([self.fileNameIdentifier isEqualToString:@"servercer"] &&
                 [file.pathExtension isEqualToString:@"otre"])) {
                    NSString *path = [self.path stringByAppendingPathComponent:file];
                    BOOL directory;
                    if ([[NSFileManager defaultManager] fileExistsAtPath:path
                                                             isDirectory:&directory] &&
                        !directory) {
                        [_contents addObject:file];
                    }
            }
        }

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
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    NSString *file = self.contents[indexPath.row];
    cell.textLabel.text = file;
    
    NSArray *fileNames = [self.selectedFileNames componentsSeparatedByString:@" "];
    for (NSString *name in fileNames) {
        if ([name isEqualToString:file]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            break;
        }
    }
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSString *fileToDelete = self.contents[indexPath.row];
        
        NSMutableArray *fileNames = [[self.selectedFileNames componentsSeparatedByString:@" "] mutableCopy];
        for (NSString *name in fileNames) {
            if ([name isEqualToString:fileToDelete]) {
                [fileNames removeObject:fileToDelete];
                break;
            }
        }
        self.selectedFileNames = @"";
        if (fileNames.count > 0) {
            self.selectedFileNames = fileNames[0];
            for (int i = 1; i < fileNames.count; i++) {
                self.selectedFileNames = [self.selectedFileNames stringByAppendingFormat:@" %@", fileNames[i]];
            }
        }
        
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

- (NSIndexPath *)tableView:(UITableView *)tableView
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *file = self.contents[indexPath.row];

    NSString *found = nil;
    NSMutableArray *fileNames = [[NSMutableArray alloc] init];
    if (self.selectedFileNames && self.selectedFileNames.length) {
        fileNames = [[self.selectedFileNames componentsSeparatedByString:@" "] mutableCopy];
    }
    for (NSString *name in fileNames) {
        if ([name isEqualToString:file]) {
            found = name;
            break;
        }
    }

    if (found) {
        [fileNames removeObject:found];
    } else {
        [fileNames addObject:file];
    }

    self.selectedFileNames = @"";
    if (fileNames.count > 0) {
        self.selectedFileNames = fileNames[0];
        if (self.multiple.boolValue) {
            for (int i = 1; i < fileNames.count; i++) {
                self.selectedFileNames = [self.selectedFileNames stringByAppendingFormat:@" %@", fileNames[i]];
            }
        }
    }

    [tableView reloadData];
    return indexPath;
}


@end
