//
//  OwnTracksTests.m
//  OwnTracksTests
//
//  Created by Christoph Krey on 02.01.16.
//  Copyright © 2016 OwnTracks. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Hosted.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;

@interface OwnTracksTests : XCTestCase
@property (strong, nonatomic) Hosted *hosted;
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
    self.hosted = [[Hosted alloc] init];
}

- (void)completion:(NSError *)error {
    NSLog(@"completion %@", error);
}

- (void)ticker:(NSTimer *)timer {
    NSLog(@"ticker");
}

- (void)tearDown {
    self.hosted = nil;
    [self.timer invalidate];
    self.timer = nil;
    [super tearDown];
}

- (void)testAuthenticate {
    self.returned = false;
    
    [self.hosted authenticate:USER password:PASS completionBlock:^(NSInteger status, NSString *refreshToken) {
        NSLog(@"authenticate (%ld) %@", (long)status, refreshToken);
        self.returned = true;
    }];
    
    while (!self.returned) {
        NSLog(@"waiting");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
}

- (void)testCachedRefreshToken {
    self.returned = false;
    
    [self.hosted authenticate:USER password:PASS completionBlock:^(NSInteger status, NSString *refreshToken) {
        NSLog(@"authenticate (%ld) %@", (long)status, refreshToken);
        self.returned = true;
    }];
    
    while (!self.returned) {
        NSLog(@"waiting");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    
    self.returned = false;
    
    [self.hosted authenticate:USER password:PASS completionBlock:^(NSInteger status, NSString *refreshToken) {
        NSLog(@"authenticate (%ld) %@", (long)status, refreshToken);
        self.returned = true;
    }];
    
    while (!self.returned) {
        NSLog(@"waiting");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
}

- (void)testAccessToken {
    self.returned = false;
    
    [self.hosted authenticate:USER password:PASS completionBlock:^(NSInteger status, NSString *refreshToken) {
        NSLog(@"authenticate (%ld) %@", (long)status, refreshToken);
        if (refreshToken) {
            [self.hosted accessToken:refreshToken completionBlock:^(NSInteger status, NSString *accessToken) {
                NSLog(@"accessToken (%ld) %@", (long)status, accessToken);
                self.returned = true;
            }];
        } else {
            self.returned = true;
        }
    }];
    
    while (!self.returned) {
        NSLog(@"waiting");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
}

- (void)testCreateUser {
    self.returned = false;
    
    [self.hosted createUser:USER password:PASS fullname:FULL email:MAIL completionBlock:^(NSInteger status, NSDictionary *user) {
        NSLog(@"createUser (%ld) %@", (long)status, user);
        self.returned = true;
    }];
    
    while (!self.returned) {
        NSLog(@"waiting");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
}

- (void)testCreateDevice {
    self.returned = false;
    
    [self.hosted authenticate:USER password:PASS completionBlock:^(NSInteger status, NSString *refreshToken) {
        NSLog(@"authenticate (%ld) %@", (long)status, refreshToken);
        if (refreshToken) {
            [self.hosted accessToken:refreshToken completionBlock:^(NSInteger status, NSString *accessToken) {
                NSLog(@"accessToken (%ld) %@", (long)status, accessToken);
                if (accessToken) {
                    NSDictionary *me = [Hosted decode:accessToken];
                    NSLog(@"de-LWTed %@", me);
                    
                    
                    NSNumber *userId = [me valueForKey:@"userId"];
                    if (userId) {
                        [self.hosted createDevice:accessToken
                                       devicename:DEV
                                           userId:[userId integerValue]
                                  completionBlock:^(NSInteger status, NSDictionary *device) {
                                      NSLog(@"createDevice (%ld) %@", (long)status, device);
                                      self.returned = true;
                                  }];
                    } else {
                        self.returned = true;
                    }
                } else {
                    self.returned = true;
                }
            }];
        } else {
            self.returned = true;
        }
    }];
    
    while (!self.returned) {
        NSLog(@"waiting");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
}

- (void)testListUsers {
    self.returned = false;
    
    [self.hosted authenticate:USER password:PASS completionBlock:^(NSInteger status, NSString *refreshToken) {
        NSLog(@"authenticate (%ld) %@", (long)status, refreshToken);
        if (refreshToken) {
            [self.hosted accessToken:refreshToken completionBlock:^(NSInteger status, NSString *accessToken) {
                NSLog(@"accessToken (%ld) %@", (long)status, accessToken);
                if (accessToken) {
                    [self.hosted listUsers:accessToken completionBlock:^(NSInteger status, NSArray *users) {
                        NSLog(@"users (%ld) %@", (long)status, users);
                        self.returned = true;
                    }];
                } else {
                    self.returned = true;
                }
            }];
        } else {
            self.returned = true;
        }
    }];
    
    while (!self.returned) {
        NSLog(@"waiting");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
}


- (void)testRetrieveUser {
    self.returned = false;
    
    [self.hosted authenticate:USER password:PASS completionBlock:^(NSInteger status, NSString *refreshToken) {
        NSLog(@"authenticate (%ld) %@", (long)status, refreshToken);
        if (refreshToken) {
            [self.hosted accessToken:refreshToken completionBlock:^(NSInteger status, NSString *accessToken) {
                NSLog(@"accessToken (%ld) %@", (long)status, accessToken);
                if (accessToken) {
                    NSDictionary *me = [Hosted decode:accessToken];
                    NSLog(@"de-LWTed %@", me);
                    
                    NSNumber *userId = [me valueForKey:@"userId"];
                    if (userId) {
                        
                        
                        [self.hosted retrieveUser:accessToken userId:[userId integerValue]
                                  completionBlock:^(NSInteger status, NSDictionary *user){
                                      NSLog(@"user (%ld) %@", (long)status, user);
                                      self.returned = true;
                                  }];
                    } else {
                        self.returned = true;
                    }
                } else {
                    self.returned = true;
                }
            }];
        } else {
            self.returned = true;
        }
    }];
    
    while (!self.returned) {
        NSLog(@"waiting");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
}


- (void)testListDevices {
    self.returned = false;
    
    [self.hosted authenticate:USER password:PASS completionBlock:^(NSInteger status, NSString *refreshToken) {
        NSLog(@"authenticate (%ld) %@", (long)status, refreshToken);
        if (refreshToken) {
            [self.hosted accessToken:refreshToken completionBlock:^(NSInteger status, NSString *accessToken) {
                NSLog(@"accessToken (%ld) %@", (long)status, accessToken);
                if (accessToken) {
                    NSDictionary *me = [Hosted decode:accessToken];
                    NSLog(@"de-LWTed %@", me);
                    
                    NSNumber *userId = [me valueForKey:@"userId"];
                    if (userId) {
                        
                        [self.hosted listDevices:accessToken
                                          userId:[userId integerValue]
                                 completionBlock:^(NSInteger status, NSArray *devices) {
                                     NSLog(@"devices (%ld) %@", (long)status, devices);
                                     self.returned = true;
                                 }];
                    } else {
                        self.returned = true;
                    }
                    
                } else {
                    self.returned = true;
                }
            }];
        } else {
            self.returned = true;
        }
    }];
    
    while (!self.returned) {
        NSLog(@"waiting");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
}

- (void)testRetrieveDevice {
    self.returned = false;
    
    [self.hosted authenticate:USER password:PASS completionBlock:^(NSInteger status, NSString *refreshToken) {
        NSLog(@"authenticate (%ld) %@", (long)status, refreshToken);
        if (refreshToken) {
            [self.hosted accessToken:refreshToken completionBlock:^(NSInteger status, NSString *accessToken) {
                NSLog(@"accessToken (%ld) %@", (long)status, accessToken);
                if (accessToken) {
                    NSDictionary *me = [Hosted decode:accessToken];
                    NSLog(@"de-LWTed %@", me);
                    
                    NSNumber *userId = [me valueForKey:@"userId"];
                    if (userId) {
                        
                        [self.hosted retrieveDevice:accessToken
                                             userId:[userId integerValue]
                                           deviceId:DEVID
                                    completionBlock:^(NSInteger status, NSDictionary *device){
                                        NSLog(@"device %ld/%ld: (%ld) %@", (long)4, (long)1, (long)status, device);
                                        self.returned = true;
                                    }];
                    } else {
                        self.returned = true;
                    }
                } else {
                    self.returned = true;
                }
            }];
        } else {
            self.returned = true;
        }
    }];
    
    while (!self.returned) {
        NSLog(@"waiting");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
}

- (void)testCreateFlow {
    self.returned = false;
    
    [self.hosted createUser:USER password:PASS fullname:FULL email:MAIL completionBlock:^(NSInteger status, NSDictionary *user) {
        NSLog(@"createUser (%ld) %@", (long)status, user);
        
        [self.hosted authenticate:USER password:PASS completionBlock:^(NSInteger status, NSString *refreshToken) {
            NSLog(@"authenticate (%ld) %@", (long)status, refreshToken);
            
            if (refreshToken) {
                [self.hosted accessToken:refreshToken completionBlock:^(NSInteger status, NSString *accessToken) {
                    NSLog(@"accessToken (%ld) %@", (long)status, accessToken);
                    
                    NSDictionary *me = [Hosted decode:accessToken];
                    NSLog(@"de-LWTed %@", me);
                    
                    NSNumber *userId = [me valueForKey:@"userId"];
                    if (userId) {
                        [self.hosted createDevice:accessToken
                                       devicename:DEV
                                           userId:[userId integerValue]
                                  completionBlock:^(NSInteger status, NSDictionary *device) {
                                      NSLog(@"createDevice(%ld) %@", (long)status, device);
                                      self.returned = true;
                                  }];
                    } else {
                        self.returned = true;
                    }
                }];
            } else {
                self.returned = true;
            }
        }];
    }];
    
    while (!self.returned) {
        NSLog(@"waiting");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
}




@end
