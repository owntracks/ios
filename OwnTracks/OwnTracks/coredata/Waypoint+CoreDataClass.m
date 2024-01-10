//
//  Waypoint+CoreDataClass.m
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
//  Copyright © 2018-2022 OwnTracks. All rights reserved.
//
//

#import "Waypoint+CoreDataClass.h"
#import "Friend+CoreDataClass.h"
#import <MapKit/MapKit.h>
#import <Contacts/Contacts.h>
#import "CoreData.h"
#import "NSNumber+metrics.h"

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

- (NSString *)coordinateText {
    return [NSString stringWithFormat:@"%g,%g (±%@)",
            (self.lat).doubleValue,
            (self.lon).doubleValue,
            [NSLocale currentLocale].usesMetricSystem ?
            (self.acc).meterString : (self.acc).feetString
            ];
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
    return [NSString stringWithFormat:@"✈︎%@ (±%@) %@ %0.f%@",
            [NSLocale currentLocale].usesMetricSystem ?
            (self.alt).meterString : (self.alt).feetString,
            [NSLocale currentLocale].usesMetricSystem ?
            (self.vac).meterString : (self.vac).feetString,
            [NSLocale currentLocale].usesMetricSystem ?
            (self.vel).kilometerperhourString : (self.vel).milesperhourString,
            (self.cog).doubleValue,
            NSLocalizedString(@"°", @"Short for degrees celsius as in 20°")
            ];
}

+ (NSString *)distanceText:(CLLocationDistance)distance {
    if ([NSLocale currentLocale].usesMetricSystem) {
        if (distance * METER2KILOMETER > 1.0) {
            return @(distance).kilometerString;
        } else {
            return @(distance).meterString;
        }
    } else {
        if (distance * METER2MILE > 1.0) {
            return @(distance).mileString;
        } else {
            return @(distance).yardString;
        }
    }
}

- (NSString *)batteryLevelText {
    NSLog(@"self.batt %@", self.batt);
    if (self.batt && self.batt.doubleValue >= 0.0) {
        NSString *text = [NSString stringWithFormat:@"%0.f%%",
                          (self.batt).doubleValue * 100.0
                          ];
        return text;
    } else {
        return @" ";
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
