//
//  Shares.m
//  OwnTracks
//
//  Created by Christoph Krey on 02.08.22.
//  Copyright © 2022 OwnTracks. All rights reserved.
//

#import "Shares.h"
#import "CoreData.h"
#import "Settings.h"
#import "OwnTracksAppDelegate.h"

@implementation Share
- (instancetype)initFromDictionary:(NSDictionary *)dictionary {
    self = [self init];
    if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
        self.label = dictionary[@"label"];
        self.uuid = dictionary[@"uuid"];
        self.url = dictionary[@"url"];
        NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions ^= NSISO8601DateFormatWithTimeZone;
        self.from = [formatter dateFromString:dictionary[@"from"]];
        self.to = [formatter dateFromString:dictionary[@"to"]];
    }
    return self;
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

- (NSComparisonResult)compare:(Share *)share {
    return [self.from compare:share.from];
}

@end

@interface Shares()
@property (strong, nonatomic) NSMutableArray <Share *> *array;
@property (strong, nonatomic) NSTimer *shareTimer;
@property (strong, nonatomic) NSTimer *sharesTimer;
@end

@implementation Shares
static Shares *theInstance = nil;

+ (Shares *)sharedInstance {
    if (theInstance == nil) {
        theInstance = [[Shares alloc] init];
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
    NSArray *array = [response objectForKey:@"shares"];
    if (array && [array isKindOfClass:[NSArray class]]) {
        for (NSDictionary *dictionary in array) {
            if ([dictionary isKindOfClass:[NSDictionary class]]) {
                Share *share = [[Share alloc] initFromDictionary:dictionary];
                [self.array addObject:share];
            }
        }
    }
    self.array = [[self.array sortedArrayUsingSelector:@selector(compare:)] mutableCopy];
    self.timestamp = [NSDate date];
    [self.sharesTimer invalidate];
    self.activity = @(FALSE);
    self.message = NSLocalizedString(@"Sharings list received", @"Sharings list received");
}

- (NSInteger)count{
    return self.array.count;
}

- (Share *)shareAtIndex:(NSInteger)index {
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
        @"request": @"shares",
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
    self.message = NSLocalizedString(@"Requesting sharings list", @"Requesting sharings list");
    if (self.sharesTimer && self.sharesTimer.isValid) {
        [self.sharesTimer invalidate];
    }
    self.sharesTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                       repeats:FALSE
                                                         block:^(NSTimer * _Nonnull timer) {
        self.activity = @(FALSE);
        self.message = NSLocalizedString(@"Sharings list request timed out", @"Sharings list request timed out");
    }];
}

- (void)addShare:(Share *)share {
    [self.array addObject:share];
    self.array = [[self.array sortedArrayUsingSelector:@selector(compare:)] mutableCopy];
    self.timestamp = [NSDate date];
    [self.shareTimer invalidate];
    self.activity = @(FALSE);
    self.message = NSLocalizedString(@"Sharing created", @"Sharing created");
}

- (void)requestShare:(Share *)share {
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    NSString *topic = [Settings theGeneralTopicInMOC:moc];
    
    NSDictionary *json = @{
        @"_type": @"request",
        @"request": @"share",
        @"share": share.asDictionary
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
    self.message = NSLocalizedString(@"Requesting Sharing", @"Requesting Sharing");
    if (self.shareTimer && self.shareTimer.isValid) {
        [self.shareTimer invalidate];
    }
    self.shareTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                      repeats:FALSE
                                                        block:^(NSTimer * _Nonnull timer) {
        self.activity = @(FALSE);
        self.message = NSLocalizedString(@"Sharing request timed out", @"Sharing request timed out");
    }];
}

- (BOOL)removeShareAtIndex:(NSInteger)index {
    Share *share = [self shareAtIndex:index];
    if (!share) {
        return FALSE;
    }
    
    if (share.uuid) {
        NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
        NSString *topic = [Settings theGeneralTopicInMOC:moc];
        
        NSDictionary *json = @{
            @"_type": @"request",
            @"request": @"unshare",
            @"uuid": share.uuid,
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
        self.message = NSLocalizedString(@"Sharing deleted", @"Sharing deleted");
    }
    
    [self.array removeObjectAtIndex:index];
    self.timestamp = [NSDate date];
    return TRUE;
}
@end
