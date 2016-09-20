//
//  Region.h
//  OwnTracks
//
//  Created by Christoph Krey on 28.09.15.
//  Copyright © 2015-2016 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

@class Friend;

NS_ASSUME_NONNULL_BEGIN

@interface Region : NSManagedObject <MKAnnotation, MKOverlay>

@property (nonatomic) CLLocationCoordinate2D coordinate;
- (CLRegion *)CLregion;
- (MKCircle *)circle;
- (NSDate *)getAndFillTst;

@end

NS_ASSUME_NONNULL_END

#import "Region+CoreDataProperties.h"
