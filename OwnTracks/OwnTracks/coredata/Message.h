//
//  Message.h
//  OwnTracks
//
//  Created by Christoph Krey on 10.02.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Message : NSManagedObject

@property (nonatomic, retain) NSData * data;
@property (nonatomic, retain) NSString * topic;
@property (nonatomic, retain) NSNumber * qos;
@property (nonatomic, retain) NSNumber * retained;
@property (nonatomic, retain) NSNumber * mid;
@property (nonatomic, retain) NSDate * timestamp;

@end
