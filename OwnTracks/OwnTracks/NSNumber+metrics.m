//
//  NSNumber+metrics.m
//  OwnTracks
//
//  Created by Christoph Krey on 10.01.24.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import "NSNumber+metrics.h"

@implementation NSNumber (metrics)
- (NSString *)kilometerString {
    return [NSString stringWithFormat:@"%.0fkm",
            self.doubleValue * METER2KILOMETER];
}

- (NSString *)meterString {
    return [NSString stringWithFormat:@"%.0fm",
            self.doubleValue];
}

- (NSString *)mileString {
    return [NSString stringWithFormat:@"%.0fmi",
            self.doubleValue * METER2MILE];
}

- (NSString *)yardString {
    return [NSString stringWithFormat:@"%.0fyd",
            self.doubleValue * METER2YARD];
}

- (NSString *)feetString {
    return [NSString stringWithFormat:@"%.0fft",
            self.doubleValue * METER2FEET];
}

-(NSString *)kilometerperhourString {
    return [NSString stringWithFormat:@"%.0fkm/h",
            self.doubleValue];
}

- (NSString *)milesperhourString {
    return [NSString stringWithFormat:@"%.0fmph",
            self.doubleValue * METER2MILE * 1000.0];

}
@end
