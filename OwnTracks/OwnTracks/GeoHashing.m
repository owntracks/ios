//
//  GeoHashing.m
//  OwnTracks
//
//  Created by Christoph Krey on 05.12.16.
//  Copyright © 2016-2017 OwnTracks. All rights reserved.
//

#import "GeoHashing.h"
#import "OwnTracksAppDelegate.h"
#import "Friend+CoreDataClass.h"
#import "CoreData.h"
#import "Subscription+CoreDataClass.h"
#import "Info+CoreDataClass.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface GeoHashing()
@property (strong, nonatomic) NSString *geoHash;
@end


@implementation Area
- (void)setCoordinate:(CLLocationCoordinate2D)coordinate {
    //
}


- (CLLocationCoordinate2D)coordinate {
    GHArea *a = [GeoHash areaForHash:self.geoHash];
    CLLocationCoordinate2D coordinate =
    CLLocationCoordinate2DMake(
                               (a.latitude.min).doubleValue,
                               (a.longitude.min).doubleValue
                               );
    return coordinate;
}

- (MKPolygon *)polygon {
    GHArea *a = [GeoHash areaForHash:self.geoHash];
    CLLocationCoordinate2D coordinates[4];
    coordinates[0] =
    CLLocationCoordinate2DMake(
                               (a.latitude.min).doubleValue,
                               (a.longitude.min).doubleValue
                               );
    coordinates[1] =
    CLLocationCoordinate2DMake(
                               (a.latitude.min).doubleValue,
                               (a.longitude.max).doubleValue
                               );
    coordinates[2] =
    CLLocationCoordinate2DMake(
                               (a.latitude.max).doubleValue,
                               (a.longitude.max).doubleValue
                               );
    coordinates[3] =
    CLLocationCoordinate2DMake(
                               (a.latitude.max).doubleValue,
                               (a.longitude.min).doubleValue
                               );


    MKPolygon *p = [MKPolygon polygonWithCoordinates:coordinates count:4];
    return p;
}

- (MKMapRect)boundingMapRect {
    GHArea *a = [GeoHash areaForHash:self.geoHash];
    CLLocationCoordinate2D coordinateMin =
    CLLocationCoordinate2DMake(
                               (a.latitude.min).doubleValue,
                               (a.longitude.min).doubleValue
                               );
    CLLocationCoordinate2D coordinateMax =
    CLLocationCoordinate2DMake(
                               (a.latitude.max).doubleValue,
                               (a.longitude.max).doubleValue
                               );

    MKMapPoint min = MKMapPointForCoordinate(coordinateMin);
    MKMapPoint max = MKMapPointForCoordinate(coordinateMax);

    MKMapRect r = MKMapRectMake(min.x, min.y, max.x - min.x, min.y - max.y);
    return r;
}
@end

@implementation Neighbors
@end

@implementation GeoHashing
static const DDLogLevel ddLogLevel = DDLogLevelWarning;

+ (instancetype)sharedInstance {
    static dispatch_once_t once = 0;
    static id sharedInstance = nil;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];

#ifdef GEOHASHING

    Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopic]
                            inManagedObjectContext:[CoreData theManagedObjectContext]];

    if (!myself.hasSubscriptions.count) {
        [self addSubscriptionFor:myself name:@"luftinfo" level:6 context:myself.managedObjectContext];
    } else {
        for (Subscription *subscription in myself.hasSubscriptions) {
            subscription.level = [NSNumber numberWithInteger:6];
        }
    }
    for (Subscription *subscription in myself.hasSubscriptions) {
        DDLogInfo(@"subscription %@, %@",subscription.name, subscription.level);
    }

    [CoreData saveContext:myself.managedObjectContext];

#endif

    self.geoHash = [Settings stringForKey:@"geoHash"];

    self.neighbors = [[Neighbors alloc] init];
    self.neighbors.center = [[Area alloc] init];
    self.neighbors.west = [[Area alloc] init];
    self.neighbors.northWest = [[Area alloc] init];
    self.neighbors.north = [[Area alloc] init];
    self.neighbors.northEast = [[Area alloc] init];
    self.neighbors.east = [[Area alloc] init];
    self.neighbors.southEast = [[Area alloc] init];
    self.neighbors.south = [[Area alloc] init];
    self.neighbors.southWest = [[Area alloc] init];

    if (!self.geoHash) {
        [self newLocation:[[CLLocation alloc] initWithLatitude:0 longitude:0]];
    }

    return self;
}

