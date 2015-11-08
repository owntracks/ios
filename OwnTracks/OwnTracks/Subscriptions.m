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
#import <OpenSSL/x509.h>
#import <OpenSSL/pkcs7.h>
#import <OpenSSL/err.h>

typedef NS_ENUM(NSInteger, ReceiptStatus) {
    ReceiptStatusUnknown,
    ReceiptStatusNoReceipt,
    ReceiptStatusValidationFailedOnce,
    ReceiptStatusReceipt,
    ReceiptStatusValidReceipt,
    ReceiptStatusOk,
    ReceiptStatusError
};

#define RECEIPT_BUNDLE_ID 2
#define RECEIPT_OPAQUE_VALUE 4
#define RECEIPT_SHA1_HASH 5
#define RECEIPT_INAPP_PURCHASE 17

#define PURCHASE_PRODUCT_ID 1702
#define PURCHASE_TRANSACTION_ID 1703
#define PURCHASE_DATE 1704
#define PURCHASE_EXPIRES_DATE 1708

#define kReceiptBundleIdentiferData @"BundleIDData"
#define kReceiptOpaqueValue @"opaque_value"
#define kReceiptSha1Hash @"sha1_hash"
#define kReceiptBundleIdentifer @"bundle_id"

#define kPurchaseProductIdentifier @"product_id"
#define kPurchaseTransactionIdentifier @"transaction_id"
#define kPurchaseDate @"purchase_date"
#define kPurchaseExpirationDate @"expires_date"

@interface Subscriptions()
@property (strong, nonatomic) SKReceiptRefreshRequest *request;
@property (strong, nonatomic) NSMutableDictionary *receipt;
@property (strong, nonatomic) NSMutableDictionary *purchases;

@property (readwrite, strong, nonatomic) NSNumber *recording;
@property (nonatomic) ReceiptStatus status;
@property (nonatomic) BOOL validationFailed;

@end

@implementation Subscriptions
static Subscriptions *theInstance = nil;
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;

+ (Subscriptions *)sharedInstance {
    if (theInstance == nil) {
        theInstance = [[Subscriptions alloc] init];
        theInstance.status = ReceiptStatusUnknown;
        theInstance.validationFailed = false;
        [[SKPaymentQueue defaultQueue] addTransactionObserver:theInstance];
    }
    return theInstance;
}

