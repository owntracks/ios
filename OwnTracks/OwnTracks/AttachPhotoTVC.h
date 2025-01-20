//
//  AttachPhotoTVCTableViewController.h
//  OwnTracks
//
//  Created by Christoph Krey on 21.11.24.
//  Copyright © 2024-2025 OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>

NS_ASSUME_NONNULL_BEGIN

@interface AttachPhotoTVC : UITableViewController <UINavigationControllerDelegate, PHPickerViewControllerDelegate>
@property (weak, nonatomic) IBOutlet UITextField *poi;
@property (weak, nonatomic) IBOutlet UIImageView *photo;
@property (strong, nonatomic) NSString *imageName;
@property (strong, nonatomic) NSData *data;

@end

NS_ASSUME_NONNULL_END
