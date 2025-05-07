//
//  OwnTracksStorageTests.m
//  OwnTracksTests
//
//  Created by Christoph Krey on 21.04.25.
//  Copyright © 2025 OwnTracks. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Waypoint+CoreDataClass.h"
#import "Friend+CoreDataClass.h"
#import "Settings.h"
#import "Coredata.h"

@interface OwnTracksStorageTests : XCTestCase

@end

@implementation OwnTracksStorageTests

- (void)setUp {
}

- (void)tearDown {
}

- (void)testaddWaypoint {
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopicInMOC:moc]
                      inManagedObjectContext:moc];
    NSDate *now = [NSDate now];
    CLLocation *location = [[CLLocation alloc]
                            initWithCoordinate:CLLocationCoordinate2DMake(6.0, 13.0) altitude:100.0
                            horizontalAccuracy:10.0
                            verticalAccuracy:5.0 course:15.0
                            courseAccuracy:3.0
                            speed:17.0
                            speedAccuracy:2.0
                            timestamp:now];

    Waypoint *waypoint = [friend addWaypoint:location
                                   createdAt:nil
                                     trigger:nil
                                         poi:nil
                                         tag:nil
                                     battery:nil
                                       image:nil
                                   imageName:nil
                                   inRegions:nil
                                      inRids:nil
                                       bssid:nil
                                        ssid:nil
                                           m:nil
                                        conn:nil
                                          bs:nil];
    XCTAssertNotNil(waypoint);
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;
    NSLog(@"Number of Waypoints %ld", friend.hasWaypoints.count);
    for (Waypoint *waypoint in friend.hasWaypoints) {
        NSLog(@"Waypoint %@", [formatter stringFromDate:waypoint.tst]);
    }
}

- (void)testAdd50WaypointsAndReduceTo1days {
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopicInMOC:moc]
                      inManagedObjectContext:moc];
    for (NSInteger i = 0; i < 50; i++) {
        NSDate *now = [NSDate dateWithTimeIntervalSinceNow:-24*60*60*i];
        NSLog(@"addWaypoint #%ld %@", i, now);
        CLLocation *location = [[CLLocation alloc]
                                initWithCoordinate:CLLocationCoordinate2DMake(6.0, 13.0) altitude:100.0
                                horizontalAccuracy:10.0
                                verticalAccuracy:5.0 course:15.0
                                courseAccuracy:3.0
                                speed:17.0
                                speedAccuracy:2.0
                                timestamp:now];

        (void)[friend addWaypoint:location
                        createdAt:nil
                          trigger:nil
                              poi:nil
                              tag:nil
                          battery:nil
                            image:nil
                        imageName:nil
                        inRegions:nil
                           inRids:nil
                            bssid:nil
                             ssid:nil
                                m:nil
                             conn:nil
                               bs:nil];
    }
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;
    NSLog(@"Number of Waypoints %ld", friend.hasWaypoints.count);
    for (Waypoint *waypoint in friend.hasWaypoints) {
        NSLog(@"Waypoint %@", [formatter stringFromDate:waypoint.tst]);
    }
    NSLog(@"Reducing to 1 day");
    NSInteger remainingPositions = [friend limitWaypointsToMaximumDays:0];
    NSLog(@"Number of Waypoints %ld", friend.hasWaypoints.count);
    for (Waypoint *waypoint in friend.hasWaypoints) {
        NSLog(@"Waypoint %@", [formatter stringFromDate:waypoint.tst]);
    }
    XCTAssert(remainingPositions == 1);
}

- (void)testAdd50WaypointsAndReduceToToday {
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopicInMOC:moc]
                      inManagedObjectContext:moc];
    for (NSInteger i = 0; i < 50; i++) {
        NSDate *now = [NSDate dateWithTimeIntervalSinceNow:-24*60*60*i];
        NSLog(@"addWaypoint #%ld %@", i, now);
        CLLocation *location = [[CLLocation alloc]
                                initWithCoordinate:CLLocationCoordinate2DMake(6.0, 13.0) altitude:100.0
                                horizontalAccuracy:10.0
                                verticalAccuracy:5.0 course:15.0
                                courseAccuracy:3.0
                                speed:17.0
                                speedAccuracy:2.0
                                timestamp:now];

        (void)[friend addWaypoint:location
                        createdAt:nil
                          trigger:nil
                              poi:nil
                              tag:nil
                          battery:nil
                            image:nil
                        imageName:nil
                        inRegions:nil
                           inRids:nil
                            bssid:nil
                             ssid:nil
                                m:nil
                             conn:nil
                               bs:nil];
    }
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;
    NSLog(@"Number of Waypoints %ld", friend.hasWaypoints.count);
    for (Waypoint *waypoint in friend.hasWaypoints) {
        NSLog(@"Waypoint %@", [formatter stringFromDate:waypoint.tst]);
    }
    NSLog(@"Reducing to 1 day");
    NSInteger remainingPositions = [friend limitWaypointsToMaximumDays:1];
    NSLog(@"Number of Waypoints %ld", friend.hasWaypoints.count);
    for (Waypoint *waypoint in friend.hasWaypoints) {
        NSLog(@"Waypoint %@", [formatter stringFromDate:waypoint.tst]);
    }
    XCTAssert(remainingPositions > 1);
}

