//
//  OwnTracksTests.m
//  OwnTracksTests
//
//  Created by Christoph Krey on 03.02.14.
//  Copyright (c) 2014 OwnTracks. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface OwnTracksTests : XCTestCase

@end

@implementation OwnTracksTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testNil
{
    NSMutableDictionary *sections = [[NSMutableDictionary alloc] init];

    NSString *name = nil;
    NSLog(@"name:<%@>", name.description);
    NSString *key = [[name substringToIndex:1] uppercaseString];
    NSLog(@"key:<%@>", key.description);
    NSMutableArray *array = [sections objectForKey:key];
    NSLog(@"array:<%@>", array.description);
}
- (void)testZero
{
    NSMutableDictionary *sections = [[NSMutableDictionary alloc] init];

    NSString *name = @"\0";
    NSLog(@"name:<%@>", name.description);
    NSString *key = [[name substringToIndex:1] uppercaseString];
    NSLog(@"key:<%@>", key.description);
    NSMutableArray *array = [sections objectForKey:key];
    NSLog(@"array:<%@>", array.description);
}
- (void)testAmpValue
{
    NSMutableDictionary *sections = [[NSMutableDictionary alloc] init];

    NSString *name = @"@";
    NSLog(@"name:<%@>", name.description);
    NSString *key = [[name substringToIndex:1] uppercaseString];
    NSLog(@"key:<%@>", key.description);
    NSMutableArray *array = [sections valueForKey:key];
    NSLog(@"array:<%@>", array.description);
}
- (void)testAmp
{
    NSMutableDictionary *sections = [[NSMutableDictionary alloc] init];

    NSString *name = @"@";
    NSLog(@"name:<%@>", name.description);
    NSString *key = [[name substringToIndex:1] uppercaseString];
    NSLog(@"key:<%@>", key.description);
    NSMutableArray *array = [sections objectForKey:key];
    NSLog(@"array:<%@>", array.description);
}
- (void)testAmpOne
{
    NSMutableDictionary *sections = [[NSMutableDictionary alloc] init];

    NSString *name = @"@a";
    NSLog(@"name:<%@>", name.description);
    NSString *key = [[name substringToIndex:2] uppercaseString];
    NSLog(@"key:<%@>", key.description);
    NSMutableArray *array = [sections objectForKey:key];
    NSLog(@"array:<%@>", array.description);
}
- (void)testLenghtOne
{
    NSMutableDictionary *sections = [[NSMutableDictionary alloc] init];

    NSString *name = @"a";
    NSLog(@"name:<%@>", name.description);
    NSString *key = [[name substringToIndex:1] uppercaseString];
    NSLog(@"key:<%@>", key.description);
    NSMutableArray *array = [sections objectForKey:key];
    NSLog(@"array:<%@>", array.description);
}

@end
