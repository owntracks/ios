//
//  Message+Create.m
//  OwnTracks
//
//  Created by Christoph Krey on 20.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "Message+Create.h"

@implementation Message (Create)

+ (Message *)messageWithTopic:(NSString *)topic
                    timestamp:(NSDate *)timestamp
                       expiry:(NSDate *)expiry
                          desc:(NSString *)desc
                          url:(NSString *)url
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
        message.timestamp = timestamp;
        message.expiry = expiry;
        message.desc = desc;
        message.url = url;
    }
    
    return message;
}

+ (void)expireMessages:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Message"];
    request.predicate = [NSPredicate predicateWithFormat:@"expiry < %@", [NSDate date]];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    for (Message *message in matches) {
        [context deleteObject:message];
    }
}

+ (void)removeMessages:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Message"];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    for (Message *message in matches) {
        [context deleteObject:message];
    }
}

+ (void)removeMessages:(NSString *)geoHash context:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Message"];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    for (Message *message in matches) {
        if ([message.topic hasSuffix:geoHash]) {
            [context deleteObject:message];
        }
    }
}


@end
