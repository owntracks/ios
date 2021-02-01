//
//  OwnTracksTests.m
//  OwnTracksTests
//
//  Created by Christoph Krey on 01.02.21.
//  Copyright © 2021 OwnTracks. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSNumber+decimals.h"

@interface OwnTracksTests : XCTestCase

@end

@implementation OwnTracksTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testNumberJson {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    NSNumber *lat = @(51.1958123);
    NSNumber *lon = @(6.68826123);
    dict[@"lat"] = lat;
    dict[@"lon"] = lon;
    dict[@"_type"] = @"test";
    NSLog(@"dict %@", dict);
    NSData *jsonData =
    [NSJSONSerialization dataWithJSONObject:dict
                                    options:NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted
                                      error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData
                                                 encoding:NSUTF8StringEncoding];
    NSLog(@"json %@",jsonString);
    NSDictionary *dictFromData = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                 options:0
                                                                   error:nil];
    NSLog(@"dictFromData %@", dictFromData);

    XCTAssert(TRUE);
}

- (void)testDecimalNumberJson {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    NSNumber *latDouble = @(51.1958123);
    NSNumber *lonDouble = @(6.68826123);
    NSNumber *altDouble = @(100.345);
    dict[@"lat"] = [latDouble decimals:6];
    dict[@"lon"] = lonDouble.sixDecimals;
    dict[@"alt"] = altDouble.zeroDecimals;
    dict[@"_type"] = @"test";
    NSLog(@"dict %@", dict);
    NSData *jsonData =
    [NSJSONSerialization dataWithJSONObject:dict
                                    options:NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted
                                      error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData
                                                 encoding:NSUTF8StringEncoding];
    NSLog(@"json %@",jsonString);
    NSDictionary *dictFromData = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                 options:0
                                                                   error:nil];
    NSLog(@"dictFromData %@", dictFromData);

    XCTAssert(TRUE);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
