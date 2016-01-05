//
//  Waypoint+Create.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.06.15.
//  Copyright © 2015-2016 OwnTracks. All rights reserved.
//

#import "Waypoint+Create.h"
#import "Friend+Create.h"
#import <MapKit/MapKit.h>

@implementation Waypoint (Create)

- (void)getReverseGeoCode
{
    if (!self.placemark) {
        CLGeocoder *geocoder = [[CLGeocoder alloc] init];
        CLLocation *location = [[CLLocation alloc] initWithLatitude:[self.lat doubleValue]
                                                          longitude:[self.lon doubleValue]];
        [geocoder reverseGeocodeLocation:location completionHandler:
         ^(NSArray *placemarks, NSError *error) {
             if (!self.isDeleted) {
                 if ([placemarks count] > 0) {
                     CLPlacemark *placemark = placemarks[0];
                     NSArray *address = placemark.addressDictionary[@"FormattedAddressLines"];
                     if (address && [address count] >= 1) {
                         self.placemark = address[0];
                         for (int i = 1; i < [address count]; i++) {
                             self.placemark = [NSString stringWithFormat:@"%@, %@", self.placemark, address[i]];
                         }
                     }
                     self.belongsTo.topic = self.belongsTo.topic;
                 } else {
                     self.placemark = nil;
                 }
             }
         }];
    }
}

- (NSString *)coordinateText {
    return [NSString stringWithFormat:@"%g,%g (±%.0fm)",
            [self.lat doubleValue],
            [self.lon doubleValue],
            [self.acc doubleValue]];
}

- (NSString *)timestampText {
    return [NSDateFormatter localizedStringFromDate:self.tst
                                          dateStyle:NSDateFormatterShortStyle
                                          timeStyle:NSDateFormatterMediumStyle];
}

- (NSString *)infoText {
    return [NSString stringWithFormat:@"✈︎%0.fm (±%.0fm) %0.fkm/h %0.f°",
            [self.alt doubleValue],
            [self.vac doubleValue],
            [self.vel doubleValue],
            [self.cog doubleValue]
            ];
}


@end
