//
//  Region+Create.h
//  OwnTracks
//
//  Created by Christoph Krey on 29.06.15.
//  Copyright © 2015-2016 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import "Region+CoreDataProperties.h"

@interface Region (Create) <MKAnnotation, MKOverlay>
@property (nonatomic) CLLocationCoordinate2D coordinate;
- (CLRegion *)CLregion;
- (MKCircle *)circle;
- (NSDate *)getAndFillTst;
@end
