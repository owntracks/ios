//
//  CertificatesTVC.h
//  OwnTracks
//
//  Created by Christoph Krey on 01.07.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CertificatesTVC : UITableViewController
@property (strong, nonatomic) NSString *selectedFileNames;
@property (strong, nonatomic) NSString *fileNameIdentifier;
@property (strong, nonatomic) NSNumber *multiple;
@end
