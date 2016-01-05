//
//  UIColor+WithName.h
//  OwnTracks
//
//  Created by Christoph Krey on 28.06.15.
//  Copyright © 2015-2016 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UIColor (WithName)
+ (UIColor *)colorWithName:(NSString *)name;
+ (UIColor *)colorWithName:(NSString *)name defaultColor:(UIColor *)defaultColor;
@end
