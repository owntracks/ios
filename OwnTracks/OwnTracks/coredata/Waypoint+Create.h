//
//  Waypoint+Create.h
//  OwnTracks
//
//  Created by Christoph Krey on 29.06.15.
//  Copyright © 2015-2016 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Waypoint+CoreDataProperties.h"

@interface Waypoint (Create)
- (void) getReverseGeoCode;
- (NSString *)coordinateText;
- (NSString *)timestampText;
- (NSString *)infoText;

@end
