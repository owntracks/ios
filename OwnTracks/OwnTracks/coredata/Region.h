//
//  Region.h
//  OwnTracks
//
//  Created by Christoph Krey on 28.09.15.
//  Copyright © 2015-2018 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

@class Friend;

NS_ASSUME_NONNULL_BEGIN

@interface Region : NSManagedObject <MKAnnotation, MKOverlay>

@property (nonatomic) CLLocationCoordinate2D coordinate;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) CLRegion * _Nonnull CLregion;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) MKCircle * _Nonnull circle;
@property (NS_NONATOMIC_IOSONLY, getter=getAndFillTst, readonly, copy) NSDate * _Nonnull andFillTst;

@end

NS_ASSUME_NONNULL_END

#import "Region+CoreDataProperties.h"
