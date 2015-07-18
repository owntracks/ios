//
//  OwnTracking.h
//  OwnTracks
//
//  Created by Christoph Krey on 28.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Friend+Create.h"
#import "Waypoint+Create.h"
#import "Region+Create.h"
#import <CoreLocation/CoreLocation.h>

@interface OwnTracking : NSObject
@property (strong, nonatomic) NSNumber *inQueue;

+ (OwnTracking *)sharedInstance;
- (void)syncProcessing;

- (BOOL)processMessage:(NSString *)topic data:(NSData *)data retained:(BOOL)retained context:(NSManagedObjectContext *)context;

- (Waypoint *)addWaypointFor:(Friend *)friend location:(CLLocation *)location trigger:(NSString *)trigger context:(NSManagedObjectContext *)context;

- (Region *)addRegionFor:(Friend *)friend name:(NSString *)name uuid:(NSString *)uuid major:(unsigned int)major minor:(unsigned int)minor share:(BOOL)share radius:(double)radius lat:(double)lat lon:(double)lon context:(NSManagedObjectContext *)context;
- (void)removeRegion:(Region *)region context:(NSManagedObjectContext *)context;

- (NSDictionary *)waypointAsJSON:(Waypoint *)waypoint;
- (NSDictionary *)regionAsJSON:(Region *)region;

@end
