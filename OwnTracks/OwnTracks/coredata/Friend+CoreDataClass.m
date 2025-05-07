//
//  Friend+CoreDataClass.m
//  OwnTracks
//
//  Created by Christoph Krey on 08.12.16.
//  Copyright © 2016-2025  OwnTracks. All rights reserved.
//

#import "Friend+CoreDataClass.h"
#import "Region+CoreDataClass.h"
#import "Waypoint+CoreDataClass.h"
#import "Settings.h"
#import "CoreData.h"
#import <Contacts/Contacts.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

@implementation Friend
static const DDLogLevel ddLogLevel = DDLogLevelInfo;

+ (Friend *)existsFriendWithTopic:(NSString *)topic
           inManagedObjectContext:(NSManagedObjectContext *)context {
    Friend *friend = nil;

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Friend"];
    request.predicate = [NSPredicate predicateWithFormat:@"topic = %@", topic];

    NSError *error = nil;

    NSArray *matches = [context executeFetchRequest:request error:&error];

    if (!matches) {
        // handle error
    } else {
        if (matches.count) {
            friend = matches.lastObject;
        }
    }

    return friend;
}

+ (void)deleteAllFriendsInManagedObjectContext:(NSManagedObjectContext *)context {
    NSArray *friends = [Friend allFriendsInManagedObjectContext:context];
    for (Friend *friend in friends) {
        [context deleteObject:friend];
    }
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
            if ([newestWaypoint.effectiveTimestamp compare:waypoint.effectiveTimestamp] == NSOrderedAscending) {
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
    __block MKPolyline *polyLine = [MKPolyline polylineWithCoordinates:&coordinate count:1];

    [self.managedObjectContext performBlockAndWait:^{
        NSFetchRequest<Waypoint *> *request = Waypoint.fetchRequest;
        request.predicate = [NSPredicate predicateWithFormat:@"belongsTo = %@", self];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"tst" ascending:FALSE]];
        request.fetchLimit = 1000;
        NSError *error;
        NSArray <Waypoint *>*result = [request execute:&error];
        NSLog(@"error:%@ result:%@", error, result);
        if (result && result.count > 0) {
            CLLocationCoordinate2D *coordinates = malloc(result.count * sizeof(CLLocationCoordinate2D));
            if (coordinates) {
                int count = 0;
                for (Waypoint *waypoint in result) {
                    coordinates[count++] =
                    CLLocationCoordinate2DMake((waypoint.lat).doubleValue,
                                               (waypoint.lon).doubleValue);
                }
                polyLine = [MKPolyline polylineWithCoordinates:coordinates count:result.count];
                free(coordinates);
            }
        }
    }];
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

- (Waypoint *)addWaypoint:(CLLocation *)location
                createdAt:(NSDate *)createdAt
                  trigger:(NSString *)trigger
                      poi:(NSString *)poi
                      tag:(NSString *)tag
                  battery:(NSNumber *)battery
                    image:(NSData *)image
                imageName:(NSString *)imageName
                inRegions:(NSArray<NSString *> *)inRegions
                   inRids:(NSArray<NSString *> *)inRids
                    bssid:(NSString *)bssid
                     ssid:(NSString *)ssid
                        m:(NSNumber *)m
                     conn:(NSString *)conn
                       bs:(NSNumber *)bs {
    Waypoint *waypoint = [NSEntityDescription insertNewObjectForEntityForName:@"Waypoint"
                                                       inManagedObjectContext:self.managedObjectContext];
    waypoint.belongsTo = self;
    waypoint.trigger = trigger;
    waypoint.poi = poi;
    waypoint.tag = tag;
    waypoint.acc = @(location.horizontalAccuracy);
    waypoint.alt = @(location.altitude);
    waypoint.lat = @(location.coordinate.latitude);
    waypoint.lon = @(location.coordinate.longitude);
    waypoint.vac = @(location.verticalAccuracy);
    waypoint.tst = location.timestamp;
    waypoint.createdAt = createdAt;
    waypoint.batt = battery;
    double speed = location.speed;
    if (speed != -1) {
        speed = speed * 3600 / 1000;
    }
    waypoint.vel = @(speed);
    waypoint.cog = @(location.course);
    waypoint.placemark = nil;
    waypoint.image = image;
    waypoint.imageName = imageName;
    if (inRegions && [NSJSONSerialization isValidJSONObject:inRegions]) {
        waypoint.inRegions = [NSJSONSerialization dataWithJSONObject:inRegions
                                                             options:0
                                                               error:nil];
    } else {
        waypoint.inRegions = nil;
    }
    if (inRids && [NSJSONSerialization isValidJSONObject:inRids]) {
        waypoint.inRids = [NSJSONSerialization dataWithJSONObject:inRids
                                                          options:0
                                                            error:nil];
    } else {
        waypoint.inRids = nil;
    }
    waypoint.ssid = ssid;
    waypoint.bssid = bssid;
    waypoint.bs = bs;
    waypoint.m = m;
    waypoint.conn = conn;

    [[CoreData sharedInstance] sync:waypoint.managedObjectContext];
    return waypoint;
}

