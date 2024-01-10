//
//  NSNumber+metrics.h
//  OwnTracks
//
//  Created by Christoph Krey on 10.01.24.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define METER2FEET 3.28084
#define METER2KILOMETER 0.001
#define METER2MILE 0.00062137
#define METER2YARD 1.0936

@interface NSNumber (metrics)
- (NSString *)meterString;
- (NSString *)kilometerString;
- (NSString *)mileString;
- (NSString *)yardString;
- (NSString *)feetString;

- (NSString *)kilometerperhourString;
- (NSString *)milesperhourString;
@end

NS_ASSUME_NONNULL_END
