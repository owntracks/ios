//
//  Friend+Create.h
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright © 2013-2016 Christoph Krey. All rights reserved.
//

#import "Friend+CoreDataProperties.h"
#import <MapKit/MapKit.h>
#import <AddressBook/AddressBook.h>

@interface Friend (Create) <MKAnnotation, MKOverlay>
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
