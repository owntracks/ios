//
//  Message+Create.h
//  OwnTracks
//
//  Created by Christoph Krey on 10.02.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "Message.h"
#import <MQTTClient/MQTTClient.h>

@interface Message (Create)

+ (Message *)messageWithMid:(UInt16)mid
                  timestamp:(NSDate *)timestamp
                       data:(NSData *)data
                      topic:(NSString *)topic
                        qos:(MQTTQosLevel)qos
                   retained:(BOOL)retained
     inManagedObjectContext:(NSManagedObjectContext *)context;

+ (Message *)existsMessageWithMid:(UInt16)mid
     inManagedObjectContext:(NSManagedObjectContext *)context;

+ (NSArray *)allMessagesInManagedObjectContext:(NSManagedObjectContext *)context;

+ (void)clearAllMessagesInManagedObjectContext:(NSManagedObjectContext *)context;
@end
