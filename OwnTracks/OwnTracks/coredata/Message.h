//
//  Message.h
//  OwnTracks
//
//  Created by Christoph Krey on 20.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Message : NSManagedObject

@property (nonatomic, retain) NSString * topic;
@property (nonatomic, retain) NSDate * timestamp;
@property (nonatomic, retain) NSString * desc;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSDate * expiry;

@end
