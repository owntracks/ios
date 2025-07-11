//
//  OwnTracking.h
//  OwnTracks
//
//  Created by Christoph Krey on 28.06.15.
//  Copyright © 2015-2025  OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Friend+CoreDataClass.h"
#import "Waypoint+CoreDataClass.h"
#import "Region+CoreDataClass.h"
#import <CoreLocation/CoreLocation.h>

@interface OwnTracking : NSObject
+ (OwnTracking *)sharedInstance;
- (void)publishStatus:(BOOL)isActive; // ← Add this line
- (BOOL)processMessage:(NSString *)topic
                  data:(NSData *)data
              retained:(BOOL)retained
               context:(NSManagedObjectContext *)context;

- (Waypoint *)addWaypointFor:(Friend *)friend
location:(CLLocation *)location
createdAt:(NSDate *)createdAt
trigger:(NSString *)trigger
poi:(NSString *)poi
tag:(NSString *)tag
battery:(NSNumber *)battery
image:(NSData *)image
imageName:(NSString *)imageName
inRegions:(NSArray <NSString *> *)inRegions
inRids:(NSArray <NSString *> *)inRids
bssid:(NSString *)bssid
ssid:(NSString *)ssid
m:(NSNumber *)m
conn:(NSString *)conn
bs:(NSNumber *)bs;

- (void)limitWaypointsFor:(Friend *)friend toMaximum:(NSInteger)max;

- (Region *)addRegionFor:(NSString *)rid
friend:(Friend *)friend
name:(NSString *)name
tst:(NSDate *)tst
uuid:(NSString *)uuid
major:(unsigned int)major
minor:(unsigned int)minor
radius:(double)radius
lat:(double)lat
lon:(double)lon;

- (void)removeRegion:(Region *)region context:(NSManagedObjectContext *)context;

- (NSDictionary *)waypointAsJSON:(Waypoint *)waypoint;
- (NSDictionary *)regionAsJSON:(Region *)region;

@end
