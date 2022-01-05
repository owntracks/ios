//
//  NSNumber+decimals.h
//  OwnTracks
//
//  Created by Christoph Krey on 01.02.21.
//  Copyright © 2021-2022 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSNumber (decimals)
+ (NSDecimalNumber *)doubleValue:(double)d withDecimals:(int)decimals;
+ (NSDecimalNumber *)doubleValueWithSixDecimals:(double)d;
+ (NSDecimalNumber *)doubleValueWithThreeDecimals:(double)d;
+ (NSDecimalNumber *)doubleValueWithZeroDecimals:(double)d;

- (NSDecimalNumber *)decimals:(int)decimals;
- (NSDecimalNumber *)sixDecimals;
- (NSDecimalNumber *)threeDecimals;
- (NSDecimalNumber *)zeroDecimals;

@end

NS_ASSUME_NONNULL_END
