//
//  Location+Create.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "Location+Create.h"
#import <AddressBookUI/AddressBookUI.h>
#import "Friend+Create.h"

@implementation Location (Create)

+ (Location *)locationWithTopic:(NSString *)topic
                      timestamp:(NSDate *)timestamp
                     coordinate:(CLLocationCoordinate2D)coordinate
                       accuracy:(CLLocationAccuracy)accuracy
                      automatic:(BOOL)automatic
                      remark:(NSString *)remark
                      radius:(CLLocationDistance)radius
                          share:(BOOL)share
         inManagedObjectContext:(NSManagedObjectContext *)context;
{
    Location *location = nil;
    
    Friend *friend = [Friend friendWithTopic:topic inManagedObjectContext:context];
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Location"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO]];
    request.predicate = [NSPredicate predicateWithFormat:@"timestamp = %@ AND belongsTo = %@ AND automatic = %@", timestamp, friend, @(automatic)];

    NSError *error = nil;
    
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (!matches) {
        // handle error
    } else {
        if (![matches count]) {
            //create new location
            location = [NSEntityDescription insertNewObjectForEntityForName:@"Location" inManagedObjectContext:context];
            location.justcreated = @(TRUE);
        } else {
            location = [matches lastObject];
            location.justcreated = @(TRUE);
        }
        location.belongsTo = friend;
        location.timestamp = timestamp;
        [location setCoordinate:coordinate];
        location.accuracy = @(accuracy);
        location.automatic = @(automatic);
        location.remark = remark;
        location.regionradius = @(radius);
        location.share = @(share);
    }
    
    return location;
}

+ (NSArray *)allLocationsInManagedObjectContext:(NSManagedObjectContext *)context
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Location"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO]];
    
    NSError *error = nil;
    
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    return matches;
}

+ (NSArray *)allValidLocationsInManagedObjectContext:(NSManagedObjectContext *)context
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Location"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO]];
    request.predicate = [NSPredicate predicateWithFormat:@"latitude != 0 OR longitude != 0"];
    
    NSError *error = nil;
    
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    return matches;
}

+ (NSArray *)allWaypointsOfTopic:(NSString *)topic inManagedObjectContext:(NSManagedObjectContext *)context
{
    Friend *friend = [Friend friendWithTopic:topic inManagedObjectContext:context];
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Location"];
    request.predicate = [NSPredicate predicateWithFormat:@"belongsTo = %@ AND automatic = FALSE AND remark != NIL", friend];
    
    NSError *error = nil;
    
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    return matches;
}

+ (NSArray *)allAutomaticLocationsWithFriend:(Friend *)friend inManagedObjectContext:(NSManagedObjectContext *)context
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Location"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO]];
    request.predicate = [NSPredicate predicateWithFormat:@"belongsTo = %@ AND automatic = TRUE", friend];

    NSError *error = nil;
    
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    return matches;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ %@", self.title, self.subtitle];
}

- (NSString *)title {
    return [NSString stringWithFormat:@"%@ %@", [self nameText], (![self.automatic boolValue] && self.remark ) ? self.remark : @""];
}

- (NSString *)subtitle {
    return [NSString stringWithFormat:@"%@ %@",
            [NSDateFormatter localizedStringFromDate:self.timestamp
                                           dateStyle:NSDateFormatterShortStyle
                                           timeStyle:NSDateFormatterShortStyle],
            [self locationText]];
}

- (NSString *)nameText
{
    return self.belongsTo ? (self.belongsTo.name ? self.belongsTo.name : self.belongsTo.topic) : @"";
}
- (NSString *)timestampText
{
    return [NSDateFormatter localizedStringFromDate:self.timestamp
                                          dateStyle:NSDateFormatterShortStyle
                                          timeStyle:NSDateFormatterMediumStyle];
}
- (NSString *)locationText
{
    return [NSString stringWithFormat:@"%@ (±%.0fm)",
            (self.placemark) ? self.placemark :
            [NSString stringWithFormat:@"%g,%g", self.coordinate.latitude, self.coordinate.longitude],
            [self.accuracy doubleValue]];
}

