//
//  FriendAnnotationV.m
//  OwnTracks
//
//  Created by Christoph Krey on 15.09.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "FriendAnnotationV.h"

@implementation FriendAnnotationV

#define CIRCLE_SIZE 40.0
#define CIRCLE_COLOR [UIColor yellowColor]

#define FENCE_COLOR [UIColor orangeColor]
#define FENCE_WIDTH 3.0

#define ID_COLOR [UIColor blackColor]
#define ID_FONTSIZE 24
#define ID_INSET 3

#define COURSE_COLOR [UIColor blueColor]
#define COURSE_WIDTH 8.0

#define TACHO_COLOR [UIColor redColor]
#define TACHO_MAX 200.0

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.0];
        CGRect rect;
        rect.origin.x = 0;
        rect.origin.y = 0;
        rect.size.width = CIRCLE_SIZE;
        rect.size.height = CIRCLE_SIZE;
        self.frame = rect;
    }
    return self;
}

- (void)setPersonImage:(UIImage *)image
{
    _personImage = [UIImage imageWithCGImage:image.CGImage
                                       scale:(MAX(image.size.width, image.size.height) / CIRCLE_SIZE)
                                 orientation:UIImageOrientationUp];
}

- (void)drawRect:(CGRect)rect
{
    // It is all within a circle
    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:rect];
    [circle addClip];

    // Yellow or Photo background
    [CIRCLE_COLOR setFill];
    [circle fill];
    
    // ID
    if (self.tid == nil || [self.tid isEqualToString:@""]) {
        if (self.personImage != nil) {
            [self.personImage drawInRect:rect];
        }
    }
    
    // Tachometer
    if (self.speed > 0) {
        UIBezierPath *tacho = [[UIBezierPath alloc] init];
        [tacho moveToPoint:CGPointMake(rect.origin.x + rect.size.width / 2, rect.origin.y + rect.size.height / 2)];
        [tacho addLineToPoint:CGPointMake(rect.origin.x + rect.size.width / 2, rect.origin.y + rect.size.height)];
        [tacho appendPath:[UIBezierPath bezierPathWithArcCenter:CGPointMake(rect.size.width / 2, rect.size.height / 2)
                                                         radius:CIRCLE_SIZE / 2
                                                     startAngle:M_PI_2
                                                       endAngle:M_PI_2 + 2 * M_PI * self.speed / TACHO_MAX
                                                      clockwise:true]];
        [tacho addLineToPoint:CGPointMake(rect.origin.x + rect.size.width / 2, rect.origin.y + rect.size.height / 2)];
        [tacho closePath];
        
        [TACHO_COLOR setFill];
        [tacho fill];
    }

    // ID
    if ((self.tid != nil && ![self.tid isEqualToString:@""]) || !self.automatic) {
        UIFont *font = [UIFont boldSystemFontOfSize:ID_FONTSIZE];
        NSDictionary *attributes = @{NSFontAttributeName: font,
                                     NSForegroundColorAttributeName: ID_COLOR};
        NSString *text;
        if (self.automatic) {
            text = self.tid;
        } else {
            text = @"***";
        }

        
        CGRect boundingRect = [text boundingRectWithSize:rect.size options:0 attributes:attributes context:nil];
        
        CGRect textRect = CGRectMake(rect.origin.x + (rect.size.width - boundingRect.size.width) / 2,
                                     rect.origin.y + (rect.size.height - boundingRect.size.height) / 2,
                                     boundingRect.size.width, boundingRect.size.height);
        
        [text drawInRect:textRect withAttributes:attributes];
    }
    
    // FENCE
    [FENCE_COLOR setStroke];
    [circle setLineWidth:FENCE_WIDTH];
    [circle stroke];

    // Course
    UIBezierPath *course = [UIBezierPath bezierPathWithOvalInRect:
                            CGRectMake(
                                       rect.origin.x + rect.size.width / 2 + CIRCLE_SIZE / 2 * cos((self.course -90 )/ 360 * 2 * M_PI) - COURSE_WIDTH / 2,
                                       rect.origin.y + rect.size.height / 2 + CIRCLE_SIZE / 2 * sin((self.course -90 )/ 360 * 2 * M_PI) - COURSE_WIDTH / 2,
                                       COURSE_WIDTH,
                                       COURSE_WIDTH
                                       )
                            ];
    [COURSE_COLOR setFill];
    [course fill];
}


@end
