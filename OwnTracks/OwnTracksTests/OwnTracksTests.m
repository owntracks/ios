//
//  OwnTracksTests.m
//  OwnTracksTests
//
//  Created by Christoph Krey on 02.01.16.
//  Copyright © 2016 OwnTracks. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <CocoaLumberjack/CocoaLumberjack.h>
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;

@interface OwnTracksTests : XCTestCase
@property (strong, nonatomic) NSTimer *timer;
@property (nonatomic) BOOL returned;
@end

#define USER @"user"
#define MAIL @"user@nowhere.com"
#define PASS @"pass"
#define FULL @"Full Name"
#define DEV @"device"
#define DEVID 11

@implementation OwnTracksTests

- (void)setUp {
    [super setUp];
    if (![[DDLog allLoggers] containsObject:[DDTTYLogger sharedInstance]])
        [DDLog addLogger:[DDTTYLogger sharedInstance] withLevel:DDLogLevelAll];
    if (![[DDLog allLoggers] containsObject:[DDASLLogger sharedInstance]])
        [DDLog addLogger:[DDASLLogger sharedInstance] withLevel:DDLogLevelWarning];
    
    DDLogVerbose(@"setup");
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(ticker:) userInfo:nil repeats:true];
}

- (void)completion:(NSError *)error {
    NSLog(@"completion %@", error);
}

- (void)ticker:(NSTimer *)timer {
    NSLog(@"ticker");
}

- (void)tearDown {
    [self.timer invalidate];
    self.timer = nil;
    [super tearDown];
}

- (void)testOne {
}

@end
