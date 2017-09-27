//
//  Friend+CoreDataClass.h
//  OwnTracks
//
//  Created by Christoph Krey on 08.12.16.
//  Copyright © 2016-2017 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <MapKit/MapKit.h>
#import <AddressBook/AddressBook.h>

@class Location, Region, Subscription, Waypoint;

NS_ASSUME_NONNULL_BEGIN

@interface Friend : NSManagedObject <MKAnnotation, MKOverlay>

@property (nonatomic) CLLocationCoordinate2D coordinate;

+ (ABAddressBookRef)theABRef CF_RETURNS_NOT_RETAINED;

+ (Friend *)existsFriendWithTopic:(NSString *)topic
           inManagedObjectContext:(NSManagedObjectContext *)context;

+ (Friend *)friendWithTopic:(NSString *)topic
     inManagedObjectContext:(NSManagedObjectContext *)context;

+ (NSString *)nameOfPerson:(ABRecordRef)record;
+ (NSData *)imageDataOfPerson:(ABRecordRef)record;

+ (NSArray *)allFriendsInManagedObjectContext:(NSManagedObjectContext *)context;

- (void)linkToAB:(ABRecordRef)record;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * _Nonnull name;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString * _Nonnull nameOrTopic;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSData * _Nonnull image;

+ (NSString *)effectiveTid:(NSString *)tid device:(NSString *)device;
@property (NS_NONATOMIC_IOSONLY, getter=getEffectiveTid, readonly, copy) NSString * _Nonnull effectiveTid;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) Waypoint * _Nonnull newestWaypoint;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) MKPolyline * _Nonnull polyLine;

@end

NS_ASSUME_NONNULL_END

#import "Friend+CoreDataProperties.h"