- (NSString *)coordinateText
{
    return [NSString stringWithFormat:@"%g,%g (±%.0fm)",
            self.coordinate.latitude,
            self.coordinate.longitude,
            [self.accuracy doubleValue]];
}

- (NSString *)radiusText
{
    return [NSString stringWithFormat:@"%.0f", [self.regionradius doubleValue]];
}

- (CLLocationCoordinate2D)coordinate
{
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake([self.latitude doubleValue], [self.longitude doubleValue]);
    return coord;
}

- (void)setCoordinate:(CLLocationCoordinate2D)coordinate
{
    self.latitude = @(coordinate.latitude);
    self.longitude = @(coordinate.longitude);
    
    /*
     * We could get the Reverse GeoCode here automatically, but this would cost mobile data. If necessary, call getReverseGeoCode directly for actually shown locations
     *
     [self getReversGeoCode];
     *
     */
}


- (void)getReverseGeoCode
{
    if (!self.placemark) {
        CLGeocoder *geocoder = [[CLGeocoder alloc] init];
        CLLocation *location = [[CLLocation alloc] initWithCoordinate:self.coordinate altitude:0 horizontalAccuracy:0 verticalAccuracy:0 course:0 speed:0 timestamp:0];
        [geocoder reverseGeocodeLocation:location completionHandler:
         ^(NSArray *placemarks, NSError *error) {
             if (!self.isDeleted) {
                 if ([placemarks count] > 0) {
                     CLPlacemark *placemark = placemarks[0];
                     self.placemark = ABCreateStringWithAddressDictionary (placemark.addressDictionary, TRUE);
                     self.placemark = [self.placemark stringByReplacingOccurrencesOfString:@"\n" withString:@", "];
                 } else {
                     self.placemark = nil;
                 }
             }
         }];
    }
}

- (CLRegion *)region
{
    CLRegion *region = nil;
    
    // a location qualifies being a region if
    //
    // it was not created automatically
    // it has a remark which is not zero length
    //
    // it either has
    // a radius > 0 set: then it is a circular region
    //
    // a remark that is a valid UUID string: then it is treated a beacon region
    //
    
    if (![self.automatic boolValue] && self.remark && self.remark.length) {
        
        if ([self.regionradius doubleValue] > 0) {
            region = [[CLCircularRegion alloc] initWithCenter:self.coordinate
                                                       radius:[self.regionradius doubleValue]
                                                   identifier:self.remark];
        } else {
            NSArray *components = [self.remark componentsSeparatedByString:@":"];
            if (components) {
                NSUUID *uuid = nil;
                NSNumber *major = nil;
                NSNumber *minor = nil;
                
                if ([components count] > 1) {
                    uuid = [[NSUUID alloc] initWithUUIDString:components[1]];
                }

                if ([components count] > 2) {
                    unsigned int u;
                    if ([[NSScanner scannerWithString:components[2]] scanHexInt:&u]) {
                        major = @(u);
                    }
                }
                
                if ([components count] > 3) {
                    unsigned int u;
                    if ([[NSScanner scannerWithString:components[3]] scanHexInt:&u]) {
                        minor = @(u);
                    }
                }

                if (uuid) {
                    CLBeaconRegion *beaconRegion;

                    if (major) {
                        if (minor) {
                            beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid
                                                                                   major:[major intValue]
                                                                                   minor:[minor intValue]
                                                                              identifier:components[0]];
                        } else {
                            beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid
                                                                                   major:[major intValue]
                                                                              identifier:components[0]];
                        }
                    } else {
                        beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid
                                                                          identifier:components[0]];
                    }
                    
                    region = beaconRegion;
                    
                    // make sure the app is woken up if the device is switched on within the beacon region
                    // beaconRegion.notifyEntryStateOnDisplay = TRUE;
                    
                }
            }
            
        }
    }
    return region;
}

- (BOOL)sharedWaypoint
{
    if (self.remark && self.remark.length && [self.share boolValue]) {
        return TRUE;
    } else {
        return FALSE;
    }
}

- (MKMapRect)boundingMapRect
{
    return [MKCircle circleWithCenterCoordinate:self.coordinate radius:self.radius].boundingMapRect;
}

- (CLLocationDistance)radius
{
    return [self.regionradius doubleValue];
}


@end
