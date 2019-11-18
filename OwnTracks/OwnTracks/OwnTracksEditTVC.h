//
//  OwnTracksEditTVC.h
//  OwnTracks
//
//  Created by Christoph Krey on 13.10.19.
//  Copyright © 2019 OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OwnTracksEditTVC : UITableViewController
@property (strong, nonatomic) NSString *emptyText;
- (void)empty;
- (void)nonempty;
@end

NS_ASSUME_NONNULL_END
