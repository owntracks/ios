//
//  InterfaceController.m
//  OwnTracks WatchKit Extension
//
//  Created by Christoph Krey on 02.04.15.
//  Copyright © 2015-2017 OwnTracks. All rights reserved.
//

#import "InterfaceController.h"
#import "SharedFriendsRC.h"

@interface InterfaceController()
@property (strong, nonatomic) NSDictionary *sharedFriends;
@property (strong, nonatomic) NSMutableDictionary *places;
@property (nonatomic) int mode;
@property (weak, nonatomic) IBOutlet WKInterfaceTable *table;

@end

@implementation InterfaceController

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    
    // Configure interface objects here.
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:@"group.org.owntracks.Owntracks"];
    self.sharedFriends = [shared dictionaryForKey:@"sharedFriends"];
    self.places = [[NSMutableDictionary alloc] init];
    NSLog(@"sharedFriends: %@", self.sharedFriends);
    [self show];
}

- (void)show {
    [self.table setRowTypes:@[@"SharedFriendsRC"]];
    [self.table setNumberOfRows:self.sharedFriends.count withRowType:@"SharedFriendsRC"];
    for (NSInteger i = 0; i < self.table.numberOfRows; i++) {
        SharedFriendsRC *row = [self.table rowControllerAtIndex:i];
        NSString *name = [self.sharedFriends allKeys][i];
        NSDictionary *friend = self.sharedFriends[name];

        NSString *info = [self itemText:name];
        
        UIFont *fontBold = [UIFont boldSystemFontOfSize:[UIFont smallSystemFontSize]];
        NSDictionary *attributesBold = @{NSFontAttributeName: fontBold};
        
        UIFont *fontLight = [UIFont systemFontOfSize:[UIFont smallSystemFontSize]];
        NSDictionary *attributesLight = @{NSFontAttributeName: fontLight};
        
        NSMutableAttributedString *as = [[NSMutableAttributedString alloc]
                                         initWithString:name attributes:attributesBold];
        
        [as appendAttributedString:[[NSAttributedString alloc]
                                    initWithString:info attributes:attributesLight]];
        
        [row.label setAttributedText:as];
        [row.image setImage:[UIImage imageWithData:friend[@"image"]]];
    }
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

         - (NSString *)itemText:(NSString *)name {
             NSString *itemText;
             NSDictionary *friend = self.sharedFriends[name];
             
    switch (self.mode) {
        default:
        case 0: {
            double distance = [friend[@"distance"] doubleValue];
            itemText = [NSString stringWithFormat:@"\n%0.f %@",
                        distance / 1000.0,
                        NSLocalizedString(@"km",
                                          @"short for kilometer on Watch")
                        ];
            break;
        }
        case 1: {
            NSDate *timestamp = friend[@"timestamp"];
            NSTimeInterval interval = -[timestamp timeIntervalSinceNow];
            if (interval < 60) {
                itemText = [NSString stringWithFormat:@"\n%0.f %@",
                            interval,
                            NSLocalizedString(@"sec",
                                              @"short for second on Watch")
                            ];

            } else if (interval < 3600) {
                itemText = [NSString stringWithFormat:@"\n%0.f %@",
                            interval / 60,
                            NSLocalizedString(@"min",
                                              @"short for minute on Watch")
                            ];

            } else if (interval < 24 * 3600) {
                itemText = [NSString stringWithFormat:@"\n%0.f %@",
                            interval / 3600,
                            NSLocalizedString(@"h",
                                              @"short for hour on Watch")
                            ];
            } else {
                itemText = [NSString stringWithFormat:@"\n%0.f %@",
                            interval / (24 * 3600),
                            NSLocalizedString(@"d",
                                              @"short for day on Watch")
                            ];
            }
            break;
        }
        case 2:
        case 3:
        case 4: {
            CLPlacemark *placemark = self.places[name];
            if (!placemark) {
                [self.places setObject:[[NSObject alloc] init] forKey:name];

                CLLocation *location = [[CLLocation alloc] initWithLatitude:[friend[@"latitude"] doubleValue]
                                                                  longitude:[friend[@"longitude"] doubleValue]];
                CLGeocoder *geocoder = [[CLGeocoder alloc] init];
                [geocoder reverseGeocodeLocation:location completionHandler:
                 ^(NSArray *placemarks, NSError *error) {
                     if ([placemarks count] > 0) {
                         CLPlacemark *placemark = placemarks[0];
                         NSLog(@"placemark %@", placemark);
                         [self.places setObject:placemark forKeyedSubscript:name];
                     }
                     [self show];
                 }];
            }
            NSString *place;
            switch (self.mode) {
                default:
                case 2:
                    place = [NSString stringWithFormat:@"%@ %@",
                             [placemark isKindOfClass:[CLPlacemark class]] ?
                             placemark.subThoroughfare ? placemark.subThoroughfare : @"-" : @"???",
                             [placemark isKindOfClass:[CLPlacemark class]] ?
                             placemark.thoroughfare ? placemark.thoroughfare : @"-" : @"???"];
                    break;
                case 3:
                    place = [NSString stringWithFormat:@"%@ %@",
                             [placemark isKindOfClass:[CLPlacemark class]] ?
                             placemark.locality ? placemark.locality : @"-" : @"???",
                             [placemark isKindOfClass:[CLPlacemark class]] ?
                             placemark.postalCode ? placemark.postalCode : @"-": @"???"];
                    break;
                case 4:
                    place = [NSString stringWithFormat:@"%@ %@",
                             [placemark isKindOfClass:[CLPlacemark class]] ?
                             placemark.administrativeArea ? placemark.administrativeArea : @"-" : @"???",
                             [placemark isKindOfClass:[CLPlacemark class]] ?
                             placemark.country ? placemark.country : @"-": @"???"];
                    break;
            }

            itemText = [NSString stringWithFormat:@"\n%@", place];
            break;
        }
    }
    return itemText;
}

- (void)table:(WKInterfaceTable *)table didSelectRowAtIndex:(NSInteger)rowIndex {
    self.mode = (self.mode + 1) % 5;
    [self show];
}


@end



