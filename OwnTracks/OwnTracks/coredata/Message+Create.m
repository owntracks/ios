//
//  Message+Create.m
//  OwnTracks
//
//  Created by Christoph Krey on 10.02.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "Message+Create.h"

@implementation Message (Create)

+ (Message *)existsMessageWithMid:(UInt16)mid
           inManagedObjectContext:(NSManagedObjectContext *)context {
    Message *message = nil;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Message"];
    request.predicate = [NSPredicate predicateWithFormat:@"mid = %u", mid];
    
    NSError *error = nil;
    
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (!matches) {
        // handle error
    } else {
        if ([matches count]) {
            message = [matches lastObject];
        }
    }
    
    return message;
}

+ (Message *)messageWithMid:(UInt16)mid
                  timestamp:(NSDate *)timestamp
                       data:(NSData *)data
                      topic:(NSString *)topic
                        qos:(MQTTQosLevel)qos
                   retained:(BOOL)retained
     inManagedObjectContext:(NSManagedObjectContext *)context {
    Message *message = [Message existsMessageWithMid:mid inManagedObjectContext:context];
    
    if (!message) {
        message = [NSEntityDescription insertNewObjectForEntityForName:@"Message" inManagedObjectContext:context];
    }
    message.mid = @(mid);
    message.timestamp = timestamp;
    message.data = data;
    message.topic = topic;
    message.qos = @(qos);
    message.retained = @(retained);
    
    return message;
}

+ (NSArray *)allMessagesInManagedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Message"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
    
    NSError *error = nil;
    
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    return matches;
}

+ (void)clearAllMessagesInManagedObjectContext:(NSManagedObjectContext *)context {
    NSArray *allMessages = [Message allMessagesInManagedObjectContext:context];
    for (Message *message in allMessages) {
        [context deleteObject:message];
    }
    NSError *error = nil;
    if (![context save:&error]) {
        NSString *message = [NSString stringWithFormat:@"%@", error.localizedDescription];
        NSLog(@"managedObjectContext save error: %@", message);
    }
}

@end
