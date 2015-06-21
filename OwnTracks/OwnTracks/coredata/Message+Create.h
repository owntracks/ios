//
//  Message+Create.h
//  OwnTracks
//
//  Created by Christoph Krey on 20.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "Message.h"
#import <Foundation/Foundation.h>

@interface Message (Create)

+ (Message *)messageWithTopic:(NSString *)topic
                     latitude:(double)latitude
                    longitude:(double)longitude
                    timestamp:(NSDate *)timestamp
                       expiry:(NSDate *)expiry
                        title:(NSString *)title
                         desc:(NSString *)desc
                          url:(NSString *)url
                      iconurl:(NSString *)iconurl
       inManagedObjectContext:(NSManagedObjectContext *)context;

+ (void)expireMessages:(NSManagedObjectContext *)context;
+ (void)removeMessages:(NSManagedObjectContext *)context;
+ (void)removeMessages:(NSString *)topic context:(NSManagedObjectContext *)context;

@end
