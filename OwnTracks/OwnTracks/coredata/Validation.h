//
//  Validation.h
//  OwnTracks
//
//  Created by Christoph Krey on 13.11.23.
//  Copyright © 2023 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Validation : NSObject
+ (Validation *)sharedInstance;
- (id)validateData:(NSData *)data;
- (id)validateArrayData:(NSData *)data;
- (id)validateEncryptedData:(NSData *)data;
- (BOOL)validateJson:(id)json;

@end

NS_ASSUME_NONNULL_END
