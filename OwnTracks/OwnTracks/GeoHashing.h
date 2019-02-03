//
//  GeoHashing.h
//  OwnTracks
//
//  Created by Christoph Krey on 05.12.16.
//  Copyright © 2016 -2019 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Mapkit/Mapkit.h>
#import <CoreLocation/CoreLocation.h>
#import "GeoHash.h"
#import "GHArea.h"
#import "GHRange.h"
#import "Subscription+CoreDataClass.h"

#undef GEOHASHING // work without geohashing

@interface Area : NSObject <MKOverlay>
@property (strong, nonatomic) NSString *geoHash;
- (void)setCoordinate:(CLLocationCoordinate2D)coordinate;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) MKPolygon *polygon;

@end

@interface Neighbors : NSObject
@property (strong, nonatomic) Area *center;
@property (strong, nonatomic) Area *west;
@property (strong, nonatomic) Area *northWest;
@property (strong, nonatomic) Area *north;
@property (strong, nonatomic) Area *northEast;
@property (strong, nonatomic) Area *east;
@property (strong, nonatomic) Area *southEast;
@property (strong, nonatomic) Area *south;
@property (strong, nonatomic) Area *southWest;

@end

@interface GeoHashing : NSObject
@property (strong, nonatomic) Neighbors *neighbors;

+ (GeoHashing *)sharedInstance;

- (BOOL)processMessage:(NSString *)topic data:(NSData *)data retained:(BOOL)retained context:(NSManagedObjectContext *)context;
- (void)newLocation:(CLLocation *)location;

- (Subscription *)addSubscriptionFor:(Friend *)friend name:(NSString *)name level:(int)level context:(NSManagedObjectContext *)context;
- (void)removeSubscription:(Subscription *)subscription context:(NSManagedObjectContext *)context;

- (Info *)addInfoFor:(Subscription *)subscription
          identifier:(NSString *)identifier
             geohash:(NSString *)geohash
                 tst:(NSDate *)tst
                 lat:(float)lat
                 lon:(float)lon
                size:(float)size
                hand:(float)hand
               level:(float)level
         circleStart:(float)circleStart
           circleEnd:(float)circleEnd
           ringColor:(int32_t)ringColor
                name:(NSString *)name
                 tid:(NSString *)tid
               image:(NSData *)image
             context:(NSManagedObjectContext *)context;
- (void)removeInfo:(Info *)info context:(NSManagedObjectContext *)context;
@end
