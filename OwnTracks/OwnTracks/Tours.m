//
//  Tours.m
//  OwnTracks
//
//  Created by Christoph Krey on 02.08.22.
//  Copyright © 2022 OwnTracks. All rights reserved.
//

#import "Tours.h"
#import "CoreData.h"
#import "Settings.h"
#import "OwnTracksAppDelegate.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

static const DDLogLevel ddLogLevel = DDLogLevelInfo;

@implementation Tour
- (instancetype)initFromDictionary:(NSDictionary *)dictionary {
    self = [self init];
    if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
        NSString *label = dictionary[@"label"];
        if (label && [label isKindOfClass:[NSString class]]){
            self.label = label;
        } else {
            DDLogError(@"[Tours] initFromDictionary invalid label");
            return nil;
        }

        NSString *uuidString = dictionary[@"uuid"];
        if (label && [label isKindOfClass:[NSString class]]){
            self.uuid = uuidString;
        } else {
            DDLogError(@"[Tours] initFromDictionary invalid uuid");
            return nil;
        }

        NSString *urlString = dictionary[@"url"];
        if (label && [label isKindOfClass:[NSString class]]){
            self.url = urlString;
        } else {
            DDLogError(@"[Tours] initFromDictionary invalid url");
            return nil;
        }

        NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions ^= NSISO8601DateFormatWithTimeZone;
        NSString *fromString = dictionary[@"from"];
        if (fromString && [fromString isKindOfClass:[NSString class]]) {
            self.from = [formatter dateFromString:fromString];
            if (!self.from) {
                DDLogError(@"[Tours] initFromDictionary invalid from dateformat");
                return nil;
            }
        } else {
            DDLogError(@"[Tours] initFromDictionary invalid from");
            return nil;
        }
        
        NSString *toString = dictionary[@"to"];
        if (fromString && [fromString isKindOfClass:[NSString class]]) {
            self.to = [formatter dateFromString:toString];
            if (!self.to) {
                DDLogError(@"[Tours] initFromDictionary invalid to dateformat");
                return nil;
            }
        } else {
            DDLogError(@"[Tours] initFromDictionary invalid to");
            return nil;
        }

        return self;
    } else {
        DDLogError(@"[Tours] initFromDictionary invalid dictionary");
        return nil;
    }
}

- (NSDictionary *)asDictionary {
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime ^
    NSISO8601DateFormatWithTimeZone;
    formatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
    
    NSMutableDictionary *dictionary = [@{
        @"label": self.label,
        @"from":  [formatter stringFromDate:self.from],
        @"to": [formatter stringFromDate:self.to]
    } mutableCopy];
    
    if (self.uuid) {
        dictionary[@"uuid"] = self.uuid;
    }
    if (self.url) {
        dictionary[@"url"] = self.url;
    }
    return dictionary;
}

- (NSComparisonResult)compare:(Tour *)tour {
    return [self.from compare:tour.from];
}

@end

@interface Tours()
@property (strong, nonatomic) NSMutableArray <Tour *> *array;
@property (strong, nonatomic) NSTimer *tourTimer;
@property (strong, nonatomic) NSTimer *toursTimer;
@end

@implementation Tours
static Tours *theInstance = nil;

+ (Tours *)sharedInstance {
    if (theInstance == nil) {
        theInstance = [[Tours alloc] init];
    }
    return theInstance;
}

- (instancetype)init {
    self = [super init];
    self.timestamp = [NSDate distantPast];
    self.array = [[NSMutableArray alloc] init];
    [self refresh];
    return self;
}

- (void)setResponse:(NSMutableDictionary *)response {
    _response = response;
    self.array = [[NSMutableArray alloc] init];
    NSArray *array = [response objectForKey:@"tours"];
    if (array && [array isKindOfClass:[NSArray class]]) {
        for (NSDictionary *dictionary in array) {
            if ([dictionary isKindOfClass:[NSDictionary class]]) {
                Tour *tour = [[Tour alloc] initFromDictionary:dictionary];
                [self.array addObject:tour];
            }
        }
    }
    self.array = [[self.array sortedArrayUsingSelector:@selector(compare:)] mutableCopy];
    self.timestamp = [NSDate date];
    [self.toursTimer invalidate];
    self.activity = @(FALSE);
    self.message = NSLocalizedString(@"Tour list received", @"Tour list received");
}

- (NSInteger)count{
    return self.array.count;
}

- (Tour *)tourAtIndex:(NSInteger)index {
    if (index < self.array.count) {
        return self.array[index];
    } else {
        return nil;
    }
}

- (void)refresh {
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    NSString *topic = [Settings theGeneralTopicInMOC:moc];
    
    NSDictionary *json = @{
        @"_type": @"request",
        @"request": @"tours",
    };
    
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.connection sendData:[NSJSONSerialization dataWithJSONObject:json
                                                            options:NSJSONWritingSortedKeys
                                                              error:nil]
                      topic:[topic stringByAppendingString:@"/request"]
                 topicAlias:@(0)
                        qos:MQTTQosLevelAtMostOnce
                     retain:NO];
    self.activity = @(TRUE);
    self.message = NSLocalizedString(@"Requesting tour list", @"Requesting tour list");
    if (self.toursTimer && self.toursTimer.isValid) {
        [self.toursTimer invalidate];
    }
    self.toursTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                       repeats:FALSE
                                                         block:^(NSTimer * _Nonnull timer) {
        self.activity = @(FALSE);
        self.message = NSLocalizedString(@"Tour list request timed out", @"Tour list request timed out");
    }];
}

