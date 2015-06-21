//
//  Message+Create.m
//  OwnTracks
//
//  Created by Christoph Krey on 20.06.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "Message+Create.h"
#import "LocationManager.h"

@implementation Message (Create)

- (NSString *)geohash {
    NSArray *components = [self.topic componentsSeparatedByString:@"/"];
    if (components.count == 3) {
        return components[2];
    } else {
        return nil;
    }
}

- (NSString *)channel {
    NSArray *components = [self.topic componentsSeparatedByString:@"/"];
    if (components.count == 3) {
        return components[1];
    } else {
        return nil;
    }
}

- (NSNumber *)distance {
    CLLocation *here = [LocationManager sharedInstance].location;
    CLLocation *location = [[CLLocation alloc]
                            initWithLatitude:[self.latitude doubleValue]
                            longitude:[self.longitude doubleValue]];
    NSLog(@"%@ %@", here, location);

    CLLocationDistance distance = [here distanceFromLocation:location];
    return [NSNumber numberWithDouble:distance];
}

+ (Message *)messageWithTopic:(NSString *)topic
                     latitude:(double)latitude
                    longitude:(double)longitude
                    timestamp:(NSDate *)timestamp
                       expiry:(NSDate *)expiry
                        title:(NSString *)title
                         desc:(NSString *)desc
                          url:(NSString *)url
                      iconurl:(NSString *)iconurl
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
        message.latitude = [NSNumber numberWithDouble:latitude];
        message.longitude = [NSNumber numberWithDouble:longitude];
        message.timestamp = timestamp;
        message.expiry = expiry;
        message.title = title;
        message.desc = desc;
        message.url = url;
        message.iconurl = iconurl;
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
