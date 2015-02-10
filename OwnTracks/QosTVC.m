//
//  QosTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 19.05.14.
//  Copyright (c) 2014-2015 OwnTracks. All rights reserved.
//

#import "QosTVC.h"

@interface QosTVC ()

@end

@implementation QosTVC

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    for (int i = 0; i < 3; i++) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
        if (i == [self.editQos intValue]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.editQos = @(indexPath.row);
    return indexPath;
}

@end
