//
//  Friend+CoreDataClass.m
//  OwnTracks
//
//  Created by Christoph Krey on 08.12.16.
//  Copyright © 2016-2020  OwnTracks. All rights reserved.
//

#import "Friend+CoreDataClass.h"
#import "Region+CoreDataClass.h"
#import "Waypoint+CoreDataClass.h"
#import "Settings.h"
#import <Contacts/Contacts.h>

@implementation Friend

+ (Friend *)existsFriendWithTopic:(NSString *)topic
           inManagedObjectContext:(NSManagedObjectContext *)context {
    Friend *friend = nil;

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Friend"];
    request.predicate = [NSPredicate predicateWithFormat:@"topic = %@", topic];

    NSError *error = nil;

    NSArray *matches = [context executeFetchRequest:request error:&error];

    if (!matches || matches.count > 1) {
        // handle error
    } else {
        if (matches.count) {
            friend = matches.lastObject;
        }
    }

    return friend;
}

+ (NSArray *)allFriendsInManagedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Friend"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"topic" ascending:YES]];

    NSError *error = nil;

    NSArray *matches = [context executeFetchRequest:request error:&error];

    return matches;
}

+ (NSArray *)allNonStaleFriendsInManagedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Friend"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"topic" ascending:YES]];
    double ignoreStaleLocations = [Settings doubleForKey:@"ignorestalelocations_preference" inMOC:context];
    if (ignoreStaleLocations) {
        NSTimeInterval stale = -ignoreStaleLocations * 24.0 * 3600.0;
        request.predicate = [NSPredicate predicateWithFormat:@"lastLocation > %@",
                             [NSDate dateWithTimeIntervalSinceNow:stale]];
    }

    NSError *error = nil;

    NSArray *matches = [context executeFetchRequest:request error:&error];

    return matches;
}

+ (Friend *)friendWithTopic:(NSString *)topic
     inManagedObjectContext:(NSManagedObjectContext *)context {
    Friend *friend = [self existsFriendWithTopic:topic inManagedObjectContext:context];

    if (!friend) {
        friend = [NSEntityDescription insertNewObjectForEntityForName:@"Friend" inManagedObjectContext:context];

        friend.topic = topic;
    }

    return friend;
}

- (NSString *)name {
    NSString *name = self.cardName;

    if (self.contactId) {
        NSString *nameOfPerson = [Friend nameOfPerson:self.contactId];
        if (nameOfPerson) {
            name = nameOfPerson;
        }
    }
    return name;
}

- (NSString *)nameOrTopic {
    return self.name ? self.name : self.topic;
}

+ (NSString *)nameOfPerson:(NSString *)contactId {
    NSString *name = nil;

    CNContactStore *contactStore = [[CNContactStore alloc] init];
    NSArray *keys = @[[CNContactFormatter
                       descriptorForRequiredKeysForStyle:CNContactFormatterStyleFullName],
                      CNContactNicknameKey
                      ];
    CNContact *contact = [contactStore unifiedContactWithIdentifier:contactId
                                                        keysToFetch:keys
                                                              error:nil];

    if (contact) {
        if (contact.nickname && contact.nickname.length > 0) {
            name = contact.nickname;
        } else {
            name = [CNContactFormatter
                    stringFromContact:contact
                    style:CNContactFormatterStyleFullName];
        }
    }
    return name;
}

- (NSData *)image {
    NSData *data = self.cardImage;

    if (self.contactId) {
        NSData *imageData = [Friend imageDataOfPerson:self.contactId];
        if (imageData) {
            data = imageData;
        }
    }
    return data;
}

+ (NSData *)imageDataOfPerson:(NSString *)contactId {
    NSData *imageData = nil;

    CNContactStore *contactStore = [[CNContactStore alloc] init];
    NSArray *keys = @[CNContactThumbnailImageDataKey,
                      CNContactImageDataAvailableKey
                      ];
    CNContact *contact = [contactStore unifiedContactWithIdentifier:contactId
                                                        keysToFetch:keys
                                                              error:nil];

    if (contact) {
        if (contact.imageDataAvailable) {
            imageData = contact.thumbnailImageData;
        }
    }
    return imageData;
}

