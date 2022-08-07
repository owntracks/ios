//
//  ToursStatusCell.h
//  OwnTracks
//
//  Created by Christoph Krey on 05.08.22.
//  Copyright © 2022 OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ToursStatusCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activity;
@property (weak, nonatomic) IBOutlet UILabel *label;

@end

NS_ASSUME_NONNULL_END
