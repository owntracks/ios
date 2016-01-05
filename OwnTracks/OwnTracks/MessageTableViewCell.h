//
//  MessageTableViewCell.h
//  OwnTracks
//
//  Created by Christoph Krey on 25.06.15.
//  Copyright © 2015-2016 OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MessageTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *icon;
@property (weak, nonatomic) IBOutlet UILabel *info;
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UILabel *label;

@end
