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
@property (weak, nonatomic) IBOutlet UITextField *name;
@property (weak, nonatomic) IBOutlet UIImageView *cardImage;

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

    self.cardImage.image = [UIImage imageWithCGImage:editedImage.CGImage
                                               scale:editedImage.size.width / 192.0
                                         orientation:UIImageOrientationUp];

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

- (IBAction)savePressed:(UIBarButtonItem *)sender {
    NSLog(@"image %f, %f, %f",
          self.cardImage.image.size.width,
          self.cardImage.image.size.height,
          self.cardImage.image.scale);
    
    NSData *png = UIImagePNGRepresentation(self.cardImage.image);
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    NSString *topic = [Settings theGeneralTopicInMOC:moc];
    Friend *myself = [Friend existsFriendWithTopic:topic
                            inManagedObjectContext:moc];
    
    
    myself.cardName = self.name.text;
    myself.cardImage = UIImagePNGRepresentation(self.cardImage.image);
    
    NSDictionary *json = @{
        @"_type": @"card",
        @"face": [png base64EncodedStringWithOptions:0],
        @"name": self.name.text,
        @"tid": myself.tid
    };
    
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.connection sendData:[NSJSONSerialization dataWithJSONObject:json
                                                            options:NSJSONWritingSortedKeys
                                                              error:nil]
                        topic:[[Settings theGeneralTopicInMOC:moc] stringByAppendingString:@"/info"]
                   topicAlias:@(0)
                          qos:[Settings intForKey:@"qos_preference"
                                            inMOC:moc]
                       retain:YES];
}
@end
