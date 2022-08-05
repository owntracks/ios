//
//  CreateCardTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 18.07.22.
//  Copyright © 2022 OwnTracks. All rights reserved.
//

#import "CreateCardTVC.h"
#import "CoreData.h"
#import "Settings.h"
#import "OwnTracksAppDelegate.h"
#import "Friend+CoreDataClass.h"

@interface CreateCardTVC ()
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;

@end

@implementation CreateCardTVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    NSString *topic = [Settings theGeneralTopicInMOC:moc];
    Friend *myself = [Friend existsFriendWithTopic:topic
                            inManagedObjectContext:moc];
    if (!self.name.text || self.name.text.length == 0) {
        self.name.text = myself.name ? myself.name : myself.tid;
    }
    if (!self.cardImage.image) {
        self.cardImage.image = myself.image ? [UIImage imageWithData:myself.image] : nil;
    }
}

#pragma UIImagePickerControllerDelegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    NSLog(@"imagePickerController imagePickerControllerDidCancel");
    [picker dismissViewControllerAnimated:TRUE
                               completion:^{
        //
    }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    NSLog(@"imagePickerController didFinishPickingMediaWithInfo %@", info);
    UIImage *editedImage = info[@"UIImagePickerControllerEditedImage"];
    
    NSLog(@"editedImage %f, %f, %f",
          editedImage.size.width,
          editedImage.size.height,
          editedImage.scale);
    
    CGFloat scale = 192.0 / MIN(editedImage.size.width, editedImage.size.height);
    CGSize size = CGSizeApplyAffineTransform(editedImage.size,
                                             CGAffineTransformMakeScale(scale, scale));
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(192.0, 192.0), FALSE, 1.0);
    [editedImage drawInRect:CGRectMake((192.0 - size.width) / 2,
                                       (192.0 - size.height) / 2,
                                       size.width, size.height)
    ];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    self.cardImage.image = scaledImage;

    NSLog(@"cardImage %f, %f, %f",
          self.cardImage.image.size.width,
          self.cardImage.image.size.height,
          self.cardImage.image.scale);

    [picker dismissViewControllerAnimated:TRUE
                               completion:^{
        //
    }];

}
- (IBAction)takePhotoPressed:(UIButton *)sender {
    NSLog(@"imagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera %d", [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]);
    NSLog(@"imagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera %@", [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera]);

    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    imagePickerController.mediaTypes = @[@"public.image"];
    imagePickerController.allowsEditing = TRUE;
    imagePickerController.delegate = self;
    [self presentViewController:imagePickerController
                       animated:TRUE
                     completion:^{
            //
    }];
}

- (IBAction)selectPressed:(UIButton *)sender {
    NSLog(@"imagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary %d", [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]);
    NSLog(@"imagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary %@", [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary]);

    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePickerController.mediaTypes = @[@"public.image"];
    imagePickerController.allowsEditing = TRUE;
    imagePickerController.delegate = self;
    [self presentViewController:imagePickerController
                       animated:TRUE
                     completion:^{
            //
    }];
}

@end
