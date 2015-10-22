//
//  Subscriptions.m
//  OwnTracks
//
//  Created by Christoph Krey on 20.10.15.
//  Copyright © 2015 OwnTracks. All rights reserved.
//

#import "Subscriptions.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface Subscriptions()
@property (strong, nonatomic) SKProductsResponse *response;
@property (strong, nonatomic) SKReceiptRefreshRequest *request;
@property (strong, nonatomic) NSArray *transactions;
@property (strong, nonatomic) NSDictionary *receipt;
@property (readwrite, strong, nonatomic) NSNumber *recording;

@end

#define SUBSCRIPTION @"recording1m"

@implementation Subscriptions
static Subscriptions *theInstance = nil;
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;

+ (Subscriptions *)sharedInstance {
    if (theInstance == nil) {
        theInstance = [[Subscriptions alloc] init];
    }
    return theInstance;
}

- (instancetype)init {
    self = [super init];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil queue:nil usingBlock:^(NSNotification *note){
                                                          [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
                                                          [self validateProductIdentifiers];
                                                          self.request = [[SKReceiptRefreshRequest alloc] init];
                                                          self.request.delegate = self;
                                                          [self.request start];
                                                      }];
    return self;
}

- (void)setReceipt:(NSDictionary *)receipt {
    _receipt = receipt;
    BOOL recording = false;
    NSSet *inAppReceipts = [receipt valueForKey:@"in_app"];
    for (NSDictionary *inAppReceipt in inAppReceipts) {
        NSString *productId = [inAppReceipt valueForKey:@"product_id"];
        NSTimeInterval expiresDate = [[inAppReceipt valueForKey:@"expires_date_ms"] doubleValue] / 1000;
        if ([productId isEqualToString:SUBSCRIPTION]) {
            if ([[NSDate date] timeIntervalSince1970] < expiresDate) {
                recording = true;
            }
        }
    }
    self.recording = [NSNumber numberWithBool:recording];
}

- (NSNumber *)recording {
    if (!self.receipt) {
        NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
        NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
        
        if (receiptData) {
            NSError *error;
            NSDictionary *requestContents = @{
                                              @"receipt-data": [receiptData base64EncodedStringWithOptions:0],
                                              @"password": @"b48e97e6187e44f0b2910586d54b20af"
                                              };
            NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents
                                                                  options:0
                                                                    error:&error];
#ifdef DEBUG
            NSURL *storeURL = [NSURL URLWithString:@"https://sandbox.itunes.apple.com/verifyReceipt"];
#else
            NSURL *storeURL = [NSURL URLWithString:@"https://buy.itunes.apple.com/verifyReceipt"];
#endif
            DDLogError(@"storeURL %@", storeURL);

            NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
            [storeRequest setHTTPMethod:@"POST"];
            [storeRequest setHTTPBody:requestData];
            
            NSOperationQueue *queue = [[NSOperationQueue alloc] init];
            [NSURLConnection sendAsynchronousRequest:storeRequest queue:queue
                                   completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                                       if (connectionError) {
                                           DDLogError(@"connectionError %@", connectionError.localizedDescription);
                                       } else {
                                           NSError *error;
                                           NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                           if (!jsonResponse) {
                                               DDLogError(@"NSJSONSerialization error %@", error.localizedDescription);
                                           } else {
                                               DDLogVerbose(@"jsonResponse %@", jsonResponse);
                                               int status = [[jsonResponse valueForKey:@"status"] intValue];
                                               if (status == 0) {
                                                   self.receipt = [jsonResponse valueForKey:@"receipt"];
                                               }
                                           }
                                       }
                                   }];
        }
    }
    return _recording;
}

- (void)payRecording {
    for (SKProduct *product in self.response.products) {
        if ([product.productIdentifier isEqualToString:SUBSCRIPTION]) {
            SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
            payment.quantity = 1;
            [[SKPaymentQueue defaultQueue] addPayment:payment];
        }
    }
}

- (void)validateProductIdentifiers
{
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc]
                                          initWithProductIdentifiers:[NSSet setWithArray:@[SUBSCRIPTION]]];
    
    productsRequest.delegate = self;
    [productsRequest start];
}

- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response {
    DDLogVerbose(@"productsRequest didReceiveResponse invalidProductIdentifiers %@", response.invalidProductIdentifiers);

    self.response = response;
    
    for (SKProduct *product in self.response.products) {
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
        [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        [numberFormatter setLocale:product.priceLocale];
        NSString *formattedPrice = [numberFormatter stringFromNumber:product.price];
        DDLogVerbose(@"products %@\n\tlocalizedTitle %@\n\tlocalizedDescription %@\n\tprice %@",
                     product.productIdentifier,
                     product.localizedTitle,
                     product.localizedDescription,
                     formattedPrice);
    }

}

- (void)requestDidFinish:(SKRequest *)request {
    DDLogVerbose(@"requestDidFinish");
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    DDLogError(@"request didFailWithError %@", error.localizedDescription);

}

- (void)paymentQueue:(SKPaymentQueue *)queue
 updatedTransactions:(NSArray *)transactions
{
    DDLogVerbose(@"paymentQueue updatedTransactions %lu", (unsigned long)transactions.count);
    self.transactions = transactions;

    for (SKPaymentTransaction *transaction in transactions) {
        DDLogVerbose(@"SKPaymentTransaction %@", transaction.transactionIdentifier);

        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:
                DDLogVerbose(@"SKPaymentTransactionStatePurchasing");
                break;
            case SKPaymentTransactionStateDeferred:
                DDLogVerbose(@"SKPaymentTransactionStateDeferred");
                break;
            case SKPaymentTransactionStateFailed:
                DDLogVerbose(@"SKPaymentTransactionStateFailed %@ %@",
                             transaction.transactionIdentifier,
                             transaction.error.localizedDescription);
                self.receipt = nil;
                break;
            case SKPaymentTransactionStatePurchased:
                DDLogVerbose(@"SKPaymentTransactionStatePurchased %@", transaction.transactionDate);
                self.receipt = nil;
                break;
            case SKPaymentTransactionStateRestored:
                DDLogVerbose(@"SKPaymentTransactionStateRestored %@", transaction.transactionDate);
                self.receipt = nil;
                break;
            default:
                DDLogError(@"Unexpected transaction state %@", @(transaction.transactionState));
                break;
        }
    }
}

@end
