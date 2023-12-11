//
//  NSDictionary+DSJSONDeepMutableCopy.h
//  libDSJSONSchemaValidation-iOS
//
//  Created by Andrew Podkovyrin on 07/09/2018.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary (DSJSONDeepMutableCopy)

/**
 Returns deep mutable copy of the receiver (only containers will be mutable)
 */
- (NSMutableDictionary *)ds_deepMutableCopy;

@end

NS_ASSUME_NONNULL_END