- (void)addTour:(Tour *)tour {
    [self.array addObject:tour];
    self.array = [[self.array sortedArrayUsingSelector:@selector(compare:)] mutableCopy];
    self.timestamp = [NSDate date];
    [self.tourTimer invalidate];
    self.activity = @(FALSE);
    self.message = NSLocalizedString(@"Tour created", @"Tour created");
}

- (void)requestTour:(Tour *)tour {
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    NSString *topic = [Settings theGeneralTopicInMOC:moc];
    
    NSDictionary *json = @{
        @"_type": @"request",
        @"request": @"tour",
        @"tour": tour.asDictionary
    };
    
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.connection sendData:[NSJSONSerialization dataWithJSONObject:json
                                                            options:NSJSONWritingSortedKeys
                                                              error:nil]
                      topic:[topic stringByAppendingString:@"/request"]
                 topicAlias:@(0)
                        qos:MQTTQosLevelAtMostOnce
                     retain:NO];
    self.activity = @(TRUE);
    self.message = NSLocalizedString(@"Requesting tour", @"Requesting tour");
    if (self.tourTimer && self.tourTimer.isValid) {
        [self.tourTimer invalidate];
    }
    self.tourTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                      repeats:FALSE
                                                        block:^(NSTimer * _Nonnull timer) {
        self.activity = @(FALSE);
        self.message = NSLocalizedString(@"Tour request timed out", @"Tour request timed out");
    }];
}

- (BOOL)removeTourAtIndex:(NSInteger)index {
    Tour *tour = [self tourAtIndex:index];
    if (!tour) {
        return FALSE;
    }
    
    if (tour.uuid) {
        NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
        NSString *topic = [Settings theGeneralTopicInMOC:moc];
        
        NSDictionary *json = @{
            @"_type": @"request",
            @"request": @"untour",
            @"uuid": tour.uuid,
        };
        
        OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        [ad.connection sendData:[NSJSONSerialization dataWithJSONObject:json
                                                                options:NSJSONWritingSortedKeys
                                                                  error:nil]
                          topic:[topic stringByAppendingString:@"/request"]
                     topicAlias:@(0)
                            qos:MQTTQosLevelAtMostOnce
                         retain:NO];
        self.activity = @(FALSE);
        self.message = NSLocalizedString(@"Tour deleted", @"Tour deleted");
    }
    
    [self.array removeObjectAtIndex:index];
    self.timestamp = [NSDate date];
    return TRUE;
}

- (BOOL)processResponse:(NSDictionary *)dictionary {
    if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
        NSString *request = dictionary[@"request"];
        if (request && [request isKindOfClass:[NSString class]]) {
            if ([request isEqualToString:@"tour"]) {
                NSNumber *status = dictionary[@"status"];
                if (status && [status isKindOfClass:[NSNumber class]]) {
                    if (status.integerValue == 200) {
                        NSDictionary *tourDictionary = dictionary[@"tour"];
                        if (tourDictionary && [tourDictionary isKindOfClass:[NSDictionary class]]) {
                            Tour *tour = [[Tour alloc] initFromDictionary:dictionary[@"tour"]];
                            if (tour) {
                                [[Tours sharedInstance] addTour:tour];
                                
                                UIPasteboard *generalPasteboard = [UIPasteboard generalPasteboard];
                                [generalPasteboard setString:tour.url];
                                
                                OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
                                
                                [ad.navigationController alert:
                                     NSLocalizedString(@"Response",
                                                       @"Alert message header for Request Response")
                                                       message:
                                     [NSString stringWithFormat:@"%@ %ld %@\n",
                                      NSLocalizedString(@"URL copied to Clipboard",
                                                        @"URL copied to Clipboard"),
                                      (long)status.integerValue,
                                      tour.url]
                                                           url:tour.url
                                ];
                            } else {
                                DDLogError(@"[Tours] processResponse invalid tour");
                                return FALSE;
                            }
                        } else {
                            DDLogError(@"[Tours] processResponse invalid tour dictionary");
                            return FALSE;
                        }
                    } else {
                        DDLogError(@"[Tours] processResponse response status not 200 %@", status);
                        return FALSE;
                    }
                    return TRUE;
                } else {
                    DDLogError(@"[Tours] processResponse request not tour or tours %@", request);
                    return FALSE;

                }
            } else if ([request isEqual:@"tours"]) {
                self.response = [dictionary mutableCopy];
                return TRUE;
            } else {
                DDLogError(@"[Tours] processResponse request not tour or tours %@", request);
                return FALSE;
            }
        } else {
            DDLogError(@"[Tours] processResponse request invalid");
            return FALSE;
        }
    } else {
        DDLogError(@"[Tours] processResponse invalid dictionary");
        return FALSE;
    }
}
@end
