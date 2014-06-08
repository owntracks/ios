//
//  Friend.h
//  OwnTracks
//
//  Created by Christoph Krey on 04.06.14.
//  Copyright (c) 2014 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Location;

@interface Friend : NSManagedObject

@property (nonatomic, retain) NSNumber * abRecordId;
@property (nonatomic, retain) NSString * topic;
@property (nonatomic, retain) NSSet *hasLocations;
@end

@interface Friend (CoreDataGeneratedAccessors)

- (void)addHasLocationsObject:(Location *)value;
- (void)removeHasLocationsObject:(Location *)value;
- (void)addHasLocations:(NSSet *)values;
- (void)removeHasLocations:(NSSet *)values;

@end
