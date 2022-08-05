//
//  Shares.h
//  OwnTracks
//
//  Created by Christoph Krey on 02.08.22.
//  Copyright © 2022 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface Share: NSObject
@property (strong, nonatomic) NSString *label;
@property (strong, nonatomic) NSString *uuid;
@property (strong, nonatomic) NSString *url;
@property (strong, nonatomic) NSDate *from;
@property (strong, nonatomic) NSDate *to;

- (instancetype)initFromDictionary:(nullable NSDictionary *)dictionary;
- (NSDictionary *)asDictionary;
- (NSComparisonResult)compare:(Share *)share;
@end

@interface Shares : NSObject
@property (strong, nonatomic, nullable) NSMutableDictionary *response;
@property (strong, nonatomic) NSDate *timestamp;
@property (strong, nonatomic) NSString *message;
@property (strong, nonatomic) NSNumber *activity;

+ (Shares *)sharedInstance;
- (void)refresh;
- (NSInteger)count;
- (nullable Share *)shareAtIndex:(NSInteger)index;
- (void)requestShare:(nonnull Share *)share;
- (void)addShare:(nonnull Share *)share;
- (BOOL)removeShareAtIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
