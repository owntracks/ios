//
//  Waypoint+CoreDataClass.m
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
//  Copyright © 2018-2024 OwnTracks. All rights reserved.
//
//

#import "Waypoint+CoreDataClass.h"
#import "Friend+CoreDataClass.h"
#import <MapKit/MapKit.h>
#import <Contacts/Contacts.h>
#import "CoreData.h"

@implementation Waypoint

- (void)getReverseGeoCode {
    if (!self.placemark) {
        CLGeocoder *geocoder = [[CLGeocoder alloc] init];
        CLLocation *location = [[CLLocation alloc] initWithLatitude:(self.lat).doubleValue
                                                          longitude:(self.lon).doubleValue];
        [geocoder reverseGeocodeLocation:location completionHandler:
         ^(NSArray *placemarks, NSError *error) {
             [self.managedObjectContext performBlock:^{
                 if (!self.isDeleted) {
                     if (placemarks.count > 0) {
                         CLPlacemark *placemark = placemarks[0];
                         CNPostalAddress *postalAddress = placemark.postalAddress;
                         self.placemark = [CNPostalAddressFormatter
                                           stringFromPostalAddress:postalAddress
                                           style:CNPostalAddressFormatterStyleMailingAddress];
                     } else {
                         self.placemark = [NSString stringWithFormat:@"%@\n%@ %ld\n%@",
                                           NSLocalizedString(@"Address resolver failed", @"reverseGeocodeLocation error"),
                                           error.domain,
                                           (long)error.code,
                                           NSLocalizedString(@"due to rate limit or off-line", @"reverseGeocodeLocation text")
                                           ];
                     }
                     self.belongsTo.topic = self.belongsTo.topic;
                     [CoreData.sharedInstance sync:self.managedObjectContext];
                 }
             }];
         }];
    }
}

- (CLLocationDistance)getDistanceFrom:(CLLocation *)fromLocation {
    CLLocation *location = [[CLLocation alloc] initWithLatitude:(self.lat).doubleValue
                                                      longitude:(self.lon).doubleValue];
    return [location distanceFromLocation:fromLocation];
}

- (NSString *)shortCoordinateText {
    return [NSString stringWithFormat:@"%g,%g",
            (self.lat).doubleValue,
            (self.lon).doubleValue
            ];
}

+ (NSString *)CLLocationAccuracyText:(CLLocation *)location {
    if (location && 
        CLLocationCoordinate2DIsValid(location.coordinate) &&
        location.horizontalAccuracy >= 0.0) {
        NSMeasurement *m = [[NSMeasurement alloc] initWithDoubleValue:location.horizontalAccuracy
                                                                 unit:[NSUnitLength meters]];
        NSMeasurementFormatter *mf = [[NSMeasurementFormatter alloc] init];
        mf.unitOptions = NSMeasurementFormatterUnitOptionsNaturalScale;
        mf.numberFormatter.maximumFractionDigits = 0;
        
        return [NSString stringWithFormat:@"±%@",
                [mf stringFromMeasurement:m]];
    } else {
        return @"-";
    }
}

+ (NSString *)CLLocationCoordinateText:(CLLocation *)location {
    if (location && CLLocationCoordinate2DIsValid(location.coordinate)) {
        return [NSString stringWithFormat:@"%g,%g (%@)",
                location.coordinate.latitude,
                location.coordinate.longitude,
                [Waypoint CLLocationAccuracyText:location]];
    } else {
        return @"-";
    }
}

- (NSString *)coordinateText {
    CLLocation *location = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake((self.lat).doubleValue,
                                                                                             (self.lon).doubleValue)
                                                         altitude:(self.alt).doubleValue
                                               horizontalAccuracy:(self.acc).doubleValue
                                                 verticalAccuracy:(self.vac).doubleValue
                                                        timestamp:self.tst];
    return [Waypoint CLLocationCoordinateText:location];
}