- (void)testAdd50WaypointsAndReduceTo1 {
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopicInMOC:moc]
                      inManagedObjectContext:moc];
    for (NSInteger i = 0; i < 50; i++) {
        NSLog(@"addWaypoint #%ld", i);
        NSDate *now = [NSDate now];
        CLLocation *location = [[CLLocation alloc]
                                initWithCoordinate:CLLocationCoordinate2DMake(6.0, 13.0) altitude:100.0
                                horizontalAccuracy:10.0
                                verticalAccuracy:5.0 course:15.0
                                courseAccuracy:3.0
                                speed:17.0
                                speedAccuracy:2.0
                                timestamp:now];

        (void)[friend addWaypoint:location
                        createdAt:nil
                          trigger:nil
                              poi:nil
                              tag:nil
                          battery:nil
                            image:nil
                        imageName:nil
                        inRegions:nil
                           inRids:nil
                            bssid:nil
                             ssid:nil
                                m:nil
                             conn:nil
                               bs:nil];
    }
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;
    NSLog(@"Number of Waypoints %ld", friend.hasWaypoints.count);
    for (Waypoint *waypoint in friend.hasWaypoints) {
        NSLog(@"Waypoint %@", [formatter stringFromDate:waypoint.tst]);
    }
    NSLog(@"Reducing to 1");
    NSInteger remainingPositions = [friend limitWaypointsToMaximum:1];
    NSLog(@"Number of Waypoints %ld", friend.hasWaypoints.count);
    for (Waypoint *waypoint in friend.hasWaypoints) {
        NSLog(@"Waypoint %@", [formatter stringFromDate:waypoint.tst]);
    }
    XCTAssert(remainingPositions == 1);
}

- (void)testAdd500WaypointsAndReduceTo30days {
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopicInMOC:moc]
                      inManagedObjectContext:moc];
    for (NSInteger i = 0; i < 500; i++) {
        NSDate *now = [NSDate dateWithTimeIntervalSinceNow:-2*60*60*i];
        NSLog(@"addWaypoint #%ld %@", i, now);
        CLLocation *location = [[CLLocation alloc]
                                initWithCoordinate:CLLocationCoordinate2DMake(6.0, 13.0) altitude:100.0
                                horizontalAccuracy:10.0
                                verticalAccuracy:5.0 course:15.0
                                courseAccuracy:3.0
                                speed:17.0
                                speedAccuracy:2.0
                                timestamp:now];

        (void)[friend addWaypoint:location
                        createdAt:nil
                          trigger:nil
                              poi:nil
                              tag:nil
                          battery:nil
                            image:nil
                        imageName:nil
                        inRegions:nil
                           inRids:nil
                            bssid:nil
                             ssid:nil
                                m:nil
                             conn:nil
                               bs:nil];
        NSInteger remainingPositions = [friend limitWaypointsToMaximumDays:30];
        NSLog(@"addWaypoint remainingPositions=%ld", remainingPositions);
    }
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;
    NSLog(@"Number of Waypoints %ld", friend.hasWaypoints.count);
    //for (Waypoint *waypoint in friend.hasWaypoints) {
    //    NSLog(@"Waypoint %@", [formatter stringFromDate:waypoint.tst]);
    //}
}


- (void)testAdd5000WaypointsAndReduceTo30days {
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopicInMOC:moc]
                      inManagedObjectContext:moc];
    for (NSInteger i = 0; i < 5000; i++) {
        NSDate *now = [NSDate dateWithTimeIntervalSinceNow:-60*60*i];
        NSLog(@"addWaypoint #%ld %@", i, now);
        CLLocation *location = [[CLLocation alloc]
                                initWithCoordinate:CLLocationCoordinate2DMake(6.0, 13.0) altitude:100.0
                                horizontalAccuracy:10.0
                                verticalAccuracy:5.0 course:15.0
                                courseAccuracy:3.0
                                speed:17.0
                                speedAccuracy:2.0
                                timestamp:now];

        (void)[friend addWaypoint:location
                        createdAt:nil
                          trigger:nil
                              poi:nil
                              tag:nil
                          battery:nil
                            image:nil
                        imageName:nil
                        inRegions:nil
                           inRids:nil
                            bssid:nil
                             ssid:nil
                                m:nil
                             conn:nil
                               bs:nil];
        NSInteger remainingPositions = [friend limitWaypointsToMaximumDays:30];
        NSLog(@"addWaypoint remainingPositions=%ld", remainingPositions);
    }
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;
    NSLog(@"Number of Waypoints %ld", friend.hasWaypoints.count);
    //for (Waypoint *waypoint in friend.hasWaypoints) {
    //    NSLog(@"Waypoint %@", [formatter stringFromDate:waypoint.tst]);
    //}
}


