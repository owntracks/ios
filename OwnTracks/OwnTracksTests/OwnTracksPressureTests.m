//
//  OwnTracksPressureTests.m
//  OwnTracksTests
//
//  Created by Christoph Krey on 10.03.24.
//  Copyright © 2024-2025 OwnTracks. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface OwnTracksPressureTests : XCTestCase
@end

@implementation OwnTracksPressureTests
NSNumber *pressureInkPa;

- (void)setUp {
    pressureInkPa = [NSNumber numberWithFloat:101.325];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testNil {
    [self formatPressure:nil];
}

- (void)testStandard {
    [self formatPressure:[NSNumber numberWithFloat:101.325]];
}

- (void)formatPressure:(NSNumber *)pressureInkPA {
    if (pressureInkPA) {
        NSMeasurement *m = [[NSMeasurement alloc] initWithDoubleValue:pressureInkPA.doubleValue
                                                                 unit:[NSUnitPressure kilopascals]];
        
        NSMeasurement *mhPA = [m measurementByConvertingToUnit:[NSUnitPressure hectopascals]];
        NSMeasurement *mmbar = [m measurementByConvertingToUnit:[NSUnitPressure millibars]];
        NSMeasurement *minHG = [m measurementByConvertingToUnit:[NSUnitPressure inchesOfMercury]];
        
        NSMeasurementFormatter *mf = [[NSMeasurementFormatter alloc] init];
        mf.unitOptions = NSMeasurementFormatterUnitOptionsNaturalScale;
        mf.numberFormatter.maximumFractionDigits = 3;
        NSLog(@"pressure in NaturalScale with 3 digits:%@",
              [mf stringFromMeasurement:m]);

        mf.unitOptions = NSMeasurementFormatterUnitOptionsProvidedUnit;
        mf.numberFormatter.maximumFractionDigits = 3;
        NSLog(@"pressure in kPA with 3 digits:%@",
              [mf stringFromMeasurement:m]);
        
        mf.unitOptions = NSMeasurementFormatterUnitOptionsProvidedUnit;
        mf.numberFormatter.maximumFractionDigits = 2;
        NSLog(@"pressure in hPA with 2 digits:%@",
              [mf stringFromMeasurement:mhPA]);

        mf.unitOptions = NSMeasurementFormatterUnitOptionsProvidedUnit;
        mf.numberFormatter.maximumFractionDigits = 2;
        NSLog(@"pressure in mbar with 2 digits:%@",
              [mf stringFromMeasurement:mmbar]);

        mf.unitOptions = NSMeasurementFormatterUnitOptionsProvidedUnit;
        mf.numberFormatter.maximumFractionDigits = 2;
        NSLog(@"pressure in inHG with 2 digits:%@",
              [mf stringFromMeasurement:minHG]);
    } else {
        NSLog(@"No pressure available");
    }
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
