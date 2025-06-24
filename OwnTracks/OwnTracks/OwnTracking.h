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

- (BOOL)processMessage:(NSString *)topic
                  data:(NSData *)data
              retained:(BOOL)retained
               context:(NSManagedObjectContext *)context;

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
