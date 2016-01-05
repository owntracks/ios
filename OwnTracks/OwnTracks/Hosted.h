//
//  Hosted.h
//  OwnTracks
//
//  Created by Christoph Krey on 02.01.16.
//  Copyright © 2016 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Hosted : NSObject

- (void)authenticate:(NSString *)username
            password:(NSString *)password
     completionBlock:(void (^)(NSInteger status, NSString *refreshToken))completionBlock;

- (void)accessToken:(NSString *)refreshToken
    completionBlock:(void (^)(NSInteger status, NSString *accessToken))completionBlock;

- (void)listUsers:(NSString *)accessToken
  completionBlock:(void (^)(NSInteger status, NSArray *users))completionBlock;

- (void)createUser:(NSString *)username
          password:(NSString *)password
          fullname:(NSString *)fullname
             email:(NSString *)email
   completionBlock:(void (^)(NSInteger status, NSDictionary *user))completionBlock;

- (void)retrieveUser:(NSString *)accessToken
              userId:(NSInteger)userId
     completionBlock:(void (^)(NSInteger status, NSDictionary *user))completionBlock;

- (void)editUser:(NSString *)accessToken
          userId:(NSInteger)userId
        username:(NSString *)username
        password:(NSString *)password
        fullname:(NSString *)fullname
           email:(NSString *)email
 completionBlock:(void (^)(NSInteger status, NSDictionary *user))completionBlock;

- (void)removeUser:(NSString *)accessToken
            userId:(NSInteger)userId
   completionBlock:(void (^)(NSInteger status, NSDictionary *user))completionBlock;

- (void)listDevices:(NSString *)accessToken
             userId:(NSInteger)userId
    completionBlock:(void (^)(NSInteger status, NSArray *devices))completionBlock;

- (void)createDevice:(NSString *)accessToken
          devicename:(NSString *)devicename
              userId:(NSInteger)userId
   completionBlock:(void (^)(NSInteger status, NSDictionary *device))completionBlock;

- (void)retrieveDevice:(NSString *)accessToken
                userId:(NSInteger)userId
              deviceId:(NSInteger)deviceId
       completionBlock:(void (^)(NSInteger status, NSDictionary *device))completionBlock;

- (void)obtainNewDeviceCredentials:(NSString *)accessToken
                            userId:(NSInteger)userId
                          deviceId:(NSInteger)deviceId
                   completionBlock:(void (^)(NSInteger status, NSDictionary *device))completionBlock;

- (void)removeDevice:(NSString *)accessToken
              userId:(NSInteger)userId
            deviceId:(NSInteger)deviceId
     completionBlock:(void (^)(NSInteger status, NSDictionary *device))completionBlock;

- (void)listShares:(NSString *)accessToken
             userId:(NSInteger)userId
   completionBlock:(void (^)(NSInteger status, NSArray *shares))completionBlock;

- (void)createShare:(NSInteger)otherUserId
              userId:(NSInteger)userId
           deviceId:(NSInteger)deviceId
     completionBlock:(void (^)(NSInteger status, NSDictionary *device))completionBlock;

- (void)retrieveShare:(NSString *)accessToken
               userId:(NSInteger)userId
              shareId:(NSInteger)shareId
      completionBlock:(void (^)(NSInteger status, NSDictionary *share))completionBlock;

- (void)removeShare:(NSString *)accessToken
             userId:(NSInteger)userId
            shareId:(NSInteger)shareId
    completionBlock:(void (^)(NSInteger status, NSDictionary *share))completionBlock;

+ (NSDictionary *)decode:(NSString *)jwt;

@end