- (BOOL)processMessage:(NSString *)topic
                  data:(NSData *)data
              retained:(BOOL)retained
               context:(NSManagedObjectContext *)context {

    NSError *error;
    NSDictionary *dictionary;
    NSArray <NSString *> *topicComponents;

    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (json && [json isKindOfClass:[NSDictionary class]]) {
        dictionary = json;
        topicComponents = [topic componentsSeparatedByString:@"/"];
        if (topicComponents.count == 4  && [topicComponents[0] isEqualToString:@"geohash"]) {
            DDLogVerbose(@"[GeoHashing] processMessage %@ %@", topic, dictionary);
        }
    } else {
        DDLogError(@"illegal json %@, %@ %@)", error.localizedDescription, error.userInfo, data.description);
    }

    [context performBlock:^{
        Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopic]
                                inManagedObjectContext:context];
        for (Subscription *subscription in myself.hasSubscriptions) {
            if ([subscription.name isEqualToString:topicComponents[1]]) {
                NSData *imageData;
                id imageString = dictionary[@"image"];
                if (imageString && [imageString isKindOfClass:[NSString class]]) {
                    imageData = [[NSData alloc] initWithBase64EncodedString:imageString options:0];
                }

                [self addInfoFor:subscription
                      identifier:topicComponents[3]
                         geohash:topicComponents[2]
                             tst:[NSDate dateWithTimeIntervalSince1970:[dictionary[@"tst"] doubleValue]]
                             lat:[dictionary[@"lat"] floatValue]
                             lon:[dictionary[@"lon"] floatValue]
                            size:[dictionary[@"size"] floatValue]
                            hand:[dictionary[@"hand"] floatValue]
                           level:[dictionary[@"level"] floatValue]
                     circleStart:[dictionary[@"circleStart"] floatValue]
                       circleEnd:[dictionary[@"circleEnd"] floatValue]
                       ringColor:[dictionary[@"ringColor"] intValue]
                            name:dictionary[@"name"]
                             tid:dictionary[@"tid"]
                           image:imageData
                         context:context];
                [CoreData saveContext:context];
            }
        }
    }];
    return true;
}

- (void)newLocation:(CLLocation *)location {
#ifdef GEOHASHING
    NSString *geoHash;
    geoHash = [GeoHash hashForLatitude:location.coordinate.latitude
                             longitude:location.coordinate.longitude
                                length:6];

    OwnTracksAppDelegate *appDelegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopic]
                            inManagedObjectContext:[CoreData theManagedObjectContext]];
    for (Subscription *subscription in myself.hasSubscriptions) {
        int precision = [subscription.level intValue];
        geoHash = [GeoHash hashForLatitude:location.coordinate.latitude
                                 longitude:location.coordinate.longitude
                                    length:precision];
        GHNeighbors *newNeighbors = [GeoHash neighborsForHash:geoHash];
        NSMutableArray <NSString *> *newGeoHashes = [[NSMutableArray alloc] init];
        [newGeoHashes addObject:newNeighbors.west];
        [newGeoHashes addObject:newNeighbors.northWest];
        [newGeoHashes addObject:newNeighbors.north];
        [newGeoHashes addObject:newNeighbors.northEast];
        [newGeoHashes addObject:newNeighbors.east];
        [newGeoHashes addObject:newNeighbors.southEast];
        [newGeoHashes addObject:newNeighbors.south];
        [newGeoHashes addObject:newNeighbors.southWest];
        [newGeoHashes addObject:geoHash];
        NSMutableArray <NSString *> *oldGeoHashes = [[NSMutableArray alloc] init];
        if (self.geoHash) {
            GHNeighbors *oldNeighbors = [GeoHash neighborsForHash:self.geoHash];
            [oldGeoHashes addObject:oldNeighbors.west];
            [oldGeoHashes addObject:oldNeighbors.northWest];
            [oldGeoHashes addObject:oldNeighbors.north];
            [oldGeoHashes addObject:oldNeighbors.northEast];
            [oldGeoHashes addObject:oldNeighbors.east];
            [oldGeoHashes addObject:oldNeighbors.southEast];
            [oldGeoHashes addObject:oldNeighbors.south];
            [oldGeoHashes addObject:oldNeighbors.southWest];
            [oldGeoHashes addObject:self.geoHash];

            for (NSString *oldGeoHash in oldGeoHashes) {
                BOOL remove = TRUE;
                for (NSString *newGeoHash in newGeoHashes) {
                    if ([oldGeoHash isEqualToString:newGeoHash]) {
                        remove = false;
                        break;
                    }
                }
                if (remove) {
                    NSString *oldTopicFilter = [NSString stringWithFormat:@"geohash/%@/%@/#",
                                                subscription.name,
                                                oldGeoHash];
                    [appDelegate.connection removeExtraSubscription:oldTopicFilter];
                }
            }
        }

        for (NSString *newGeoHash in newGeoHashes) {
            BOOL insert = TRUE;
            for (NSString *oldGeoHash in oldGeoHashes) {
                if ([newGeoHash isEqualToString:oldGeoHash]) {
                    insert = false;
                    break;
                }
            }
            if (insert) {
                NSString *newTopicFilter = [NSString stringWithFormat:@"geohash/%@/%@/#",
                                            subscription.name,
                                            newGeoHash];
                [appDelegate.connection addExtraSubscription:newTopicFilter qos:MQTTQosLevelExactlyOnce];
            }
        }

        NSMutableArray <Info *> *infosToDelete = [[NSMutableArray alloc] init];
        for (Info *info in subscription.hasInfos) {
            BOOL delete = TRUE;
            for (NSString *newGeoHash in newGeoHashes) {
                if ([info.geohash isEqualToString:newGeoHash]) {
                    delete = FALSE;
                    break;
                }
            }
            if (delete) {
                [infosToDelete addObject:info];
            }
        }
        for (Info *info in infosToDelete) {
            [info.managedObjectContext deleteObject:info];
        }
    }

    self.geoHash = geoHash;
    [Settings setString:self.geoHash forKey:@"geoHash"];
    self.neighbors.center.geoHash = geoHash;
    self.neighbors.center.coordinate = CLLocationCoordinate2DMake(0, 0);
    if (self.geoHash) {
        GHNeighbors *neighbors = [GeoHash neighborsForHash:self.geoHash];
        self.neighbors.west.geoHash = neighbors.west;
        self.neighbors.west.coordinate = CLLocationCoordinate2DMake(0, 0);
        self.neighbors.northWest.geoHash = neighbors.northWest;
        self.neighbors.northWest.coordinate = CLLocationCoordinate2DMake(0, 0);
        self.neighbors.north.geoHash = neighbors.north;
        self.neighbors.north.coordinate = CLLocationCoordinate2DMake(0, 0);
        self.neighbors.northEast.geoHash = neighbors.northEast;
        self.neighbors.northEast.coordinate = CLLocationCoordinate2DMake(0, 0);
        self.neighbors.east.geoHash = neighbors.east;
        self.neighbors.east.coordinate = CLLocationCoordinate2DMake(0, 0);
        self.neighbors.southEast.geoHash = neighbors.southEast;
        self.neighbors.southEast.coordinate = CLLocationCoordinate2DMake(0, 0);
        self.neighbors.south.geoHash = neighbors.south;
        self.neighbors.south.coordinate = CLLocationCoordinate2DMake(0, 0);
        self.neighbors.southWest.geoHash = neighbors.southWest;
        self.neighbors.southWest.coordinate = CLLocationCoordinate2DMake(0, 0);
    }
    [CoreData saveContext];
