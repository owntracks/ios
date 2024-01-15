//
//  NavigationController.h
//  OwnTracks
//
//  Created by Christoph Krey on 29.06.15.
//  Copyright © 2015-2024  OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NavigationController : UINavigationController
- (void)alert:(NSString *)title message:(NSString *)message;
- (void)alert:(NSString *)title message:(NSString *)message url:(NSString *)url;
- (void)alert:(NSString *)title message:(NSString *)message dismissAfter:(NSTimeInterval)interval;

@end
