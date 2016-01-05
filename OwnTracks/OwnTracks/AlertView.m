//
//  AlertView.m
//  OwnTracks
//
//  Created by Christoph Krey on 20.12.13.
//  Copyright © 2013-2016 Christoph Krey. All rights reserved.
//

#import "AlertView.h"

#import <CocoaLumberjack/CocoaLumberjack.h>

@interface AlertView()
@property (strong, nonatomic) UIAlertView *alertView;

@end

@implementation AlertView
static const DDLogLevel ddLogLevel = DDLogLevelError;

+ (void)alert:(NSString *)title message:(NSString *)message {
    [AlertView alert:title message:message dismissAfter:0];
}

+ (void)alert:(NSString *)title message:(NSString *)message dismissAfter:(NSTimeInterval)interval {
    (void)[[AlertView alloc] initWithAlert:title message:message dismissAfter:interval];
}

- (AlertView *)initWithAlert:(NSString *)title message:(NSString *)message dismissAfter:(NSTimeInterval)interval {
    self = [super init];
    
    DDLogVerbose(@"AlertView ddLogLevel %lu", (unsigned long)ddLogLevel);
    DDLogVerbose(@"AlertView %@/%@ (%f)", title, message, interval);
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        self.alertView = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:interval ? nil : @"OK"
                                          otherButtonTitles:nil];
        [self performSelectorOnMainThread:@selector(setup:) withObject:[NSNumber numberWithFloat:interval] waitUntilDone:NO];
    }
    return self;
}

- (void)setup:(NSNumber *)interval {
    NSTimeInterval timeInterval = [interval doubleValue];
    [self.alertView show];
    if (timeInterval) {
        [self performSelector:@selector(dismissAfterDelay:) withObject:self.alertView afterDelay:timeInterval];
    }
}

- (void)dismissAfterDelay:(UIAlertView *)alertView
{
    DDLogVerbose(@"AlertView dismissAfterDelay");
    [alertView dismissWithClickedButtonIndex:0 animated:YES];
}

@end
