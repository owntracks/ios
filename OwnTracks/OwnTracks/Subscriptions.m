//
//  Subscriptions.m
//  OwnTracks
//
//  Created by Christoph Krey on 20.10.15.
//  Copyright © 2015 OwnTracks. All rights reserved.
//

#import "Subscriptions.h"
#import "Settings.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface Subscriptions()
@property (strong, nonatomic) SKReceiptRefreshRequest *request;
@property (strong, nonatomic) NSDictionary *receipt;

@property (readwrite, strong, nonatomic) NSNumber *recording;
@property (readwrite, strong, nonatomic) NSDate *subscriptionExpires;
@property (nonatomic) BOOL initialized;

@end

#define IN_APP_SANDBOX 1
#ifdef IN_APP_SANDBOX
#define storeURL [NSURL URLWithString:@"https://sandbox.itunes.apple.com/verifyReceipt"]
#else
#define storeURL [NSURL URLWithString:@"https://buy.itunes.apple.com/verifyReceipt"]
#endif

@implementation Subscriptions
static Subscriptions *theInstance = nil;
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;

+ (Subscriptions *)sharedInstance {
    if (theInstance == nil) {
        theInstance = [[Subscriptions alloc] init];
    }
    return theInstance;
}

- (void)reset {
    self.initialized = false;
    [self initialize];
}

- (BOOL)initialize {
    if ([Settings intForKey:@"mode"] == 1) {
        if (!self.initialized) {
            self.initialized = true;
            
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
                NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
                [storeRequest setHTTPMethod:@"POST"];
                [storeRequest setHTTPBody:requestData];
                
                NSOperationQueue *queue = [[NSOperationQueue alloc] init];
                [NSURLConnection sendAsynchronousRequest:storeRequest queue:queue
                                       completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                                           if (connectionError) {
                                               DDLogError(@"connectionError %@", connectionError.localizedDescription);
                                               self.initialized = FALSE;
                                               
                                           } else {
                                               NSError *error;
                                               NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data
                                                                                                            options:0
                                                                                                              error:&error];
                                               if (!jsonResponse) {
                                                   DDLogError(@"NSJSONSerialization error %@", error.localizedDescription);
                                                   self.initialized = FALSE;
                                                   
                                               } else {
                                                   DDLogVerbose(@"jsonResponse %@", jsonResponse);
                                                   int status = [[jsonResponse valueForKey:@"status"] intValue];
                                                   if (status != 0) {
                                                       DDLogError(@"jsonResponse status %d", status);
                                                       self.initialized = FALSE;
                                                       
                                                   } else {
                                                       self.receipt = [jsonResponse valueForKey:@"receipt"];
                                                       [self processReceipt];
                                                   }
                                               }
                                           }
                                       }];
            } else {
                // no receiptData available
                self.request = [[SKReceiptRefreshRequest alloc] init];
                self.request.delegate = self;
                [self.request start];
                self.initialized = FALSE;
            }
        } else {
            // receipt is already validated
        }
        return TRUE;
    } else {
        // mode not == Hosted(1)
        return FALSE;
    }
}

- (void)requestDidFinish:(SKRequest *)request {
    DDLogVerbose(@"requestDidFinish");
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    DDLogError(@"request didFailWithError %@", error.localizedDescription);
}

- (NSDate *)subscriptionExpires {
    if ([self initialize]) {
        [self processReceipt];
        return _subscriptionExpires;
    }
    return nil;
}

- (NSNumber *)recording {
    if ([self initialize]) {
        [self processReceipt];
        return _recording;
    }
    return nil;
}

- (void)processReceipt {
    BOOL recording = false;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSSet *inAppReceipts = [self.receipt valueForKey:@"in_app"];
    for (NSDictionary *inAppReceipt in inAppReceipts) {
        NSString *productId = [inAppReceipt valueForKey:@"product_id"];
        if ([productId isEqualToString:SUBSCRIPTION]) {
            NSTimeInterval expirationDate = [[inAppReceipt valueForKey:@"expires_date_ms"] doubleValue] / 1000;
            NSTimeInterval purchaseDate = [[inAppReceipt valueForKey:@"purchase_date_ms"] doubleValue] / 1000;
            if (now < expirationDate && now > purchaseDate) {
                recording = true;
                if ([_subscriptionExpires timeIntervalSince1970] != expirationDate) {
                    _subscriptionExpires =  [NSDate dateWithTimeIntervalSince1970:expirationDate];
                }
                break;
            }
        }
    }
    if (recording != [_recording boolValue]) {
        if (!recording) {
            _subscriptionExpires = nil;
            if ([_recording boolValue]) {
                [self reset];
            }
        }
        _recording = [NSNumber numberWithBool:recording];
    }
}

@end
