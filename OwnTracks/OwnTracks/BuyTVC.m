//
//  BuyTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 23.10.15.
//  Copyright © 2015 OwnTracks. All rights reserved.
//

#import "BuyTVC.h"
#import "Subscriptions.h"
#import "AlertView.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface BuyTVC ()
@property (weak, nonatomic) IBOutlet UILabel *UIstatus;
@property (weak, nonatomic) IBOutlet UILabel *UIprogress;
@property (weak, nonatomic) IBOutlet UIButton *UIbuy;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *UIactivity;

@property (strong, nonatomic) SKProductsRequest *request;
@property (strong, nonatomic) SKProductsResponse *response;
@property (strong, nonatomic) NSArray *transactions;

@end

@implementation BuyTVC

static const DDLogLevel ddLogLevel = DDLogLevelVerbose;

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];

    [self.UIactivity stopAnimating];
    self.UIprogress.hidden = TRUE;
    
    self.response = nil;
    
    [[Subscriptions sharedInstance] addObserver:self
                                     forKeyPath:@"recording"
                                        options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                        context:nil];
    [[Subscriptions sharedInstance] addObserver:self
                                     forKeyPath:@"subscriptionExpires"
                                        options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                        context:nil];
    
    [self validateProductIdentifiers];

}

- (void)viewWillDisappear:(BOOL)animated {
    if (self.request) {
        [self.request cancel];
    }
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    [super viewWillDisappear:animated];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    [self performSelectorOnMainThread:@selector(updateUI) withObject:nil waitUntilDone:NO];
}

- (void)updateUI {
    NSNumber *recording = [Subscriptions sharedInstance].recording;
    NSDate *subscriptionExpires = [Subscriptions sharedInstance].subscriptionExpires;
    
    self.UIstatus.text = [NSString stringWithFormat:@"%@ expires %@\n",
                          recording ? [recording boolValue] ? @"Recording" : @"Not Recording" : @"<No Recording Status>",
                          subscriptionExpires ? [NSDateFormatter localizedStringFromDate:subscriptionExpires
                                                                               dateStyle:NSDateFormatterShortStyle
                                                                               timeStyle:NSDateFormatterShortStyle]
                                                   : @"<No Expiration Date>"];
}

- (IBAction)buyPressed:(UIButton *)sender {
    for (SKProduct *product in self.response.products) {
        if ([product.productIdentifier isEqualToString:SUBSCRIPTION]) {
            if ([SKPaymentQueue canMakePayments]) {
                DDLogVerbose(@"addPayment");
                SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
                payment.quantity = 1;
                [[SKPaymentQueue defaultQueue] addPayment:payment];
                return;
            } else {
                DDLogError(@"canMakePayments = FALSE");
                [AlertView alert:@"OwnTracks Premium" message:@"User cannot buy product"];
                return;
            }
        }
    }
    DDLogError(@"product not found");
    [AlertView alert:@"OwnTracks Premium" message:@"Product not available"];
}


// Retrieving Product Information

- (void)validateProductIdentifiers {
    self.request = [[SKProductsRequest alloc]
                            initWithProductIdentifiers:[NSSet setWithArray:@[SUBSCRIPTION]]];
    
    self.request.delegate = self;
    DDLogVerbose(@"productsRequest start");
    [self.request start];

    self.UIprogress.text = @"Requesting products";
    self.UIprogress.hidden = false;
    [self.UIactivity startAnimating];
}

- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response {
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
    DDLogVerbose(@"productsRequest didReceiveResponse invalidProductIdentifiers %@", response.invalidProductIdentifiers);
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
                
                self.UIprogress.text = @"Processing payment";
                self.UIprogress.hidden = false;
                [self.UIactivity startAnimating];

                break;
            case SKPaymentTransactionStateDeferred:
                DDLogVerbose(@"SKPaymentTransactionStateDeferred");
                
                self.UIprogress.text = @"Processing deferred";
                self.UIprogress.hidden = false;
                [self.UIactivity startAnimating];

                break;
            case SKPaymentTransactionStateFailed:
                DDLogVerbose(@"SKPaymentTransactionStateFailed %@ %@",
                             transaction.transactionIdentifier,
                             transaction.error.localizedDescription);
                [queue finishTransaction:transaction];

                self.UIprogress.text = @"";
                self.UIprogress.hidden = true;
                [self.UIactivity stopAnimating];

                [AlertView alert:@"OwnTracks Premium" message:[NSString stringWithFormat:@"Payment failed %@",
                                                               transaction.error.localizedDescription ]];

                break;
            case SKPaymentTransactionStatePurchased:
                DDLogVerbose(@"SKPaymentTransactionStatePurchased %@", transaction.transactionDate);
                [queue finishTransaction:transaction];
                [[Subscriptions sharedInstance] reset];

                self.UIprogress.text = @"";
                self.UIprogress.hidden = true;
                [self.UIactivity stopAnimating];

                [AlertView alert:@"OwnTracks Premium" message:@"Payment successfull"];
                
                
                break;
            case SKPaymentTransactionStateRestored:
                DDLogVerbose(@"SKPaymentTransactionStateRestored %@", transaction.transactionDate);
                [queue finishTransaction:transaction];
                [[Subscriptions sharedInstance] reset];

                self.UIprogress.text = @"";
                self.UIprogress.hidden = true;
                [self.UIactivity stopAnimating];
                
                [AlertView alert:@"OwnTracks Premium" message:@"Transaction successfully restored"];
                
                break;
            default:
                DDLogError(@"Unexpected transaction state %@", @(transaction.transactionState));
                [queue finishTransaction:transaction];
                
                self.UIprogress.text = @"";
                self.UIprogress.hidden = true;
                [self.UIactivity stopAnimating];

                [AlertView alert:@"OwnTracks Premium" message:@"Unexpected transaction state"];

                break;
        }
    }
}

- (void)requestDidFinish:(SKRequest *)request {
    DDLogVerbose(@"requestDidFinish");

    self.UIprogress.text = @"";
    self.UIprogress.hidden = true;
    [self.UIactivity stopAnimating];
    
    self.request = nil;
    
    [self performSelectorOnMainThread:@selector(updateUI) withObject:nil waitUntilDone:NO];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    DDLogError(@"request didFailWithError %@", error.localizedDescription);

    self.UIprogress.text = @"";
    self.UIprogress.hidden = true;
    [self.UIactivity stopAnimating];

    [AlertView alert:@"OwnTracks Premium" message:[NSString stringWithFormat:@"Product request failed %@",
                                                   error.localizedDescription ]];

    self.request = nil;
    [self performSelectorOnMainThread:@selector(updateUI) withObject:nil waitUntilDone:NO];
}



@end
