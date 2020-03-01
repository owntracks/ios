//
//  OwnTracksEditTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 13.10.19.
//  Copyright © 2019-2020 OwnTracks. All rights reserved.
//

#import "OwnTracksEditTVC.h"

@interface OwnTracksEditTVC ()
#if TARGET_OS_MACCATALYST
@property (strong, nonatomic) UIBarButtonItem *editButton;
@property (strong, nonatomic) UIBarButtonItem *doneButton;
#endif
@property (strong, nonatomic) UILabel *emptyLabel;
@property (strong, nonatomic) NSArray <NSLayoutConstraint *> *constraints;

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

- (void)empty {
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = false;
    if (self.emptyText) {
        self.emptyLabel.text = self.emptyText;
    } else {
        self.emptyLabel.text = NSLocalizedString(@"Table is empty",
                                                 @"Table is empty");
    }
    self.tableView.backgroundView = self.emptyLabel;
    NSLayoutConstraint *center = [NSLayoutConstraint
                                  constraintWithItem:self.emptyLabel
                                  attribute:NSLayoutAttributeCenterX
                                  relatedBy:NSLayoutRelationEqual
                                  toItem:self.tableView
                                  attribute:NSLayoutAttributeCenterX
                                  multiplier:1
                                  constant:0];
    NSLayoutConstraint *middle = [NSLayoutConstraint
                                  constraintWithItem:self.emptyLabel
                                  attribute:NSLayoutAttributeCenterY
                                  relatedBy:NSLayoutRelationEqual
                                  toItem:self.tableView
                                  attribute:NSLayoutAttributeCenterY
                                  multiplier:1
                                  constant:0];
    self.constraints = @[center, middle];
    [NSLayoutConstraint activateConstraints:self.constraints];
}

- (void)nonempty {
    if (self.constraints) {
        [NSLayoutConstraint deactivateConstraints:self.constraints];
        self.constraints = nil;
    }
    self.emptyLabel = nil;
    self.tableView.backgroundView = nil;
}

@end
