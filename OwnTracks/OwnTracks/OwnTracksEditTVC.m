//
//  OwnTracksEditTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 13.10.19.
//  Copyright © 2019-2024 OwnTracks. All rights reserved.
//

#import "OwnTracksEditTVC.h"

@interface OwnTracksEditTVC ()
@property (strong, nonatomic) UILabel *emptyLabel;
@property (strong, nonatomic) NSArray <NSLayoutConstraint *> *constraints;

@end

@implementation OwnTracksEditTVC

- (void)viewDidLoad {
    [super viewDidLoad];
}

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
