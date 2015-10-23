//
//  BuyTVC.h
//  OwnTracks
//
//  Created by Christoph Krey on 23.10.15.
//  Copyright © 2015 OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

@interface BuyTVC : UITableViewController <SKProductsRequestDelegate, SKRequestDelegate, SKPaymentTransactionObserver>

@end
