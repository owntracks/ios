//
//  AlertView.h
//  OwnTracks
//
//  Created by Christoph Krey on 20.12.13.
//  Copyright © 2013-2017 Christoph Krey. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AlertView : NSObject
+ (void)alert:(NSString *)title message:(NSString *)message;
+ (void)alert:(NSString *)title message:(NSString *)message dismissAfter:(NSTimeInterval)interval;
@end
