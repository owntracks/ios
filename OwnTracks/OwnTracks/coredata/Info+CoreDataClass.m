//
//  Info+CoreDataClass.m
//  OwnTracks
//
//  Created by Christoph Krey on 08.12.16.
//  Copyright © 2016-2018 OwnTracks. All rights reserved.
//

#import "Info+CoreDataClass.h"
#import "Subscription+CoreDataClass.h"
@implementation Info
- (CLLocationCoordinate2D)coordinate {
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake((self.lat).doubleValue,
                                                              (self.lon).doubleValue);
    return coord;
}

- (void)setCoordinate:(CLLocationCoordinate2D)coordinate {
    self.lat = @(coordinate.latitude);
    self.lon = @(coordinate.longitude);
}

- (NSString *)title {
    return self.name;
}

- (NSString *)subtitle {
    return self.identifier;
}

@end