- (void)testAdd50WaypointsAndReduceTo2 {
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopicInMOC:moc]
                      inManagedObjectContext:moc];
    for (NSInteger i = 0; i < 50; i++) {
        NSLog(@"addWaypoint #%ld", i);
        NSDate *now = [NSDate now];
        CLLocation *location = [[CLLocation alloc]
                                initWithCoordinate:CLLocationCoordinate2DMake(6.0, 13.0) altitude:100.0
                                horizontalAccuracy:10.0
                                verticalAccuracy:5.0 course:15.0
                                courseAccuracy:3.0
                                speed:17.0
                                speedAccuracy:2.0
                                timestamp:now];

        (void)[friend addWaypoint:location
                        createdAt:nil
                          trigger:nil
                              poi:nil
                              tag:nil
                          battery:nil
                            image:nil
                        imageName:nil
                        inRegions:nil
                           inRids:nil
                            bssid:nil
                             ssid:nil
                                m:nil
                             conn:nil
                               bs:nil];
    }
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;
    NSLog(@"Number of Waypoints %ld", friend.hasWaypoints.count);
    for (Waypoint *waypoint in friend.hasWaypoints) {
        NSLog(@"Waypoint %@", [formatter stringFromDate:waypoint.tst]);
    }
    NSLog(@"Reducing to 2");
    NSInteger remainingPositions = [friend limitWaypointsToMaximum:2];
    NSLog(@"Number of Waypoints %ld", friend.hasWaypoints.count);
    for (Waypoint *waypoint in friend.hasWaypoints) {
        NSLog(@"Waypoint %@", [formatter stringFromDate:waypoint.tst]);
    }
    XCTAssert(remainingPositions == 2);
}

- (void)testAdd50WaypointsAndReduceTo0 {
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopicInMOC:moc]
                      inManagedObjectContext:moc];
    for (NSInteger i = 0; i < 50; i++) {
        NSLog(@"addWaypoint #%ld", i);
        NSDate *now = [NSDate now];
        CLLocation *location = [[CLLocation alloc]
                                initWithCoordinate:CLLocationCoordinate2DMake(6.0, 13.0) altitude:100.0
                                horizontalAccuracy:10.0
                                verticalAccuracy:5.0 course:15.0
                                courseAccuracy:3.0
                                speed:17.0
                                speedAccuracy:2.0
                                timestamp:now];

        (void)[friend addWaypoint:location
                        createdAt:nil
                          trigger:nil
                              poi:nil
                              tag:nil
                          battery:nil
                            image:nil
                        imageName:nil
                        inRegions:nil
                           inRids:nil
                            bssid:nil
                             ssid:nil
                                m:nil
                             conn:nil
                               bs:nil];
    }
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;
    NSLog(@"Number of Waypoints %ld", friend.hasWaypoints.count);
    for (Waypoint *waypoint in friend.hasWaypoints) {
        NSLog(@"Waypoint %@", [formatter stringFromDate:waypoint.tst]);
    }
    NSLog(@"Reducing to 0");
    NSInteger remainingPositions = [friend limitWaypointsToMaximum:0];
    NSLog(@"Number of Waypoints %ld", friend.hasWaypoints.count);
    for (Waypoint *waypoint in friend.hasWaypoints) {
        NSLog(@"Waypoint %@", [formatter stringFromDate:waypoint.tst]);
    }
    XCTAssert(remainingPositions == 1);
}

- (void)testFetchWaypoints {
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopicInMOC:moc]
                      inManagedObjectContext:moc];
    [moc performBlockAndWait:^{
        NSFetchRequest<Waypoint *> *request = Waypoint.fetchRequest;
        request.predicate = [NSPredicate predicateWithFormat:@"belongsTo = %@", friend];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"tst" ascending:TRUE]];
        NSError *error;
        NSArray <Waypoint *>*result = [request execute:&error];
        NSLog(@"error:%@ result:%@", error, result);
    }];
}

- (void)testFetchLatest1000Waypoints {
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopicInMOC:moc]
                      inManagedObjectContext:moc];
    [moc performBlockAndWait:^{
        NSFetchRequest<Waypoint *> *request = Waypoint.fetchRequest;
        request.predicate = [NSPredicate predicateWithFormat:@"belongsTo = %@", friend];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"tst" ascending:FALSE]];
        request.fetchLimit = 1000;
        NSError *error;
        NSArray <Waypoint *>*result = [request execute:&error];
        NSLog(@"error:%@ result:%@", error, result);
    }];
}

@end
