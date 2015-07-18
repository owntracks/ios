//
//  Message.h
//  OwnTracks
//
//  Created by Christoph Krey on 18.07.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Message : NSManagedObject

@property (nonatomic, retain) NSString * channel;
@property (nonatomic, retain) NSString * desc;
@property (nonatomic, retain) NSString * geohash;
@property (nonatomic, retain) NSString * icon;
@property (nonatomic, retain) NSString * iconurl;
@property (nonatomic, retain) NSNumber * prio;
@property (nonatomic, retain) NSDate * timestamp;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * topic;
@property (nonatomic, retain) NSNumber * ttl;
@property (nonatomic, retain) NSString * url;

@end
