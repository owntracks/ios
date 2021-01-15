//
//  HistoryTVC.h
//  OwnTracks
//
//  Created by Christoph Krey on 26.08.19.
//  Copyright © 2019-2021 OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "History+CoreDataClass.h"
#import "OwnTracksEditTVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface HistoryTVC : OwnTracksEditTVC <NSFetchedResultsControllerDelegate>

@end

NS_ASSUME_NONNULL_END
