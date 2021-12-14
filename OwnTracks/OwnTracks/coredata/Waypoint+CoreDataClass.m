//
//  Waypoint+CoreDataClass.m
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
//  Copyright © 2018-2021 OwnTracks. All rights reserved.
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

- (NSString *)coordinateText {
    return [NSString stringWithFormat:@"%g,%g (%@%.0f%@)",
            (self.lat).doubleValue,
            (self.lon).doubleValue,
            NSLocalizedString(@"±", @"Short for deviation plus/minus"),
            (self.acc).doubleValue,
            NSLocalizedString(@"m", @"Short for meters")
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
    return [NSString stringWithFormat:@"%@%0.f%@ (%@%.0f%@) %0.f%@ %0.f%@",
            NSLocalizedString(@"✈︎", @"Short for altitude as in ✈︎1000m"),
            (self.alt).doubleValue,
            NSLocalizedString(@"m", @"Short for meters"),
            NSLocalizedString(@"±", @"Short for deviation plus/minus"),
            (self.vac).doubleValue,
            NSLocalizedString(@"m", @"Short for meters"),
            (self.vel).doubleValue,
            NSLocalizedString(@"km/h", @"Short for kilometers per hour as in 120km/h"),
            (self.cog).doubleValue,
            NSLocalizedString(@"°", @"Short for degrees celsius as in 20°")
            ];
}

+ (NSString *)distanceText:(CLLocationDistance)distance {
    if (distance > 1000.0) {
        return [NSString stringWithFormat:@"%0.f%@",
                distance / 1000.0,
                NSLocalizedString(@"km", @"Short for kilometers as in 120km")
        ];
    } else {
        return [NSString stringWithFormat:@"%0.f%@",
                distance,
                NSLocalizedString(@"m", @"Short for meters")
        ];
    }
}

@end
