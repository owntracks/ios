//
//  CreateSharingTVC.h
//  OwnTracks
//
//  Created by Christoph Krey on 18.07.22.
//  Copyright © 2022 OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CreateSharingTVC : UITableViewController <UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UITextField *label;
@property (weak, nonatomic) IBOutlet UIDatePicker *from;
@property (weak, nonatomic) IBOutlet UIDatePicker *to;

@end

NS_ASSUME_NONNULL_END
