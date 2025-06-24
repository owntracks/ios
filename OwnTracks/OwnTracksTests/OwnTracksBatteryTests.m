//
//  OwnTracksBatteryTests.m
//  OwnTracksTests
//
//  Created by Christoph Krey on 21.06.25.
//  Copyright © 2025 OwnTracks. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface OwnTracksBatteryTests : XCTestCase

@end

@implementation OwnTracksBatteryTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testBatteryFormatting {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    
    for (float blf = 0; blf <= 1.0; blf += .05 ) {
        int bli = blf * 100;
        NSLog(@"%f %d", blf, bli);
    }
}

@end
