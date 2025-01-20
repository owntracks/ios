//
//  PhotoAnnotationV.m
//  OwnTracks
//
//  Created by Christoph Krey on 04.12.24.
//  Copyright © 2024-2025 OwnTracks. All rights reserved.
//

#import "PhotoAnnotationV.h"

@implementation PhotoAnnotationV

#define CIRCLE_SIZE 50.0
#define FENCE_WIDTH 3.0

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    [self internalInit];
    return self;
}

- (instancetype)initWithAnnotation:(id<MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    [self internalInit];
    return self;
}

- (void)internalInit {
    self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.0];
    self.frame = CGRectMake(0, 0, CIRCLE_SIZE, CIRCLE_SIZE);
}

- (void)setPoiImage:(UIImage *)image {
    if (image) {
        _poiImage = [UIImage imageWithCGImage:image.CGImage
                                           scale:(MAX(image.size.width, image.size.height) / CIRCLE_SIZE)
                                     orientation:UIImageOrientationUp];
    } else {
        _poiImage = nil;
    }
}

- (void)drawRect:(CGRect)rect {
    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:rect];
    [circle addClip];

    [[UIColor systemRedColor] setFill];
    [circle fill];
    
    if (self.poiImage != nil) {
        [self.poiImage drawInRect:rect];
    }
    
    [circle setLineWidth:FENCE_WIDTH];
    [[UIColor systemYellowColor] setStroke];
    [circle stroke];

}

@end