- (NSString *)timestampText {
    return [NSDateFormatter localizedStringFromDate:self.tst
                                          dateStyle:NSDateFormatterShortStyle
                                          timeStyle:NSDateFormatterMediumStyle];
}

- (NSString *)createdAtText {
    return [NSDateFormatter localizedStringFromDate:self.createdAt
                                          dateStyle:NSDateFormatterShortStyle
                                          timeStyle:NSDateFormatterMediumStyle];
}

- (NSDate *)effectiveTimestamp {
    if (self.createdAt != nil &&
        self.createdAt.timeIntervalSince1970 > self.tst.timeIntervalSince1970) {
        return self.createdAt;
    }
    return self.tst;
}

- (NSString *)infoText {
    NSMeasurement *mAlt = [[NSMeasurement alloc] initWithDoubleValue:(self.alt).doubleValue
                                                                unit:[NSUnitLength meters]];
    NSMeasurement *mVac = [[NSMeasurement alloc] initWithDoubleValue:(self.vac).doubleValue
                                                                unit:[NSUnitLength meters]];
    NSMeasurement *mVel = [[NSMeasurement alloc] initWithDoubleValue:(self.vel).doubleValue
                                                                unit:[NSUnitSpeed kilometersPerHour]];
    NSMeasurement *mCog = [[NSMeasurement alloc] initWithDoubleValue:(self.cog).doubleValue
                                                                unit:[NSUnitAngle degrees]];

    NSMeasurementFormatter *mf = [[NSMeasurementFormatter alloc] init];
    mf.unitOptions = NSMeasurementFormatterUnitOptionsNaturalScale;
    mf.numberFormatter.maximumFractionDigits = 0;

    return [NSString stringWithFormat:@"%@ (%@) %@ %@",
            (self.vac).doubleValue > 0.0 ?
            [NSString stringWithFormat:@"✈︎%@",
             [mf stringFromMeasurement:mAlt]] :
                @"-",
            (self.vac).doubleValue > 0.0 ?
            [NSString stringWithFormat:@"±%@",
             [mf stringFromMeasurement:mVac]] :
                @"-",
            (self.vel).doubleValue >= 0.0 ? 
            [mf stringFromMeasurement:mVel] :
                @"-",
            (self.cog).doubleValue >= 0.0 ?
            [mf stringFromMeasurement:mCog] :
                @"-"
            ];
}

+ (NSString *)distanceText:(CLLocationDistance)distance {
    NSMeasurement *m = [[NSMeasurement alloc] initWithDoubleValue:distance
                                                             unit:[NSUnitLength meters]];
    NSMeasurementFormatter *mf = [[NSMeasurementFormatter alloc] init];
    mf.unitOptions = NSMeasurementFormatterUnitOptionsNaturalScale;
    mf.numberFormatter.maximumFractionDigits = 0;

    return [mf stringFromMeasurement:m];
}

- (NSString *)batteryLevelText {
    NSLog(@"self.batt %@", self.batt);
    if (self.batt && self.batt.doubleValue >= 0.0) {
        NSString *text = [NSString stringWithFormat:@"%0.f%%",
                          (self.batt).doubleValue * 100.0
                          ];
        return text;
    } else {
        return @"-";
    }
}

- (NSString *)defaultPlacemark {
    return [NSString stringWithFormat:@"%@\n%@",
            NSLocalizedString(@"Address resolver disabled", @"Address resolver disabled"),
            self.coordinateText];
}

#pragma MKAnnotation

- (void)setCoordinate:(CLLocationCoordinate2D)newCoordinate {
    //
}

- (CLLocationCoordinate2D)coordinate {
    return CLLocationCoordinate2DMake((self.lat).doubleValue, (self.lon).doubleValue);
}

- (NSString *)title {
    return self.poi ? self.poi : self.placemark ? self.placemark : self.shortCoordinateText;
}

- (NSString *)subtitle {
    return self.poi ? self.placemark : nil;
}

@end
