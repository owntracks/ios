//
//  NSNumber+decimals.m
//  OwnTracks
//
//  Created by Christoph Krey on 01.02.21.
//  Copyright © 2021-2025 OwnTracks. All rights reserved.
//

#import "NSNumber+decimals.h"

@implementation NSNumber (decimals)

+ (NSDecimalNumber *)doubleValue:(double)d withDecimals:(int)decimals {
    return [[NSNumber numberWithDouble:d] decimals:decimals];
}

+ (NSDecimalNumber *)doubleValueWithSixDecimals:(double)d {
    return [NSNumber numberWithDouble:d].sixDecimals;
}

+ (NSDecimalNumber *)doubleValueWithThreeDecimals:(double)d {
    return [NSNumber numberWithDouble:d].threeDecimals;
}

+ (NSDecimalNumber *)doubleValueWithZeroDecimals:(double)d {
    return [NSNumber numberWithDouble:d].zeroDecimals;
}

- (NSDecimalNumber *)decimals:(int)decimals {
    return [NSDecimalNumber decimalNumberWithString:
            [NSString stringWithFormat:@"%.*f",
             decimals, self.doubleValue]];

}
- (NSDecimalNumber *)sixDecimals {
    return [self decimals:6];
}

- (NSDecimalNumber *)threeDecimals {
    return [self decimals:3];
}

- (NSDecimalNumber *)zeroDecimals {
    return [self decimals:0];
}

@end
