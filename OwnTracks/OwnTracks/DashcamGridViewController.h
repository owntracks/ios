//
//  DashcamGridViewController.h
//  OwnTracks
//
//  Admin-only Dash Cam tab: fetches `/api/dashcam/clips?from=&to=` once per time
//  window, caches clips in LocationAPISyncService, derives device filter chips from
//  clips that have footage, and filters client-side by reason and device.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DashcamGridViewController : UIViewController

@end

NS_ASSUME_NONNULL_END
