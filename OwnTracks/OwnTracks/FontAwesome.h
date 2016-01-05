//
//  FontAwesome.h
//  OwnTracks
//
//  Created by Christoph Krey on 12.08.15.
//  Copyright © 2015-2016 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FontAwesome : NSObject
+ (NSDictionary *)names;
+ (NSString *)codeFromName:(NSString *)name;

@end
