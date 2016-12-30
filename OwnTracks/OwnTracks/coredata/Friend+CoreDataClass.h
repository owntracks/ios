//
//  Friend+CoreDataClass.h
//  OwnTracks
//
//  Created by Christoph Krey on 08.12.16.
//  Copyright © 2016 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <MapKit/MapKit.h>
#import <AddressBook/AddressBook.h>

@class Location, Region, Subscription, Waypoint;

NS_ASSUME_NONNULL_BEGIN

@interface Friend : NSManagedObject <MKAnnotation, MKOverlay>

@property (nonatomic) CLLocationCoordinate2D coordinate;

+ (ABAddressBookRef)theABRef;

+ (Friend *)existsFriendWithTopic:(NSString *)topic
           inManagedObjectContext:(NSManagedObjectContext *)context;

+ (Friend *)friendWithTopic:(NSString *)topic
     inManagedObjectContext:(NSManagedObjectContext *)context;

+ (NSString *)nameOfPerson:(ABRecordRef)record;
+ (NSData *)imageDataOfPerson:(ABRecordRef)record;

+ (NSArray *)allFriendsInManagedObjectContext:(NSManagedObjectContext *)context;

- (void)linkToAB:(ABRecordRef)record;
- (NSString *)name;
- (NSString *)nameOrTopic;
- (NSData *)image;

- (NSString *)getEffectiveTid;
- (Waypoint *)newestWaypoint;
- (MKPolyline *)polyLine;

@end

NS_ASSUME_NONNULL_END

#import "Friend+CoreDataProperties.h"
