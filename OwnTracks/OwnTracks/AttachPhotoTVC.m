//
//  AttachPhotoTVCTableViewController.m
//  OwnTracks
//
//  Created by Christoph Krey on 21.11.24.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import "AttachPhotoTVC.h"
#import "CoreData.h"
#import "Settings.h"
#import "OwnTracksAppDelegate.h"
#import "Friend+CoreDataClass.h"
#import <Photos/Photos.h>

@interface AttachPhotoTVC ()
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;

@end

@implementation AttachPhotoTVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)adjustSaveButton {
    self.saveButton.enabled = (self.poi.text != nil &&
                               self.poi.text.length > 0 &&
                               self.photo.image != nil);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self adjustSaveButton];
}

- (IBAction)editingChanged:(UITextField *)sender {
    [self adjustSaveButton];
}

#pragma PHPickerViewControllerDelegate
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    NSLog(@"picker didFinishPicking %@", results);
    for (PHPickerResult *result in results) {
        NSLog(@"picker result %@", result);
        NSItemProvider *itemProvider = result.itemProvider;
        NSLog(@"itemProvider%@", itemProvider);
        self.imageName = itemProvider.suggestedName;
        
        if ([itemProvider hasItemConformingToTypeIdentifier:@"com.apple.private.photos.thumbnail.standard"]) {
            [itemProvider loadFileRepresentationForTypeIdentifier:@"com.apple.private.photos.thumbnail.standard" completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
                NSLog(@"loadFileRepresentationForTypeIdentifier %@ %@", error, url);
                if (!error && url) {
                    self.data = [NSData dataWithContentsOfURL:url];
                    [self performSelectorOnMainThread:@selector(handleLoad:)
                                           withObject:url
                                        waitUntilDone:FALSE];
                }
            }];
        }

    }

    [picker dismissViewControllerAnimated:TRUE completion:^{
        //
    }];
}

- (void)handleLoad:(NSURL *)url {
    UIImage *image = [UIImage imageWithData:self.data];
    CGFloat scale = 192.0 / MIN(image.size.width, image.size.height);
    CGSize size = CGSizeApplyAffineTransform(image.size,
                                             CGAffineTransformMakeScale(scale, scale));
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(192.0, 192.0), FALSE, 1.0);
    [image drawInRect:CGRectMake((192.0 - size.width) / 2,
                                 (192.0 - size.height) / 2,
                                 size.width, size.height)
    ];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    self.photo.image = scaledImage;
}

- (IBAction)selectPressed:(UIButton *)sender {
    PHPickerConfiguration *pickerConfiguration = [[PHPickerConfiguration alloc] initWithPhotoLibrary:[PHPhotoLibrary sharedPhotoLibrary]];
    PHPickerViewController *pickerViewController = [[PHPickerViewController alloc] initWithConfiguration:pickerConfiguration];
    pickerViewController.delegate = self;
    [self presentViewController:pickerViewController
                       animated:TRUE
                     completion:^{
            //
    }];
}

@end
