//
//  Friend.m
//  OwnTracks
//
//  Created by Christoph Krey on 28.09.15.
//  Copyright © 2015-2016 OwnTracks. All rights reserved.
//

#import "Friend.h"
#import "Location.h"
#import "Region.h"
#import "Waypoint.h"
#import "Settings.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@implementation Friend

static const DDLogLevel ddLogLevel = DDLogLevelError;

+ (ABAddressBookRef)theABRef
{
    static ABAddressBookRef ab = nil;

    if (!ab) {
        ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
        if (status == kABAuthorizationStatusAuthorized || status == kABAuthorizationStatusNotDetermined) {
            CFErrorRef error;
            ab = ABAddressBookCreateWithOptions(NULL, &error);
        }
    }

    return ab;
}

+ (Friend *)existsFriendWithTopic:(NSString *)topic
           inManagedObjectContext:(NSManagedObjectContext *)context

{
    Friend *friend = nil;

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Friend"];
    request.predicate = [NSPredicate predicateWithFormat:@"topic = %@", topic];

    NSError *error = nil;

    NSArray *matches = [context executeFetchRequest:request error:&error];

    if (!matches || [matches count] > 1) {
        // handle error
    } else {
        if ([matches count]) {
            friend = [matches lastObject];
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

+ (Friend *)friendWithTopic:(NSString *)topic
     inManagedObjectContext:(NSManagedObjectContext *)context

{
    Friend *friend = [self existsFriendWithTopic:topic inManagedObjectContext:context];

    if (!friend) {
        friend = [NSEntityDescription insertNewObjectForEntityForName:@"Friend" inManagedObjectContext:context];

        friend.topic = topic;
        friend.abRecordId = @(kABRecordInvalidID);
    }

    return friend;
}

- (NSString *)name
{
    NSString *name = self.cardName;

    ABRecordRef record = [self recordOfFriend];
    if (record) {
        NSString *nameOfPerson = [Friend nameOfPerson:record];
        if (nameOfPerson) {
            name = nameOfPerson;
        }
    }
    return name;
}

- (NSString *)nameOrTopic {
    return self.name ? self.name : self.topic;
}

+ (NSString *)nameOfPerson:(ABRecordRef)record
{
    NSString *name = nil;

    if (record) {
        CFStringRef nameRef = ABRecordCopyValue(record, kABPersonNicknameProperty);
        if (nameRef != NULL) {
            name = (NSString *)CFBridgingRelease(nameRef);
        } else {
            nameRef = ABRecordCopyCompositeName(record);
            if (nameRef != NULL) {
                name = (NSString *)CFBridgingRelease(nameRef);
            }
        }
    }
    return name;
}

- (NSData *)image
{
    NSData *data = self.cardImage;

    ABRecordRef record = [self recordOfFriend];
    if (record) {
        NSData *imageData = [Friend imageDataOfPerson:record];
        if (imageData) {
            data = imageData;
        }
    }
    return data;
}

+ (NSData *)imageDataOfPerson:(ABRecordRef)record
{
    NSData *imageData = nil;

    if (record) {
        if (ABPersonHasImageData(record)) {
            CFDataRef ir = ABPersonCopyImageDataWithFormat(record, kABPersonImageFormatThumbnail);
            imageData = CFBridgingRelease(ir);
        }
    }
    return imageData;
}

- (ABRecordRef)recordOfFriend
{
    ABRecordRef record = NULL;

    if ([Settings boolForKey:@"ab_preference"]) {
        record = recordWithTopic((__bridge CFStringRef)(self.topic));
    } else {
        if ([self.abRecordId intValue] != kABRecordInvalidID) {
            ABAddressBookRef ab = [Friend theABRef];
            if (ab) {
                record = ABAddressBookGetPersonWithRecordID(ab, [self.abRecordId intValue]);
            }
        }
    }
    return record;
}

- (void)linkToAB:(ABRecordRef)record
{
    if ([Settings boolForKey:@"ab_preference"]) {
        ABRecordRef oldrecord = recordWithTopic((__bridge CFStringRef)(self.topic));

        if (oldrecord) {
            [self ABsetTopic:nil record:oldrecord];
        }

        if (record) {
            [self ABsetTopic:self.topic record:record];
        }

    } else {
        ABRecordID abRecordID = ABRecordGetRecordID(record);
        self.abRecordId = @(abRecordID);
    }
}

#define RELATION_NAME CFSTR("OwnTracks")

ABRecordRef recordWithTopic(CFStringRef topic)
{
    ABRecordRef theRecord = NULL;
    ABAddressBookRef ab = [Friend theABRef];
    if (ab) {
        CFArrayRef records = ABAddressBookCopyArrayOfAllPeople(ab);

        if (records) {
            for (CFIndex i = 0; i < CFArrayGetCount(records); i++) {
                ABRecordRef record = CFArrayGetValueAtIndex(records, i);

                ABMultiValueRef relations = ABRecordCopyValue(record, kABPersonRelatedNamesProperty);
                if (relations) {
                    CFIndex relationsCount = ABMultiValueGetCount(relations);

                    for (CFIndex k = 0 ; k < relationsCount ; k++) {
                        CFStringRef label = ABMultiValueCopyLabelAtIndex(relations, k);
                        if (label != NULL) {
                            if (CFStringCompare(label, RELATION_NAME, kCFCompareCaseInsensitive) == kCFCompareEqualTo) {
                                CFStringRef value = ABMultiValueCopyValueAtIndex(relations, k);
                                if (value != NULL) {
                                    if (CFStringCompare(value, topic, kCFCompareCaseInsensitive) == kCFCompareEqualTo) {
                                        theRecord = record;
                                        CFRelease(label);
                                        CFRelease(value);
                                        break;
                                    }
                                    CFRelease(value);
                                }
                            }
                            CFRelease(label);
                        }
                    }
                    CFRelease(relations);
                }
                if (theRecord != NULL) {
                    break;
                }
            }
            CFRelease(records);
        }
    }
    return theRecord;
}

- (void)ABsetTopic:(NSString *)topic record:(ABRecordRef)record
{
    CFErrorRef errorRef;

    ABMutableMultiValueRef relationsRW;

    ABMultiValueRef relationsRO = ABRecordCopyValue(record, kABPersonRelatedNamesProperty);

    if (relationsRO) {
        relationsRW = ABMultiValueCreateMutableCopy(relationsRO);
        CFRelease(relationsRO);
    } else {
        relationsRW = ABMultiValueCreateMutable(kABMultiDictionaryPropertyType);
    }

    CFIndex relationsCount = ABMultiValueGetCount(relationsRW);
    CFIndex i;

    for (i = 0 ; i < relationsCount ; i++) {
        CFStringRef label = ABMultiValueCopyLabelAtIndex(relationsRW, i);
        if(CFStringCompare(label, RELATION_NAME, kCFCompareCaseInsensitive) == kCFCompareEqualTo) {
            if (topic) {
                if (!ABMultiValueReplaceValueAtIndex(relationsRW, (__bridge CFTypeRef)(topic), i)) {
                    DDLogError(@"Friend error ABMultiValueReplaceValueAtIndex %@ %ld", topic, i);
                }
            } else {
                if (!ABMultiValueRemoveValueAndLabelAtIndex(relationsRW, i))  {
                    DDLogError(@"Friend error ABMultiValueRemoveValueAndLabelAtIndex %ld", i);
                }
            }
            CFRelease(label);
            break;
        }
        CFRelease(label);
    }
    if (i == relationsCount) {
        if (topic) {
            if (!ABMultiValueAddValueAndLabel(relationsRW, (__bridge CFStringRef)(self.topic), RELATION_NAME, NULL)) {
                DDLogError(@"Friend error ABMultiValueAddValueAndLabel %@ %@", topic, RELATION_NAME);
            }
        }
    }

    if (!ABRecordSetValue(record, kABPersonRelatedNamesProperty, relationsRW, &errorRef)) {
        DDLogError(@"Friend error ABRecordSetValue %@", errorRef);
    }
    CFRelease(relationsRW);

    ABAddressBookRef ab = [Friend theABRef];
    if (ab) {
        if (ABAddressBookHasUnsavedChanges(ab)) {
            if (!ABAddressBookSave(ab, &errorRef)) {
                DDLogError(@"Friend error ABAddressBookSave %@", errorRef);
            }
        }
    }
}

- (NSString *)getEffectiveTid {
    NSString *tid = @"";
    if (self.tid != nil && ![self.tid isEqualToString:@""]) {
        tid = self.tid;
    } else {
        NSUInteger length = self.topic.length;
        if (length > 2) {
            tid = [self.topic substringFromIndex:length - 2].uppercaseString;
        } else {
            tid = self.topic.uppercaseString;
        }
    }
    return tid;
}

- (Waypoint *)newestWaypoint {
    Waypoint *newestWaypoint = nil;

    for (Waypoint *waypoint in self.hasWaypoints) {
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

- (CLLocationCoordinate2D)coordinate
{
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(0.0, 0.0);
    Waypoint *waypoint = [self newestWaypoint];
    if (waypoint) {
        coord = CLLocationCoordinate2DMake([waypoint.lat doubleValue], [waypoint.lon doubleValue]);
    }
    return coord;
}

- (MKMapRect)boundingMapRect {
    MKMapPoint point = MKMapPointForCoordinate([self coordinate]);
    MKMapRect mapRect = MKMapRectMake(
                                      point.x,
                                      point.y,
                                      1.0,
                                      1.0
                                      );
    if (self.hasWaypoints) {
        for (Waypoint *waypoint in self.hasWaypoints) {
            CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(
                                                                           [waypoint.lat doubleValue],
                                                                           [waypoint.lon doubleValue]
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
                                                                  [waypoint.lat doubleValue],
                                                                  [waypoint.lon doubleValue]
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
    Waypoint *waypoint = [self newestWaypoint];
    if (waypoint) {
        return [NSDateFormatter localizedStringFromDate:waypoint.tst
                                              dateStyle:NSDateFormatterShortStyle
                                              timeStyle:NSDateFormatterShortStyle];
    } else {
        return @"";
    }
}

@end
