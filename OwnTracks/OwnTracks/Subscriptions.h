//
//  Subscriptions.h
//  OwnTracks
//
//  Created by Christoph Krey on 20.10.15.
//  Copyright © 2015 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#define SUBSCRIPTION @"recording1m"

@interface Subscriptions : NSObject <SKRequestDelegate, SKPaymentTransactionObserver>
+ (Subscriptions *)sharedInstance;
@property (readonly, strong, nonatomic) NSNumber *recording;
@property (readonly, strong, nonatomic) NSDate *purchased;
@property (readonly, strong, nonatomic) NSDate *expires;
@property (readonly, strong, nonatomic) NSDate *checked;

@end
