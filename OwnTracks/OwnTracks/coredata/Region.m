//
//  Region.m
//  OwnTracks
//
//  Created by Christoph Krey on 28.09.15.
//  Copyright © 2015-2017 OwnTracks. All rights reserved.
//

#import "Region.h"
#import "Friend+CoreDataClass.h"

@implementation Region

- (NSDate *)getAndFillTst {
    if (!self.tst) {
        self.tst = [NSDate date];
    }
    return self.tst;
}

- (CLLocationCoordinate2D)coordinate
{
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake([self.lat doubleValue],
                                                              [self.lon doubleValue]);
    return coord;
}

- (void)setCoordinate:(CLLocationCoordinate2D)coordinate {
    self.lat = [NSNumber numberWithDouble:coordinate.latitude];
    self.lon = [NSNumber numberWithDouble:coordinate.longitude];
}

- (MKMapRect)boundingMapRect
{
    return [MKCircle circleWithCenterCoordinate:self.coordinate radius:[self.radius doubleValue]].boundingMapRect;
}

- (MKCircle *)circle {
    return [MKCircle circleWithCenterCoordinate:self.coordinate radius:[self.radius doubleValue]];
}
- (NSString *)title {
    return self.name;
}

- (NSString *)subtitle {
    CLRegion *CLregion = self.CLregion;

    if ([CLregion isKindOfClass:[CLCircularRegion class]]) {
        return [NSString stringWithFormat:@"%g,%g r:%gm",
                [self.lat doubleValue],
                [self.lon doubleValue],
                [self.radius doubleValue]];
    } else if ([CLregion isKindOfClass:[CLBeaconRegion class]]) {
        return [NSString stringWithFormat:@"%@:%@:%@",
                self.uuid,
                self.major,
                self.minor];
    } else {
        return [NSString stringWithFormat:@"%g,%g",
                [self.lat doubleValue],
                [self.lon doubleValue]];

    }
}

- (CLRegion *)CLregion
{
    CLRegion *region = nil;

    if (self.name && self.name.length) {

        if ([self.radius doubleValue] > 0) {
            region = [[CLCircularRegion alloc] initWithCenter:self.coordinate
                                                       radius:[self.radius doubleValue]
                                                   identifier:self.name];
        } else {
            if (self.uuid) {
                CLBeaconRegion *beaconRegion;
                NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:self.uuid];

                if ([self.major unsignedIntValue] > 0) {
                    if ([self.minor unsignedIntValue] > 0) {
                        beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid
                                                                               major:[self.major unsignedIntValue]
                                                                               minor:[self.minor unsignedIntValue]
                                                                          identifier:self.name];
                    } else {
                        beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid
                                                                               major:[self.major unsignedIntValue]
                                                                          identifier:self.name];
                    }
                } else {
                    beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid
                                                                      identifier:self.name];
                }

                region = beaconRegion;
            }
        }
    }
    return region;
}

@end
