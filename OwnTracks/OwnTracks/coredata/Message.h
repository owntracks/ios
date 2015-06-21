//
//  Message.h
//  OwnTracks
//
//  Created by Christoph Krey on 22.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Message : NSManagedObject

@property (nonatomic, retain) NSString * channel;
@property (nonatomic, retain) NSString * desc;
@property (nonatomic, retain) NSNumber * distance;
@property (nonatomic, retain) NSDate * expiry;
@property (nonatomic, retain) NSString * geohash;
@property (nonatomic, retain) NSString * iconurl;
@property (nonatomic, retain) NSNumber * latitude;
@property (nonatomic, retain) NSNumber * longitude;
@property (nonatomic, retain) NSDate * timestamp;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * topic;
@property (nonatomic, retain) NSString * url;

@end
