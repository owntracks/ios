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
    
    [self.UIactivity stopAnimating];
    self.UIprogress.hidden = TRUE;
    
    self.response = nil;
    
    [[Subscriptions sharedInstance] addObserver:self
                                     forKeyPath:@"recording"
                                        options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                        context:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    if (self.request) {
        [self.request cancel];
    }
    [super viewWillDisappear:animated];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    [self performSelectorOnMainThread:@selector(updateUI) withObject:nil waitUntilDone:NO];
}

- (void)updateUI {
    NSNumber *recording = [Subscriptions sharedInstance].recording;
    
    self.UIstatus.text = recording ? @"Recording" : @"Not Recording";
    self.UIbuy.enabled = !recording;
}

- (IBAction)buyPressed:(UIButton *)sender {
    if (!self.response) {
        [self validateProductIdentifiers];
    } else {
        [self buy];
    }
}

- (void)buy {
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

    self.UIprogress.text = @"Loading products ...";
    self.UIprogress.hidden = false;
    [self.UIactivity startAnimating];
}

- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response {
    
    self.UIprogress.text = @"";
    self.UIprogress.hidden = true;
    [self.UIactivity stopAnimating];
    
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
    [self buy];
}

@end