- (NSInteger)limitWaypointsToMaximum:(NSInteger)max {
    if (max < 1) {
        max = 1;
    }
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;

    for (NSInteger i = self.hasWaypoints.count; i > max; i--) {
        DDLogVerbose(@"count=%ld i=%ld max=%ld", self.hasWaypoints.count, i, max);
        Waypoint *oldestWaypoint = nil;
        for (Waypoint *waypoint in self.hasWaypoints) {
            if (!waypoint.isDeleted) {
                if (!oldestWaypoint || [oldestWaypoint.tst compare:waypoint.tst] == NSOrderedDescending) {
                    oldestWaypoint = waypoint;
                }
            }
        }
        if (oldestWaypoint) {
            DDLogVerbose(@"delete i=%ld %@", i, [formatter stringFromDate:oldestWaypoint.tst]);
            [self.managedObjectContext deleteObject:oldestWaypoint];
        }
    }

    Waypoint *newestWaypoint = nil;
    for (Waypoint *waypoint in self.hasWaypoints) {
        if (!waypoint.isDeleted) {
            if (!newestWaypoint || [newestWaypoint.tst compare:waypoint.tst] == NSOrderedAscending) {
                newestWaypoint = waypoint;
            }
        }
    }

    if (newestWaypoint && ![newestWaypoint.tst isEqualToDate:self.lastLocation]) {
        self.lastLocation = newestWaypoint.tst;
    }
    [CoreData.sharedInstance sync:self.managedObjectContext];
    return self.hasWaypoints.count;
}

- (NSInteger)limitWaypointsToMaximumDays:(NSInteger)days {
    if (days <= 0) {
        return [self limitWaypointsToMaximum:1];
    }
    
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;
    NSDate *oldest = [NSDate dateWithTimeIntervalSinceNow:-24.0*60.0*60.0*(days+1.0)];

    for (Waypoint *waypoint in self.hasWaypoints) {
        if (!waypoint.isDeleted && [waypoint.tst compare:oldest] == NSOrderedAscending) {
            DDLogVerbose(@"delete oldest=%@ > %@",
                         [formatter stringFromDate:oldest],
                         [formatter stringFromDate:waypoint.tst]);
            [self.managedObjectContext deleteObject:waypoint];
        }
    }

    Waypoint *newestWaypoint = nil;
    for (Waypoint *waypoint in self.hasWaypoints) {
        if (!newestWaypoint || (!waypoint.isDeleted && [newestWaypoint.tst compare:waypoint.tst] == NSOrderedAscending)) {
            newestWaypoint = waypoint;
        }
    }

    if (newestWaypoint && ![newestWaypoint.tst isEqualToDate:self.lastLocation]) {
        self.lastLocation = newestWaypoint.tst;
    }
    [CoreData.sharedInstance sync:self.managedObjectContext];
    return self.hasWaypoints.count;
}

- (void)trackToGPX:(NSOutputStream *)output {
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    NSString *xml = @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>";
    xml = [xml stringByAppendingString:@"\n<gpx xmlns=\"http://www.topografix.com/GPX/1/1\" version=\"1.1\" creator=\"OwnTracks\">"];
    xml = [xml stringByAppendingString:@"\n<trk><trkseg>"];
    NSData *data = [xml dataUsingEncoding:NSUTF8StringEncoding];
    [output write:data.bytes maxLength:data.length];
    
    [self.managedObjectContext performBlockAndWait:^{
        NSFetchRequest<Waypoint *> *request = Waypoint.fetchRequest;
        request.predicate = [NSPredicate predicateWithFormat:@"belongsTo = %@", self];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"tst" ascending:TRUE]];
        NSError *error;
        NSArray <Waypoint *>*result = [request execute:&error];
        NSLog(@"error:%@ result:%@", error, result);
        for (Waypoint *waypoint in result) {
            NSString *xml = [NSString stringWithFormat:@"\n<trkpt lat=\"%.6f\" lon=\"%.6f\"><ele>%.2f</ele><time>%@</time></trkpt>",
                   waypoint.lat.doubleValue,
                   waypoint.lon.doubleValue,
                   waypoint.alt.doubleValue,
                   [formatter stringFromDate:waypoint.tst]
            ];
            NSData *data = [xml dataUsingEncoding:NSUTF8StringEncoding];
            [output write:data.bytes maxLength:data.length];
        }
    }];

    xml = @"\n</trkseg></trk></gpx>";
    data = [xml dataUsingEncoding:NSUTF8StringEncoding];
    [output write:data.bytes maxLength:data.length];
}

@end