#endif
}

- (Subscription *)addSubscriptionFor:(Friend *)friend
                                name:(NSString *)name
                               level:(int)level
                             context:(NSManagedObjectContext *)context {
    Subscription *subscription = [NSEntityDescription insertNewObjectForEntityForName:@"Subscription"
                                                               inManagedObjectContext:context];
    subscription.belongsTo = friend;
    subscription.name = name;
    subscription.level = @(level);
    return subscription;
}

- (void)removeSubscription:(Subscription *)subscription context:(NSManagedObjectContext *)context {
    [context deleteObject:subscription];
}

- (Info *)addInfoFor:(Subscription *)subscription
          identifier:(NSString *)identifier
             geohash:(NSString *)geohash
                 tst:(NSDate *)tst
                 lat:(float)lat
                 lon:(float)lon
                size:(float)size
                hand:(float)hand
               level:(float)level
         circleStart:(float)circleStart
           circleEnd:(float)circleEnd
           ringColor:(int32_t)ringColor
                name:(NSString *)name
                 tid:(NSString *)tid
               image:(NSData *)image
             context:(NSManagedObjectContext *)context {

    Info *info = nil;

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Info"];
    request.predicate = [NSPredicate predicateWithFormat:@"geohash = %@ and identifier = %@", geohash, identifier];

    NSError *error = nil;

    NSArray *matches = [context executeFetchRequest:request error:&error];

    if (!matches) {
        // handle error
    } else {
        if (matches.count) {
            info = matches.lastObject;
        } else {
            info = [NSEntityDescription insertNewObjectForEntityForName:@"Info"
                                                 inManagedObjectContext:context];
        }
    }

    info.belongsTo = subscription;
    info.identifier = identifier;
    info.name = name;
    info.geohash = geohash;
    info.tst = tst;
    info.tid = tid;
    info.image = image;
    info.ringColor = @(ringColor);
    info.lat = @(lat);
    info.lon = @(lon);
    info.size = @(size);
    info.hand = @(hand);
    info.level = @(level);
    info.circleStart = @(circleStart);
    info.circleEnd = @(circleEnd);
    return info;
}

- (void)removeInfo:(Info *)info context:(NSManagedObjectContext *)context {
    [context deleteObject:info];
}

@end
