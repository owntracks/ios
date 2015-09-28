//
//  Message+Create.h
//  OwnTracks
//
//  Created by Christoph Krey on 20.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "Message+CoreDataProperties.h"
#import <Foundation/Foundation.h>

@interface Message (Create)

+ (Message *)messageWithTopic:(NSString *)topic
                         icon:(NSString *)icon
                         prio:(NSInteger)prio
                    timestamp:(NSDate *)timestamp
                          ttl:(NSUInteger)ttl
                        title:(NSString *)title
                         desc:(NSString *)desc
                          url:(NSString *)url
                      iconurl:(NSString *)iconurl
       inManagedObjectContext:(NSManagedObjectContext *)context;

+ (NSUInteger)expireMessages:(NSManagedObjectContext *)context;
+ (NSUInteger)removeMessages:(NSManagedObjectContext *)context;
+ (NSUInteger)removeMessages:(NSString *)topic context:(NSManagedObjectContext *)context;

@end
