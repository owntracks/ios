//
//  Subscriptions.h
//  OwnTracks
//
//  Created by Christoph Krey on 20.10.15.
//  Copyright © 2015 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@interface Subscriptions : NSObject <SKProductsRequestDelegate, SKPaymentTransactionObserver, SKRequestDelegate>
+ (Subscriptions *)sharedInstance;
@property (readonly, strong, nonatomic) NSNumber *recording;
- (void)payRecording;
@property (readonly, strong, nonatomic) NSString *subscriptionStatus;

@end
