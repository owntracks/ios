//
//  CreateViewTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 18.07.22.
//  Copyright © 2022 OwnTracks. All rights reserved.
//

#import "CreateShareTVC.h"
#import "Shares.h"

@interface CreateShareTVC ()

@end

@implementation CreateShareTVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.from.date = [NSDate now];
    self.to.date = [self.from.date dateByAddingTimeInterval:3600.0];
}
@end
