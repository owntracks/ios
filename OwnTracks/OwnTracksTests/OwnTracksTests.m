//
//  OwnTracksTests.m
//  OwnTracksTests
//
//  Created by Christoph Krey on 01.02.21.
//  Copyright © 2021-2025 OwnTracks. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSNumber+decimals.h"
#import "Validation.h"
#import <CoreLocation/CoreLocation.h>

@interface OwnTracksAppDelegate : UIResponder
- (BOOL)handleMessage:(NSObject *)connection
                 data:(NSData *)data
              onTopic:(NSString *)topic
             retained:(BOOL)retained;

@end

@interface NSObject (safeIntValue)
- (int)safeIntValue;
@end

@implementation NSObject (safeIntValue)
- (int)safeIntValue{
    int i = 0;
    if (self && [self respondsToSelector:@selector(intValue)]) {
        i = (int)[self performSelector:@selector(intValue)];
    }
    return i;
}

@end

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
    NSLog(@"jsonString %@",jsonString);
    NSDictionary *dictFromData = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                 options:0
                                                                   error:nil];
    NSLog(@"dictFromData %@", dictFromData);
    XCTAssert(TRUE);
}

- (void)testTimeZone {
    NSDate *d = [NSDate date];
    NSTimeZone *t = [NSTimeZone systemTimeZone];
    NSTimeZone *mexico = [NSTimeZone timeZoneWithName:@"America/Mexico_City"];
    
    NSLog(@"knownTimeZoneNames %@", [NSTimeZone knownTimeZoneNames]);

    NSLog(@"NSDate %@", d);
    NSLog(@"NSTimezone %@, %@, %@, %ld",
          t.name,
          t.description,
          [t abbreviationForDate:d],
          (long)[t secondsFromGMTForDate:d]);
    NSLog(@"NSTimezone America/Mexico_City %@, %@, %@, %ld",
          mexico.name,
          mexico.description,
          [mexico abbreviationForDate:d],
          (long)[mexico secondsFromGMTForDate:d]);

    
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.timeZone = t;
    NSISO8601DateFormatter *i = [[NSISO8601DateFormatter alloc] init];
    i.timeZone = t;
    NSISO8601DateFormatter *m = [[NSISO8601DateFormatter alloc] init];
    m.timeZone = mexico;

    f.dateStyle = NSDateFormatterFullStyle;
    f.timeStyle = NSDateFormatterFullStyle;
    NSLog(@"NDateFormatter %@", [f stringFromDate:d]);
    f.dateStyle = NSDateFormatterLongStyle;
    f.timeStyle = NSDateFormatterLongStyle;
    NSLog(@"NDateFormatter %@", [f stringFromDate:d]);
    f.dateStyle = NSDateFormatterShortStyle;
    f.timeStyle = NSDateFormatterShortStyle;
    NSLog(@"NDateFormatter %@", [f stringFromDate:d]);

    NSLog(@"NSISO8601DateFormatter %@", [i stringFromDate:d]);
    NSLog(@"NSISO8601DateFormatter America/Mexico_City %@", [m stringFromDate:d]);

}

- (void)testMeasurementVsRelativeDateTime {
    NSDate *timestamp = [NSDate dateWithTimeIntervalSinceNow:-3600*24*7]; // one week ago
    
    NSTimeInterval interval = -[timestamp timeIntervalSinceNow];
    NSMeasurement *m = [[NSMeasurement alloc] initWithDoubleValue:interval
                                                             unit:[NSUnitDuration seconds]];
    NSMeasurementFormatter *mf = [[NSMeasurementFormatter alloc] init];
    mf.unitOptions = NSMeasurementFormatterUnitOptionsNaturalScale;
    mf.numberFormatter.maximumFractionDigits = 0;
    NSLog(@"NSMeasurementFormatter %@",
          [mf stringFromMeasurement:m]);
    
    NSRelativeDateTimeFormatter *r = [[NSRelativeDateTimeFormatter alloc] init];
    NSLog(@"NSRelativeDateTimeFormatter %@",
          [r localizedStringForDate:timestamp
                     relativeToDate:[NSDate date]]);
}

- (void)testMeasurementPressure {
    NSMeasurement *m = [[NSMeasurement alloc] initWithDoubleValue:100.1237
                                                             unit:[NSUnitPressure kilopascals]];
    NSMeasurementFormatter *mf = [[NSMeasurementFormatter alloc] init];
    mf.unitOptions = NSMeasurementFormatterUnitOptionsNaturalScale;
    mf.numberFormatter.maximumFractionDigits = 3;
    NSString *stringFromMeasurement = [mf stringFromMeasurement:m];
    NSLog(@"stringFromMeasurement <%@>", stringFromMeasurement);
    XCTAssertNotNil(stringFromMeasurement);
}

- (void)testIncomingJSONnil {
    [self incomingJSON:nil];
}

- (void)testIncomingJSONzeroLength {
    [self incomingJSON:@""];
}

- (void)testIncomingJSONempty {
    [self incomingJSON:@"{}"];
}

- (void)testIncomingJSONarray {
    [self incomingJSON:@"[]"];
}

- (void)testIncomingJSONnull {
    [self incomingJSON:@"null"];
}

- (void)testIncomingJSONvalid {
    [self incomingJSON:@"{\"_type\":\"location\",\"tst\":1707470410,\"lat\":51.4,\"lon\":8.3,\"vel\":100,\"batt\":75}"];
}