- (NSString *)getEffectiveTid {
    NSArray <NSString *> *components = [self.topic componentsSeparatedByString:@"/"];
    return [Friend effectiveTid:self.tid device:components.count ? components[components.count-1] : @"xx"];
}

+ (NSString *)effectiveTid:(NSString *)tid device:(NSString *)device {
    NSString *effectiveTid = @"";
    if (tid != nil && ![tid isEqualToString:@""]) {
        effectiveTid = tid;
    } else {
        NSUInteger length = device.length;
        if (length > 2) {
            effectiveTid = [device substringFromIndex:length - 2].uppercaseString;
        } else {
            effectiveTid = device.uppercaseString;
        }
    }
    return effectiveTid;
}

- (Waypoint *)newestWaypoint {
    Waypoint *newestWaypoint = nil;

    for (Waypoint *waypoint in [self.hasWaypoints copy]) {
        if (!newestWaypoint) {
            newestWaypoint = waypoint;
        } else {
            if ([newestWaypoint.tst compare:waypoint.tst] == NSOrderedAscending) {
                newestWaypoint = waypoint;
            }
        }
    }
    return newestWaypoint;
}

- (void)setCoordinate:(CLLocationCoordinate2D)coordinate {
    //
}

- (CLLocationCoordinate2D)coordinate {
    CLLocationCoordinate2D coord = kCLLocationCoordinate2DInvalid;
    Waypoint *waypoint = self.newestWaypoint;
    if (waypoint) {
        coord = CLLocationCoordinate2DMake((waypoint.lat).doubleValue, (waypoint.lon).doubleValue);
    }
    return coord;
}

- (MKMapRect)boundingMapRect {
    MKMapPoint point = MKMapPointForCoordinate(self.coordinate);
    MKMapRect mapRect = MKMapRectMake(
                                      point.x,
                                      point.y,
                                      1.0,
                                      1.0
                                      );
    if (self.hasWaypoints) {
        for (Waypoint *waypoint in self.hasWaypoints) {
            CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(
                                                                           (waypoint.lat).doubleValue,
                                                                           (waypoint.lon).doubleValue
                                                                           );
            MKMapPoint mapPoint = MKMapPointForCoordinate(coordinate);
            if (mapPoint.x < mapRect.origin.x) {
                mapRect.size.width += mapRect.origin.x - mapPoint.x;
                mapRect.origin.x = mapPoint.x;
            } else if (mapPoint.x + 3 > mapRect.origin.x + mapRect.size.width) {
                mapRect.size.width = mapPoint.x - mapRect.origin.x;
            }
            if (mapPoint.y < mapRect.origin.y) {
                mapRect.size.height += mapRect.origin.y - mapPoint.y;
                mapRect.origin.y = mapPoint.y;
            } else if (mapPoint.y > mapRect.origin.y + mapRect.size.height) {
                mapRect.size.height = mapPoint.y - mapRect.origin.y;
            }
        }
    }
    return mapRect;
}

- (MKPolyline *)polyLine {
    CLLocationCoordinate2D coordinate = self.coordinate;
    MKPolyline *polyLine = [MKPolyline polylineWithCoordinates:&coordinate count:1];

    NSSet *waypoints = self.hasWaypoints;
    if (waypoints && waypoints.count > 0) {
        CLLocationCoordinate2D *coordinates = malloc(waypoints.count * sizeof(CLLocationCoordinate2D));
        if (coordinates) {
            int count = 0;
            NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"tst" ascending:TRUE]];
            for (Waypoint *waypoint in [waypoints sortedArrayUsingDescriptors:sortDescriptors]) {
                coordinates[count++] = CLLocationCoordinate2DMake(
                                                                  (waypoint.lat).doubleValue,
                                                                  (waypoint.lon).doubleValue
                                                                  );
            }
        }
        polyLine = [MKPolyline polylineWithCoordinates:coordinates count:waypoints.count];
        free(coordinates);
    }
    return polyLine;
}

- (NSString *)title {
    return self.name ? self.name : self.topic;
}

- (NSString *)subtitle {
    Waypoint *waypoint = self.newestWaypoint;
    if (waypoint) {
        return [NSDateFormatter localizedStringFromDate:waypoint.tst
                                              dateStyle:NSDateFormatterShortStyle
                                              timeStyle:NSDateFormatterShortStyle];
    } else {
        return @"";
    }
}


@end
