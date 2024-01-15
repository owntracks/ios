//
//  Validation.h
//  OwnTracks
//
//  Created by Christoph Krey on 13.11.23.
//  Copyright © 2023-2024 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Validation : NSObject
+ (Validation *)sharedInstance;
- (id)validateMessageData:(NSData *)data;
- (id)validateMessagesData:(NSData *)data;
- (id)validateEncryptionData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