- (void)testIncomingJSONwithNullBatt {
    [self incomingJSON:@"{\"_type\":\"location\",\"tst\":1707470410,\"lat\":51.4,\"lon\":8.3,\"vel\":100,\"batt\":null}"];
}

- (void)testIncomingJSONwithTrueBatt {
    [self incomingJSON:@"{\"_type\":\"location\",\"tst\":1707470410,\"lat\":51.4,\"lon\":8.3,\"vel\":100,\"batt\":true}"];
}

- (void)testIncomingJSONwithStringBatt {
    [self incomingJSON:@"{\"_type\":\"location\",\"tst\":1707470410,\"lat\":51.4,\"lon\":8.3,\"vel\":100,\"batt\":\"75\"}"];
}

- (void)testIncomingJSONwithObjectBatt {
    [self incomingJSON:@"{\"_type\":\"location\",\"tst\":1707470410,\"lat\":51.4,\"lon\":8.3,\"vel\":100,\"batt\":{\"description\":\"the battery is empty\"}}"];
}

- (void)testIncomingJSONwithArrayBatt {
    [self incomingJSON:@"{\"_type\":\"location\",\"tst\":1707470410,\"lat\":51.4,\"lon\":8.3,\"vel\":100,\"batt\":[]}"];
}

- (void)testIncomingJSONwithNullVel {
    [self incomingJSON:@"{\"_type\":\"location\",\"tst\":1707470410,\"lat\":51.4,\"lon\":8.3,\"vel\":null,\"batt\":75}"];
}

- (void)testIncomingJSONwithNullLat {
    [self incomingJSON:@"{\"_type\":\"location\",\"tst\":1707470410,\"lat\":null,\"lon\":8.3,\"vel\":100,\"batt\":75}"];
}

- (void)testIncomingJSONwithNullLon {
    [self incomingJSON:@"{\"_type\":\"location\",\"tst\":1707470410,\"lat\":51.4,\"lon\":null,\"vel\":100,\"batt\":75}"];
}

- (void)testIncomingJSONwithNullTst {
    [self incomingJSON:@"{\"_type\":\"location\",\"tst\":null,\"lat\":51.4,\"lon\":8.3,\"vel\":100,\"batt\":75}"];
}

- (void)testIncomingJSONwithNullType {
    [self incomingJSON:@"{\"_type\":null,\"tst\":1707470410,\"lat\":51.4,\"lon\":8.3,\"vel\":100,\"batt\":75}"];
}

- (void)incomingJSON:(NSString *)jsonString {
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dictionary;
    id json = [[Validation sharedInstance] validateMessageData:data];
    if (json && [json isKindOfClass:[NSDictionary class]]) {
        dictionary = json;
    }
            
    if (dictionary) {
        NSString *type = dictionary[@"_type"];
                          
        if (type && [type isKindOfClass:[NSString class]] && [type isEqualToString:@"location"]) {
            NSNumber *lat = dictionary[@"lat"];
            NSNumber *lon = dictionary[@"lon"];

            if (lat && [lat isKindOfClass:[NSNumber class]] &&
                lon && [lon isKindOfClass:[NSNumber class]]) {
                CLLocationCoordinate2D coordinate =
                CLLocationCoordinate2DMake(
                                           [lat doubleValue],
                                           [lon doubleValue]
                                           );
            }
            
            NSNumber *vel = dictionary[@"vel"];
            int speed = -1;
            if (vel && [vel isKindOfClass:[NSNumber class]]) {
                speed = [vel intValue];
                if (speed != -1) {
                    speed = speed * 1000 / 3600;
                }
            }
            
            NSNumber *batt = dictionary[@"batt"];
            NSNumber *batteryLevel = [NSNumber numberWithFloat:-1.0];
            if (batt && [batt isKindOfClass:[NSNumber class]]) {
                int iBatt = [batt intValue];
                if (iBatt >= 0) {
                    batteryLevel = [NSNumber numberWithFloat:iBatt / 100.0];
                }
            }
        } else {
            XCTAssert(TRUE);
        }
    } else {
        XCTAssert(TRUE);
    }
}

- (void)testIntValue {
    NSNumber *n = [NSNumber numberWithInt:3];
    NSString *s = @"3";
    NSNull *zero = [NSNull null];
    NSDictionary *d = [NSDictionary dictionary];
    NSArray *a = [NSArray array];
    id nix = nil;
    
    int i;
    id o;
    i = -1;
    o = n;
    i = [o safeIntValue];
    XCTAssertEqual(i, 3);

    i = -1;
    o = s;
    i = [o safeIntValue];
    XCTAssertEqual(i, 3);

    i = -1;
    o = zero;
    i = [o safeIntValue];
    XCTAssertEqual(i, 0);

    i = -1;
    o = d;
    i = [o safeIntValue];
    XCTAssertEqual(i, 0);

    i = -1;
    o = a;
    i = [o safeIntValue];
    XCTAssertEqual(i, 0);

    i = -1;
    o = nix;
    i = [o safeIntValue];
    XCTAssertEqual(i, 0); // note this is not -1
}

- (void)testProcessing {
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [ad handleMessage:nil
                 data:[@"{\"_type\":\"location\",\"tst\":1707470410,\"lat\":51.4,\"lon\":8.3,\"vel\":100,\"batt\":75}" dataUsingEncoding:NSUTF8StringEncoding]
              onTopic:@"owntracks/owntrackstest/device"
             retained:FALSE];
    NSLog(@"waiting");
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:20]];
    NSLog(@"done");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}
@end
