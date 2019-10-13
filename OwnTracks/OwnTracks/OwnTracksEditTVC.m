//
//  OwnTracksEditTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 13.10.19.
//  Copyright © 2019 OwnTracks. All rights reserved.
//

#import "OwnTracksEditTVC.h"

@interface OwnTracksEditTVC ()
#if TARGET_OS_MACCATALYST
@property (strong, nonatomic) UIBarButtonItem *editButton;
@property (strong, nonatomic) UIBarButtonItem *doneButton;
#endif

@end

@implementation OwnTracksEditTVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
#if TARGET_OS_MACCATALYST
    self.editButton =
    [[UIBarButtonItem alloc]
     initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
     target:self
     action:@selector(editToggle:)];
    self.doneButton =
    [[UIBarButtonItem alloc]
     initWithBarButtonSystemItem:UIBarButtonSystemItemDone
     target:self
     action:@selector(editToggle:)];

    NSMutableArray<UIBarButtonItem *> *a = [self.navigationItem.rightBarButtonItems mutableCopy];
    if (!a) {
        a = [[NSMutableArray alloc] init];
    }
    [a addObject:self.editButton];
    [self.navigationItem setRightBarButtonItems:a animated:TRUE];
#endif
}


#if TARGET_OS_MACCATALYST
- (IBAction)editToggle:(id)sender {
    [self.tableView setEditing:!self.tableView.editing animated:TRUE];
    NSMutableArray<UIBarButtonItem *> *a = [self.navigationItem.rightBarButtonItems mutableCopy];
    [a removeLastObject];
    if (self.tableView.editing) {
        [a addObject:self.doneButton];
    } else {
        [a addObject:self.editButton];
    }
    [self.navigationItem setRightBarButtonItems:a animated:TRUE];
}
#endif

@end
