//
//  UIColor+WithName.m
//  OwnTracks
//
//  Created by Christoph Krey on 28.06.15.
//  Copyright © 2015-2016 OwnTracks. All rights reserved.
//

#import "UIColor+WithName.h"
static NSDictionary *colors;

@implementation UIColor (WithName)
+ (UIColor *)colorWithName:(NSString *)name {
    
    if (!colors) {
        NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];
        NSURL *colorsPlistURL = [bundleURL URLByAppendingPathComponent:@"Colors.plist"];
        colors = [NSDictionary dictionaryWithContentsOfURL:colorsPlistURL];
    }
    
    UIColor *color= nil;
    NSString *rgb = colors[name];
    if (rgb) {
        NSScanner *scanner = [NSScanner scannerWithString:rgb];
        if (scanner) {
            unsigned long long llrgb;
            if ([scanner scanHexLongLong:&llrgb]) {
                double a = ((llrgb & 0xff000000) >> 24) / 255.0;
                double r = ((llrgb & 0xff0000) >> 16) / 255.0;
                double g = ((llrgb & 0xff00) >> 8) / 255.0;
                double b = (llrgb & 0xff) / 255.0;
                color = [UIColor colorWithRed:r green:g blue:b alpha:a];
            }
        }
    }
    return color;
}

+ (UIColor *)colorWithName:(NSString *)name defaultColor:(UIColor *)defaultColor {
    UIColor *color = [UIColor colorWithName:name];
    return color ? color : defaultColor;
}

@end
