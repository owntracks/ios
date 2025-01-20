//
//  FriendAnnotationV.h
//  OwnTracks
//
//  Created by Christoph Krey on 15.09.13.
//  Copyright © 2013-2025  Christoph Krey. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface FriendAnnotationV : MKAnnotationView
@property (strong, nonatomic) NSString *tid;
@property (strong, nonatomic) UIImage *personImage;
@property (nonatomic) double speed;
@property (nonatomic) double course;
@property (nonatomic) BOOL automatic;
@property (nonatomic) BOOL me;
- (UIImage *)getImage;

@end
