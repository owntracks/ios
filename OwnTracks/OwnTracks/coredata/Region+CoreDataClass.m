//
//  Region+CoreDataClass.m
//  OwnTracks
//
//  Created by Christoph Krey on 30.05.18.
//  Copyright © 2018-2024 OwnTracks. All rights reserved.
//
//

#import "Region+CoreDataClass.h"
#import "Friend+CoreDataClass.h"
#import <CommonCrypto/CommonHMAC.h>

@interface NSString (sha)
- (NSString *)sha;
- (NSString *)sha6;
@end

@implementation NSString (sha)
- (NSString *)sha {
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    NSData *stringBytes = [self dataUsingEncoding: NSUTF8StringEncoding];
    (void)CC_SHA1([stringBytes bytes],
                  (unsigned int)[stringBytes length],
                  digest);
    NSString *shaString = [[NSString alloc] init];
    for (NSInteger i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        shaString = [shaString stringByAppendingFormat:@"%02x",
                     digest[i]];
    }
    return shaString;
}

- (NSString *)sha6 {
    return [[self sha] substringToIndex:6];
}
@end

@implementation CLRegion (follow)
- (BOOL)isFollow {
    return [self.identifier hasPrefix:@"+"];
}
@end

@implementation Region

+ (NSString *)ridFromTst:(NSDate *)tst andName:(NSString *)name {
    NSString *string = [NSString stringWithFormat:@"%@-%.0f",
                        name,
                        tst.timeIntervalSince1970];
    return string.sha6;
}

+ (NSString *)newRid {
    return [NSUUID UUID].UUIDString.sha6;
}

- (NSString *)getAndFillRid {
    if (!self.rid) {
        self.rid = [Region ridFromTst:self.tst andName:self.name];
    }
    return self.rid;
}

- (NSDate *)getAndFillTst {
    if (!self.tst) {
        self.tst = [NSDate date];
    }
    return self.tst;
}


- (CLLocationCoordinate2D)coordinate {
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake((self.lat).doubleValue,
                                                              (self.lon).doubleValue);
    return coord;
}

- (void)setCoordinate:(CLLocationCoordinate2D)coordinate {
    self.lat = @(coordinate.latitude);
    self.lon = @(coordinate.longitude);
}

- (MKMapRect)boundingMapRect {
    return [MKCircle circleWithCenterCoordinate:self.coordinate radius:(self.radius).doubleValue].boundingMapRect;
}

- (MKCircle *)circle {
    return [MKCircle circleWithCenterCoordinate:self.coordinate radius:(self.radius).doubleValue];
}

- (NSString *)title {
    return self.name;
}

- (NSString *)subtitle {
    CLRegion *CLregion = self.CLregion;

    if ([CLregion isKindOfClass:[CLCircularRegion class]]) {
        return [NSString stringWithFormat:@"%g,%g r:%gm",
                (self.lat).doubleValue,
                (self.lon).doubleValue,
                (self.radius).doubleValue];
    } else if ([CLregion isKindOfClass:[CLBeaconRegion class]]) {
        return [NSString stringWithFormat:@"%@:%@:%@",
                self.uuid,
                self.major,
                self.minor];
    } else {
        return [NSString stringWithFormat:@"%g,%g",
                (self.lat).doubleValue,
                (self.lon).doubleValue];

    }
}

- (CLRegion *)CLregion {
    CLRegion *region = nil;

    if (self.name && self.name.length) {

        if ((self.radius).doubleValue > 0) {
            region = [[CLCircularRegion alloc] initWithCenter:self.coordinate
                                                       radius:(self.radius).doubleValue
                                                   identifier:self.name];
        } else {
            if (self.uuid) {
                CLBeaconRegion *beaconRegion;
                NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:self.uuid];

                if ((self.major).unsignedIntValue > 0) {
                    if ((self.minor).unsignedIntValue > 0) {
                        beaconRegion = [[CLBeaconRegion alloc]
                                        initWithUUID:uuid
                                        major:(self.major).unsignedIntValue
                                        minor:(self.minor).unsignedIntValue
                                        identifier:self.name];
                    } else {
                        beaconRegion = [[CLBeaconRegion alloc]
                                        initWithUUID:uuid
                                        major:(self.major).unsignedIntValue
                                        identifier:self.name];
                    }
                } else {
                    beaconRegion = [[CLBeaconRegion alloc]
                                    initWithUUID:uuid
                                    identifier:self.name];
                }
                region = beaconRegion;
            }
        }
    }
    return region;
}

@end
