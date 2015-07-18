//
//  Message+Create.m
//  OwnTracks
//
//  Created by Christoph Krey on 20.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "Message+Create.h"

@implementation Message (Create)

- (NSString *)geohash {
    NSArray *components = [self.topic componentsSeparatedByString:@"/"];
    if (components.count == 3) {
        return components[2];
    } else {
        return nil;
    }
}

- (NSString *)channel {
    NSArray *components = [self.topic componentsSeparatedByString:@"/"];
    if (components.count >= 2) {
        return components[1];
    } else {
        return nil;
    }
}

+ (Message *)messageWithTopic:(NSString *)topic
                         icon:(NSString *)icon
                         prio:(NSInteger)prio
                    timestamp:(NSDate *)timestamp
                          ttl:(NSUInteger)ttl
                        title:(NSString *)title
                         desc:(NSString *)desc
                          url:(NSString *)url
                      iconurl:(NSString *)iconurl
       inManagedObjectContext:(NSManagedObjectContext *)context {
    Message *message = nil;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Message"];
    request.predicate = [NSPredicate predicateWithFormat:@"topic = %@ AND timestamp = %@",
                         topic,
                         timestamp];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (!matches) {
        // handle error
    } else {
        if (![matches count]) {
            message = [NSEntityDescription insertNewObjectForEntityForName:@"Message"
                                                     inManagedObjectContext:context];
        } else {
            message = [matches lastObject];
        }
        message.topic = topic;
        message.icon = icon;
        message.prio = [NSNumber numberWithInteger:prio];
        message.timestamp = timestamp;
        message.ttl = [NSNumber numberWithUnsignedInteger:ttl];
        message.title = title;
        message.desc = desc;
        message.url = url;
        message.iconurl = iconurl;
    }
    
    return message;
}

+ (NSUInteger)expireMessages:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Message"];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    NSUInteger count = matches.count;
    for (Message *message in matches) {
        NSUInteger ttl = [message.ttl unsignedIntegerValue];
        if (ttl > 0) {
        NSDate *expires = [message.timestamp dateByAddingTimeInterval:ttl];
            if ([expires timeIntervalSince1970] < now) {
                [context deleteObject:message];
                count--;
            }
        }
    }
    return count;
}

+ (NSUInteger)removeMessages:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Message"];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    NSUInteger count = matches.count;
    for (Message *message in matches) {
        [context deleteObject:message];
        count--;
    }
    return count;
}

+ (NSUInteger)removeMessages:(NSString *)geoHash context:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Message"];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    NSUInteger count = matches.count;
    for (Message *message in matches) {
        if ([message.topic hasSuffix:geoHash]) {
            [context deleteObject:message];
            count--;
        }
    }
    return count;
}

@end
