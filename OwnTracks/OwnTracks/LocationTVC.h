//
//  LocationTVC.h
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "CoreDataTableViewController.h"
#import "Friend+Create.h"

@interface LocationTVC : CoreDataTableViewController
@property (strong, nonatomic) Friend *friend;

@end
