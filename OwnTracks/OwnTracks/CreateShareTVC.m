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
@property (weak, nonatomic) IBOutlet UITextField *label;
@property (weak, nonatomic) IBOutlet UIDatePicker *from;
@property (weak, nonatomic) IBOutlet UIDatePicker *to;

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
    self.label.text = @"my share";
    self.from.date = [NSDate now];
    self.to.date = [self.from.date dateByAddingTimeInterval:3600.0];
}

- (IBAction)savePressed:(UIBarButtonItem *)sender {
    NSLog(@"save %@, %@, %@",
          self.label.text,
          self.from.description,
          self.to.description);
    
    Share *share = [[Share alloc] init];
    share.label = self.label.text;
    share.from = self.from.date;
    share.to = self.to.date;
    
    [[Shares sharedInstance] requestShare:share];
}
@end
