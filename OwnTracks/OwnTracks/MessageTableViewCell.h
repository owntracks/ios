//
//  MessageTableViewCell.h
//  OwnTracks
//
//  Created by Christoph Krey on 25.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MessageTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *icon;
@property (weak, nonatomic) IBOutlet UILabel *title;
@property (weak, nonatomic) IBOutlet UITextView *desc;
@property (weak, nonatomic) IBOutlet UILabel *info;

@end
