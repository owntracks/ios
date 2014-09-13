//
//  LocationTVC.h
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "Friend+Create.h"

@interface LocationTVC : UITableViewController <NSFetchedResultsControllerDelegate>
@property (strong, nonatomic) Friend *friend;

@end
