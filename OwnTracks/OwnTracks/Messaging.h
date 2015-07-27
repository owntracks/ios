//
//  Messaging.h
//  OwnTracks
//
//  Created by Christoph Krey on 20.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Messaging : NSObject
@property (strong, nonatomic) NSString *lastGeoHash;
@property (strong, nonatomic) NSNumber *messages;
+ (Messaging *)sharedInstance;
- (void)shutdown:(NSManagedObjectContext *)context;
- (void)reset:(NSManagedObjectContext *)context;
- (void)updateCounter:(NSManagedObjectContext *)context;
- (void)newLocation:(double)latitude longitude:(double)longitude context:(NSManagedObjectContext *)context;
- (BOOL)processMessage:(NSString *)topic data:(NSData *)data retained:(BOOL)retained context:(NSManagedObjectContext *)context;
- (void)createMessageWithTopic:(NSString *)topic
                          icon:(NSString *)icon
                          prio:(NSInteger)prio
                     timestamp:(NSDate *)timestamp
                           ttl:(NSUInteger)ttl
                         title:(NSString *)title
                          desc:(NSString *)desc
                           url:(NSString *)url
                       iconurl:(NSString *)iconurl
        inManagedObjectContext:(NSManagedObjectContext *)context;

@end