- (void)initialize {
    if ([Settings intForKey:@"mode"] == 1) {
        if (self.status == ReceiptStatusUnknown) {
            DDLogError(@"ReceiptStatusUnknown");
            NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
            NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
            if (receiptData) {
                self.status = ReceiptStatusReceipt;
            } else {
                DDLogError(@"ReceiptStatusNoReceipt");
                self.status = ReceiptStatusNoReceipt;
                self.request = [[SKReceiptRefreshRequest alloc] init];
                self.request.delegate = self;
                [self.request start];
            }
        }
        
        if (self.status == ReceiptStatusReceipt) {
            NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
            NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
            if (receiptData) {
                NSURL *x509URL = [[NSBundle mainBundle] URLForResource:@"AppleIncRootCertificate" withExtension:@"cer"];
                NSData *x509Data = [NSData dataWithContentsOfURL:x509URL];
                
                if (x509Data) {
                    ERR_load_CRYPTO_strings();
                    ERR_load_PKCS7_strings();
                    ERR_load_X509_strings();
                    OpenSSL_add_all_digests();
                    OpenSSL_add_all_algorithms();
                    
                    BIO *b_receipt = BIO_new_mem_buf((void *)receiptData.bytes, (int)receiptData.length);
                    PKCS7 *p7 = d2i_PKCS7_bio(b_receipt, NULL);
                    
                    BIO *b_x509 = BIO_new_mem_buf((void *)x509Data.bytes, (int)x509Data.length);
                    X509 *appleRootCA = d2i_X509_bio(b_x509, NULL);
                    X509_STORE *store = X509_STORE_new();
                    X509_STORE_add_cert(store, appleRootCA);
                    
                    BIO *b_receiptPayload = BIO_new(BIO_s_mem());
                    int result = PKCS7_verify(p7, NULL, store, NULL, b_receiptPayload, 0);
                    if (result == 1) {
                        ASN1_OCTET_STRING *octets = p7->d.sign->contents->d.data;
                        const unsigned char *p = octets->data;
                        const unsigned char *end = p + octets->length;
                        
                        int type = 0;
                        int xclass = 0;
                        long length = 0;
                        
                        ASN1_get_object(&p, &length, &type, &xclass, end - p);
                        if (type == V_ASN1_SET) {
                            self.receipt = [[NSMutableDictionary alloc] init];
                            self.purchases = [[NSMutableDictionary alloc] init];
                            while (p < end) {
                                ASN1_get_object(&p, &length, &type, &xclass, end - p);
                                if (type != V_ASN1_SEQUENCE)
                                    break;
                                
                                const unsigned char *seq_end = p + length;
                                
                                int attr_type = 0;
                                int attr_version = 0;
                                
                                ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
                                if (type == V_ASN1_INTEGER && length == 1) {
                                    attr_type = p[0];
                                }
                                p += length;
                                
                                ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
                                if (type == V_ASN1_INTEGER && length == 1) {
                                    attr_version = p[0];
                                }
                                p += length;
                                
                                DDLogVerbose(@"attribute attr_type %d version %d", attr_type, attr_version);
                                
                                NSString *key;
                                
                                ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
                                if (type == V_ASN1_OCTET_STRING) {
                                    
                                    if (attr_type == RECEIPT_OPAQUE_VALUE || attr_type == RECEIPT_SHA1_HASH) {
                                        NSData *data = [NSData dataWithBytes:p length:length];
                                        
                                        switch (attr_type) {
                                            case RECEIPT_OPAQUE_VALUE:
                                                key = kReceiptOpaqueValue;
                                                break;
                                            case RECEIPT_SHA1_HASH:
                                                key = kReceiptSha1Hash;
                                                break;
                                        }
                                        
                                        [self.receipt setObject:data forKey:key];
                                    } else if (attr_type == RECEIPT_BUNDLE_ID) {
                                        int str_type = 0;
                                        long str_length = 0;
                                        const unsigned char *str_p = p;
                                        ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                                        if (str_type == V_ASN1_UTF8STRING) {
                                            NSString *string = [[NSString alloc] initWithBytes:str_p
                                                                                        length:str_length
                                                                                      encoding:NSUTF8StringEncoding];
                                            
                                            switch (attr_type) {
                                                case RECEIPT_BUNDLE_ID:
                                                    key = kReceiptBundleIdentifer;
                                                    break;
                                            }
                                            
                                            [self.receipt setObject:string forKey:key];
                                        }
                                    } else if (attr_type == RECEIPT_INAPP_PURCHASE) {
                                        const unsigned char *pOld = p;
                                        ASN1_get_object(&p, &length, &type, &xclass, end - p);
                                        if (type == V_ASN1_SET) {
                                            
                                            NSMutableDictionary *purchase = [[NSMutableDictionary alloc] init];
                                            while (p < end) {
                                                ASN1_get_object(&p, &length, &type, &xclass, end - p);
                                                if (type != V_ASN1_SEQUENCE)
                                                    break;
                                                
                                                const unsigned char *seq_end = p + length;
                                                
                                                int attr_type = 0;
                                                int attr_version = 0;
                                                
                                                ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
                                                if (type == V_ASN1_INTEGER && length == 1) {
                                                    attr_type = p[0];
                                                }
                                                if (type == V_ASN1_INTEGER && length == 2) {
                                                    attr_type = p[0] * 256 + p[1];
                                                }
                                                p += length;
                                                
                                                ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
                                                if (type == V_ASN1_INTEGER && length == 1) {
                                                    attr_version = p[0];
                                                }
                                                p += length;
                                                
                                                DDLogVerbose(@"attribute Purchase attr_type %d version %d", attr_type, attr_version);
                                                
                                                NSString *key;
                                                
                                                ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
                                                DDLogVerbose(@"attribute Purchase type %d", type);

                                                if (type == V_ASN1_OCTET_STRING) {
                                                    
                                                    int str_type = 0;
                                                    long str_length = 0;
                                                    const unsigned char *str_p = p;
                                                    ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                                                    DDLogVerbose(@"attribute String type %d", str_type);

                                                    if (str_type == V_ASN1_UTF8STRING) {
                                                        NSString *string = [[NSString alloc] initWithBytes:str_p
                                                                                                    length:str_length
                                                                                                  encoding:NSUTF8StringEncoding];
                                                        DDLogVerbose(@"attribute Purchase type %d string %@", attr_type, string);
                                                        
                                                        if (attr_type == PURCHASE_PRODUCT_ID ||
                                                            attr_type == PURCHASE_TRANSACTION_ID) {
                                                            switch (attr_type) {
                                                                case PURCHASE_PRODUCT_ID:
                                                                    key = kPurchaseProductIdentifier;
                                                                    break;
                                                                case PURCHASE_TRANSACTION_ID:
                                                                    key = kPurchaseTransactionIdentifier;
                                                                    break;
                                                            }
                                                            
                                                            [purchase setObject:string forKey:key];
                                                        }
                                                    } else if (str_type == V_ASN1_IA5STRING) {
                                                        NSString *string = [[NSString alloc] initWithBytes:str_p
                                                                                                    length:str_length
                                                                                                  encoding:NSASCIIStringEncoding];
                                                        DDLogVerbose(@"attribute Purchase type %d ia5string %@", attr_type, string);
                                                        
                                                        if (attr_type == PURCHASE_DATE ||
                                                            attr_type == PURCHASE_EXPIRES_DATE) {
                                                            switch (attr_type) {
                                                                case PURCHASE_DATE:
                                                                    key = kPurchaseDate;
                                                                    break;
                                                                case PURCHASE_EXPIRES_DATE:
                                                                    key = kPurchaseExpirationDate;
                                                                    break;
                                                            }
                                                            
                                                            NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init];
                                                            NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
                                                            [rfc3339DateFormatter setLocale:enUSPOSIXLocale];
                                                            [rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
                                                            [rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
                                                            NSDate *date = [rfc3339DateFormatter dateFromString:string];

                                                            [purchase setObject:date forKey:key];
                                                        }
                                                        
                                                    }
                                                }
                                                p += length;
                                            }
                                            [self.purchases setObject:purchase forKey:purchase[kPurchaseTransactionIdentifier]];
                                        }
                                        p = pOld;
                                    }
                                }
                                p += length;
                            }
                            self.status = ReceiptStatusOk;
                            DDLogVerbose(@"receipt %@", self.receipt);
                            DDLogVerbose(@"purchases %@", self.purchases);
                            [self processReceipt];
                        } else {
                            self.status = ReceiptStatusError;
                        }
                    } else {
                        DDLogError(@"Receipt Signature is INVALID %s",
                                   ERR_error_string(ERR_get_error(), NULL));
                        self.status = ReceiptStatusError;
                    }
                    BIO_free(b_x509);
                    BIO_free(b_receiptPayload);
                    BIO_free(b_receipt);
                    PKCS7_free(p7);
                } else {
                    DDLogError(@"no x509 data");
                    self.status = ReceiptStatusError;
                }
            } else {
                DDLogError(@"no receipt data");
                self.status = ReceiptStatusError;
            }
        }
    }
    if (self.status == ReceiptStatusReceipt) {
    }
}

- (void)requestDidFinish:(SKRequest *)request {
    DDLogVerbose(@"requestDidFinish");
    self.status = ReceiptStatusReceipt;
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    DDLogError(@"request didFailWithError %@", error.localizedDescription);
    self.status = ReceiptStatusError;
}

- (NSNumber *)recording {
    [self initialize];
    if (self.status == ReceiptStatusOk) {
        return _recording;
    }
    return nil;
}

- (void)processReceipt {
    BOOL recording = false;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    for (NSDictionary *purchase in self.purchases.allValues) {
        NSString *productId = [purchase valueForKey:kPurchaseProductIdentifier];
        if ([productId isEqualToString:SUBSCRIPTION]) {
            NSTimeInterval expirationDate = [[purchase valueForKey:kPurchaseExpirationDate] timeIntervalSince1970];
            NSTimeInterval purchaseDate = [[purchase valueForKey:kPurchaseDate] timeIntervalSince1970];
            if (now < expirationDate && now > purchaseDate) {
                DDLogVerbose(@"Recording %@ < %@ < %@",
                             [NSDate dateWithTimeIntervalSince1970:purchaseDate],
                             [NSDate dateWithTimeIntervalSince1970:now],
                             [NSDate dateWithTimeIntervalSince1970:expirationDate]
                             );
                recording = true;
                break;
            }
        }
    }
    if (!recording) {
        DDLogVerbose(@"Not Recording");
    }
    if (recording != [_recording boolValue]) {
        _recording = [NSNumber numberWithBool:recording];
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    DDLogVerbose(@"paymentQueue updatedTransactions %lu", (unsigned long)transactions.count);
    
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
                [queue finishTransaction:transaction];
                break;
            case SKPaymentTransactionStatePurchased:
                DDLogVerbose(@"SKPaymentTransactionStatePurchased %@", transaction.transactionDate);
                [queue finishTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                DDLogVerbose(@"SKPaymentTransactionStateRestored %@", transaction.transactionDate);
                [queue finishTransaction:transaction];
                break;
            default:
                DDLogError(@"Unexpected transaction state %ld", (long)transaction.transactionState);
                [queue finishTransaction:transaction];
                break;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    DDLogVerbose(@"paymentQueue removedTransactions %lu", (unsigned long)transactions.count);
    
    for (SKPaymentTransaction *transaction in transactions) {
        DDLogVerbose(@"SKPaymentTransaction %@", transaction.transactionIdentifier);
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray<SKDownload *> *)downloads {
    DDLogVerbose(@"paymentQueue updatedDownloads %lu", (unsigned long)downloads.count);
    
    for (SKDownload *download in downloads) {
        DDLogVerbose(@"SKDownLoad %@", download);
    }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    DDLogVerbose(@"paymentQueueRestoreCompletedTransactionsFinished");
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    DDLogVerbose(@"restoreCompletedTransactionsFailedWithError %@", error.localizedDescription);
}


@end
