//
//  Info+CoreDataClass.h
//  OwnTracks
//
//  Created by Christoph Krey on 08.12.16.
//  Copyright © 2016 -2019 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

@class Subscription;

NS_ASSUME_NONNULL_BEGIN

@interface Info : NSManagedObject <MKAnnotation>
@property (nonatomic) CLLocationCoordinate2D coordinate;


@end

NS_ASSUME_NONNULL_END

#import "Info+CoreDataProperties.h"
