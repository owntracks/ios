//
//  FriendAnnotationV.m
//  OwnTracks
//
//  Created by Christoph Krey on 15.09.13.
//  Copyright © 2013-2021  Christoph Krey. All rights reserved.
//

#import "FriendAnnotationV.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@implementation FriendAnnotationV
static const DDLogLevel ddLogLevel = DDLogLevelInfo;

#define CIRCLE_SIZE 40.0
#define FENCE_WIDTH 5.0
#define ID_FONTSIZE 20.0
#define ID_INSET 3.0
#define COURSE_WIDTH 10.0
#define TACHO_SCALE 30.0
#define TACHO_MAX 260.0

/** This method does not seem to be called anymore in ios10
 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    DDLogVerbose(@"FriendAnnotationView initWithFrame ddLogLevel %lu", (unsigned long)ddLogLevel);
    [self internalInit];
    return self;
}

- (instancetype)initWithAnnotation:(id<MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier {
    DDLogVerbose(@"FriendAnnotationView initWithAnnotation reuseIdentifer %@", reuseIdentifier);
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    [self internalInit];
    return self;
}

- (void)internalInit {
    self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.0];
    self.frame = CGRectMake(0, 0, CIRCLE_SIZE, CIRCLE_SIZE);
}

- (void)setPersonImage:(UIImage *)image {
    if (image) {
        _personImage = [UIImage imageWithCGImage:image.CGImage
                                           scale:(MAX(image.size.width, image.size.height) / CIRCLE_SIZE)
                                     orientation:UIImageOrientationUp];
    } else {
        _personImage = nil;
    }
}

- (UIImage *)getImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(CIRCLE_SIZE, CIRCLE_SIZE), NO, 0.0);
    [self drawRect:CGRectMake(0, 0, CIRCLE_SIZE, CIRCLE_SIZE)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)drawRect:(CGRect)rect
{
    // It is all within a circle
    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:rect];
    [circle addClip];

    // Yellow or Photo background
    [[UIColor colorNamed:@"circleColor"] setFill];
    [circle fill];
    
    // ID
    if (self.personImage != nil) {
        [self.personImage drawInRect:rect];
    }
    
    // Tachometer
     
    if (self.speed > 0) {
        UIBezierPath *tacho = [[UIBezierPath alloc] init];
        [tacho moveToPoint:CGPointMake(rect.origin.x + rect.size.width / 2.0,
                                       rect.origin.y + rect.size.height / 2.0)];
        [tacho appendPath:[UIBezierPath bezierPathWithArcCenter: CGPointMake(rect.size.width / 2.0,
                                                                             rect.size.height / 2.0)
                                                         radius:CIRCLE_SIZE / 2.0
                                                     startAngle:M_PI_2 + M_PI / 6.0
                                                       endAngle:M_PI_2 + M_PI / 6.0 + M_PI * 2.0 * 5.0 / 6.0 * (MIN(self.speed / TACHO_MAX, 1.0))
                                                      clockwise:true]];
        [tacho addLineToPoint:CGPointMake(rect.origin.x + rect.size.width / 2.0,
                                          rect.origin.y + rect.size.height / 2.0)];
        [tacho closePath];

        [[UIColor colorNamed:@"tachoColor"] setFill];
        [tacho fill];
        [[UIColor colorNamed:@"circleColor"] setStroke];
        tacho.lineWidth = 1.0;
        [tacho stroke];
    }

    // ID
    if (self.personImage == nil) {
        if ((self.tid != nil && ![self.tid isEqualToString:@""])) {
            UIFont *font = [UIFont boldSystemFontOfSize:ID_FONTSIZE];
            NSDictionary *attributes = @{NSFontAttributeName: font,
                                         NSForegroundColorAttributeName: [UIColor colorNamed:@"idColor"]};
            CGRect boundingRect = [self.tid boundingRectWithSize:rect.size
                                                         options:0
                                                      attributes:attributes
                                                         context:nil];
            CGRect textRect =
            CGRectMake(rect.origin.x + (rect.size.width - boundingRect.size.width) / 2,
                       rect.origin.y + (rect.size.height - boundingRect.size.height) / 2,
                       boundingRect.size.width, boundingRect.size.height);
            [self.tid drawInRect:textRect withAttributes:attributes];
        }
    }
    
    // FENCE
    [circle setLineWidth:FENCE_WIDTH];
    if (self.me) {
        [[UIColor colorNamed:@"meColor"] setStroke];
    } else {
        [[UIColor colorNamed:@"friendColor"] setStroke];
    }
    [circle stroke];

    // Course
    if (self.course > 0) {
        UIBezierPath *course = [UIBezierPath bezierPathWithOvalInRect:
                                CGRectMake(
                                           rect.origin.x + rect.size.width / 2 + CIRCLE_SIZE / 2 * cos((self.course -90 )/ 360 * 2 * M_PI) - COURSE_WIDTH / 2,
                                           rect.origin.y + rect.size.height / 2 + CIRCLE_SIZE / 2 * sin((self.course -90 )/ 360 * 2 * M_PI) - COURSE_WIDTH / 2,
                                           COURSE_WIDTH,
                                           COURSE_WIDTH
                                           )
                                ];
        [[UIColor colorNamed:@"courseColor"] setFill];
        [course fill];
        [[UIColor colorNamed:@"circleColor"] setStroke];
        course.lineWidth = 1.0;
        [course stroke];
    }
}

- (void)setDragState:(MKAnnotationViewDragState)newDragState animated:(BOOL)animated {
    DDLogVerbose(@"newDragState %lu", (unsigned long)newDragState);
    switch (newDragState) {
        case MKAnnotationViewDragStateStarting:
        case MKAnnotationViewDragStateDragging:
            self.dragState = MKAnnotationViewDragStateDragging;
            break;
        case MKAnnotationViewDragStateCanceling:
        case MKAnnotationViewDragStateEnding:
        case MKAnnotationViewDragStateNone:
        default:
            self.dragState = MKAnnotationViewDragStateNone;
            break;
    }
}

- (void)setSelected:(BOOL)selected {
    DDLogVerbose(@"selected %lu", (unsigned long)selected);
    super.selected = selected;
}

- (void)prepareForReuse {
    DDLogVerbose(@"prepareForReuse");
    [super prepareForReuse];
}
@end
