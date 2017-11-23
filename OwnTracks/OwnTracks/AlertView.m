//
//  AlertView.m
//  OwnTracks
//
//  Created by Christoph Krey on 20.12.13.
//  Copyright © 2013-2017 Christoph Krey. All rights reserved.
//

#import "AlertView.h"

#import <CocoaLumberjack/CocoaLumberjack.h>

@interface AlertView()
@property (strong, nonatomic) UIAlertView *alertView;

@end

@implementation AlertView
static const DDLogLevel ddLogLevel = DDLogLevelWarning;

+ (void)alert:(NSString *)title message:(NSString *)message {
    [AlertView alert:title message:message dismissAfter:0];
}

+ (void)alert:(NSString *)title message:(NSString *)message dismissAfter:(NSTimeInterval)interval {
    (void)[[AlertView alloc] initWithAlert:title message:message dismissAfter:interval];
}

- (AlertView *)initWithAlert:(NSString *)title
                     message:(NSString *)message
                dismissAfter:(NSTimeInterval)interval {
    self = [super init];

    NSMutableDictionary *d = [@{@"interval": @(interval)} mutableCopy];

    if (title) {
        d[@"title"] = title;
    }
    if (message) {
        d[@"message"] = message;
    }
    [self performSelectorOnMainThread:@selector(setup:)
                           withObject:d
                        waitUntilDone:NO];
    return self;
}

- (void)setup:(NSMutableDictionary *)d {
    DDLogVerbose(@"[AlertView] setup %@", d);

    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        NSNumber *interval = d[@"interval"];
        NSString *title = d[@"title"];
        NSString *message = d[@"message"];
        self.alertView = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:interval.doubleValue ? nil :
                          NSLocalizedString(@"OK", @"OK button title")
                                          otherButtonTitles:nil];

        [self.alertView show];
        if (interval.doubleValue) {
            [self performSelector:@selector(dismissAfterDelay:) withObject:self.alertView afterDelay:interval.doubleValue];
        }
    }
}

- (void)dismissAfterDelay:(UIAlertView *)alertView {
    DDLogVerbose(@"[AlertView] dismissAfterDelay");
    [alertView dismissWithClickedButtonIndex:0 animated:YES];
}

@end
