//
//  Region+CoreDataClass.h
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
//  Copyright © 2018-2025 OwnTracks. All rights reserved.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

@class Friend;

NS_ASSUME_NONNULL_BEGIN
@interface CLRegion (follow)
- (BOOL)isFollow;
@end

@interface Region : NSManagedObject <MKAnnotation, MKOverlay>

@property (nonatomic) CLLocationCoordinate2D coordinate;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) CLRegion * _Nullable CLregion;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) MKCircle * _Nonnull circle;
@property (NS_NONATOMIC_IOSONLY, getter=getAndFillTst, readonly, copy) NSDate * _Nonnull andFillTst;
@property (NS_NONATOMIC_IOSONLY, getter=getAndFillRid, readonly, copy) NSString * _Nonnull andFillRid;

+ (NSString *)ridFromTst:(NSDate *)tst andName:(NSString *)name;
+ (NSString *)newRid;


@end

NS_ASSUME_NONNULL_END

#import "Region+CoreDataProperties.h"
