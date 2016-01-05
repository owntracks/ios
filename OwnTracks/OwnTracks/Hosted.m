//
//  Hosted.m
//  OwnTracks
//
//  Created by Christoph Krey on 02.01.16.
//  Copyright © 2016 OwnTracks. All rights reserved.
//

#import "Hosted.h"
#import <CocoaLumberjack/CocoaLumberJack.h>
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;

@interface Hosted()
@property (strong, nonatomic) NSURLSessionDownloadTask *downloadTask;
@property (strong, nonatomic) NSURLSession *urlSession;

@property (strong, nonatomic) NSString *username;
@property (strong, nonatomic) NSString *password;
@property (strong, nonatomic) NSString *refreshToken;
@property (strong, nonatomic) NSString *accessToken;
@end

@implementation Hosted

- (void)authenticate:(NSString *)username
            password:(NSString *)password
     completionBlock:(void (^)(NSInteger, NSString *))completionBlock {
    
    if ([username isEqualToString:self.username] && [password isEqualToString:self.password] && self.refreshToken) {
        completionBlock(200, self.refreshToken);
        return;
    }
    
    NSDictionary *jsonIn = @{@"username": username,
                             @"password": password
                             };
    [self hostedAPI:@"authenticate"
              token:nil
               type:@"POST"
             jsonIn:jsonIn
    completionBlock:^(NSInteger status, id data) {
        NSString *refreshToken;
        if (status == 200) {
            if (data && [data isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dictionary = data;
                refreshToken = [dictionary valueForKey:@"refreshToken"];
                self.refreshToken = refreshToken;
                self.username = username;
                self.password = password;
            }
        } else {
            DDLogWarn(@"refeshToken status %ld", (long)status);
        }
     completionBlock(status, refreshToken);
     }];
}

- (void)accessToken:(NSString *)refreshToken
    completionBlock:(void (^)(NSInteger, NSString *))completionBlock {
    
    if ([refreshToken isEqualToString:self.refreshToken] && self.accessToken) {
        completionBlock(200, self.accessToken);
        return;
    }

    NSDictionary *jsonIn = @{};
    [self hostedAPI:@"authenticate/refresh"
              token:refreshToken
               type:@"POST"
             jsonIn:jsonIn
    completionBlock:^(NSInteger status, id data) {
        NSString *accessToken;
        if (status == 200) {
            if (data && [data isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dictionary = data;
                accessToken = [dictionary valueForKey:@"accessToken"];
                self.accessToken = accessToken;
                self.refreshToken = refreshToken;
            }
        } else {
            DDLogWarn(@"accessToken status %ld", (long)status);
        }
        completionBlock(status, accessToken);
    }];
}

- (void)listUsers:(NSString *)accessToken
  completionBlock:(void (^)(NSInteger, NSArray *))completionBlock {
    [self hostedAPI:@"users"
              token:accessToken
               type:@"GET"
             jsonIn:nil
    completionBlock:^(NSInteger status, id data) {
        NSArray *users;
        if (status == 200) {
            if (data && [data isKindOfClass:[NSArray class]]) {
                users = data;
            }
        } else {
            DDLogWarn(@"listUsers status %ld", (long)status);
        }
        completionBlock(status, users);
    }];
}

-(void)createUser:(NSString *)username
         password:(NSString *)password
         fullname:(NSString *)fullname
            email:(NSString *)email
  completionBlock:(void (^)(NSInteger, NSDictionary *))completionBlock {
    NSDictionary *jsonIn = @{@"username": username,
                             @"password": password,
                             @"fullname": fullname,
                             @"email": email
                             };
    [self hostedAPI:@"users"
              token:nil
               type:@"POST"
             jsonIn:jsonIn
    completionBlock:^(NSInteger status, id data) {
        NSDictionary *user;
        if (status == 201) {
            if (data && [data isKindOfClass:[NSDictionary class]]) {
                user = data;
            }
        } else {
            DDLogWarn(@"createUser status %ld", (long)status);
        }
        completionBlock(status, user);
    }];
}

- (void)editUser:(NSString *)accessToken
          userId:(NSInteger)userId
        username:(NSString *)username
        password:(NSString *)password
        fullname:(NSString *)fullname
           email:(NSString *)email
 completionBlock:(void (^)(NSInteger, NSDictionary *))completionBlock {
    completionBlock(0, nil);
}

- (void)retrieveUser:(NSString *)accessToken
              userId:(NSInteger)userId
     completionBlock:(void (^)(NSInteger, NSDictionary *))completionBlock {
    NSString *method = [NSString stringWithFormat:@"users/%ld", (long)userId];
    [self hostedAPI:method
              token:accessToken
               type:@"GET"
             jsonIn:nil
    completionBlock:^(NSInteger status, id data) {
        NSDictionary *user;
        if (status == 200) {
            if (data && [data isKindOfClass:[NSDictionary class]]) {
                user = data;
            }
        } else {
            DDLogWarn(@"editUser status %ld", (long)status);
        }
        completionBlock(status, user);
    }];
}

-(void)removeUser:(NSString *)accessToken
           userId:(NSInteger)userId
  completionBlock:(void (^)(NSInteger, NSDictionary *))completionBlock {
    completionBlock(0, nil);
}

- (void)listDevices:(NSString *)accessToken
             userId:(NSInteger)userId
    completionBlock:(void (^)(NSInteger, NSArray *))completionBlock {
    NSString *method = [NSString stringWithFormat:@"users/%ld/devices", (long)userId];
    [self hostedAPI:method
              token:accessToken
               type:@"GET"
             jsonIn:nil
    completionBlock:^(NSInteger status, id data) {
        NSArray *devices;
        if (status == 200) {
            if (data && [data isKindOfClass:[NSArray class]]) {
                devices = data;
            }
        } else {
            DDLogWarn(@"listDevices status %ld", (long)status);
        }
        completionBlock(status, devices);
    }];
}

- (void)createDevice:(NSString *)accessToken
          devicename:(NSString *)devicename
              userId:(NSInteger)userId
     completionBlock:(void (^)(NSInteger, NSDictionary *))completionBlock {
    NSDictionary *jsonIn = @{@"devicename": devicename
                             };
    NSString *method = [NSString stringWithFormat:@"users/%ld/devices", (long)userId];

    [self hostedAPI:method
              token:accessToken
               type:@"POST"
             jsonIn:jsonIn
    completionBlock:^(NSInteger status, id data) {
        NSDictionary *user;
        if (status == 201) {
            if (data && [data isKindOfClass:[NSDictionary class]]) {
                user = data;
            }
        } else {
            DDLogWarn(@"createDevice status %ld", (long)status);
        }
        completionBlock(status, user);
    }];
}

- (void)retrieveDevice:(NSString *)accessToken
                userId:(NSInteger)userId
              deviceId:(NSInteger)deviceId
       completionBlock:(void (^)(NSInteger, NSDictionary *))completionBlock {
    NSString *method = [NSString stringWithFormat:@"users/%ld/devices/%ld", (long)userId, (long)deviceId];
    [self hostedAPI:method
              token:accessToken
               type:@"GET"
             jsonIn:nil
    completionBlock:^(NSInteger status, id data) {
        NSDictionary *device;
        if (status == 201) {
            if (data && [data isKindOfClass:[NSDictionary class]]) {
                device = data;
            }
        } else {
            DDLogWarn(@"retrieveDevice status %ld", (long)status);
        }
        completionBlock(status, device);
    }];
}

- (void)obtainNewDeviceCredentials:(NSString *)accessToken
                            userId:(NSInteger)userId
                          deviceId:(NSInteger)deviceId
                   completionBlock:(void (^)(NSInteger, NSDictionary *))completionBlock {
    completionBlock(0, nil);
}

- (void)removeDevice:(NSString *)accessToken
              userId:(NSInteger)userId
            deviceId:(NSInteger)deviceId
     completionBlock:(void (^)(NSInteger, NSDictionary *))completionBlock {
    completionBlock(0, nil);
}

- (void)createShare:(NSInteger)otherUserId
             userId:(NSInteger)userId
           deviceId:(NSInteger)deviceId
    completionBlock:(void (^)(NSInteger, NSDictionary *))completionBlock {
    completionBlock(0, nil);
}

- (void)listShares:(NSString *)accessToken
            userId:(NSInteger)userId
   completionBlock:(void (^)(NSInteger, NSArray *))completionBlock {
    completionBlock(0, nil);
}
- (void)retrieveShare:(NSString *)accessToken
               userId:(NSInteger)userId
              shareId:(NSInteger)shareId
      completionBlock:(void (^)(NSInteger, NSDictionary *))completionBlock {
    completionBlock(0, nil);
}

- (void)removeShare:(NSString *)accessToken
             userId:(NSInteger)userId
            shareId:(NSInteger)shareId
    completionBlock:(void (^)(NSInteger, NSDictionary *))completionBlock {
    completionBlock(0, nil);
}

- (void)hostedAPI:(NSString *)method
            token:(NSString *)token
            type:(NSString *)type
           jsonIn:(NSDictionary *)jsonIn
  completionBlock:(void (^)(NSInteger, id))completionBlock {

    if (self.downloadTask) {
        [self.downloadTask cancel];
    }
    
    NSData *postData = [[NSData alloc] init];
    if (jsonIn) {
        NSError *error;
        postData = [NSJSONSerialization dataWithJSONObject:jsonIn options:0 error:&error];
    }
    
    NSString *postLength = [NSString stringWithFormat:@"%ld",(unsigned long)[postData length]];
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] init];
    
    NSString *urlString = [NSString stringWithFormat:@"https://hosted-dev.owntracks.org/api/v1/%@", method];
    [urlRequest setURL:[NSURL URLWithString:urlString]];
    
    [urlRequest setHTTPMethod:type];
    [urlRequest setValue:postLength forHTTPHeaderField:@"Content-Length"];
    if (token) {
        NSString *authHeader = [NSString stringWithFormat:@"Bearer %@", token];
        [urlRequest setValue:authHeader forHTTPHeaderField:@"Authorization"];
    }
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [urlRequest setValue:@"mobile" forHTTPHeaderField:@"clientType"];
    [urlRequest setHTTPBody:postData];
    
    DDLogInfo(@"downloadTaskWithRequest\n%@ %@\n%@\n%@",
                 urlRequest.HTTPMethod,
                 urlRequest.URL,
                 urlRequest.allHTTPHeaderFields,
                 [[NSString alloc] initWithData:urlRequest.HTTPBody encoding:NSUTF8StringEncoding]);

    self.urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    self.downloadTask = [self.urlSession downloadTaskWithRequest:urlRequest
                                               completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
                                                   DDLogVerbose(@"downloadTaskWithRequest completionhandler\n%@\n%@\n%@",
                                                         location, response, error);
                                                   NSData *downloadedData = [NSData dataWithContentsOfURL:location];
                                                   NSNumber *status;
                                                   NSDictionary *data;
                                                   if (downloadedData) {
                                                       NSError *error;
                                                       NSDictionary *jsonOut = [NSJSONSerialization
                                                                                JSONObjectWithData:downloadedData
                                                                                options:0
                                                                                error:&error];
                                                       if (jsonOut) {
                                                           status = [jsonOut valueForKey:@"status"];
                                                           data = [jsonOut valueForKey:@"data"];
                                                           if (status && data) {
                                                               DDLogVerbose(@"hostAPI %@ %@", status, data);
                                                           } else {
                                                               DDLogWarn(@"no status or data %@", jsonOut);
                                                           }
                                                       } else {
                                                           DDLogError(@"NSJSONSerialization error %@ %@", error.localizedDescription, downloadedData.description);
                                                       }
                                                   } else {
                                                       DDLogError(@"downLoadTaskWithRequest no data");
                                                   }
                                                   completionBlock([status integerValue], data);
                                               }];

    [self.downloadTask resume];
}

+ (NSDictionary *)decode:(NSString *)jwt {
    DDLogVerbose(@"jwt %@", jwt);

    NSArray *segments = [jwt componentsSeparatedByString:@"."];
    NSString *base64String = [segments objectAtIndex: 1];
    DDLogVerbose(@"base64String %@", base64String);
    
    unsigned long requiredLength = (int)(4 * ceil((float)base64String.length / 4.0));
    unsigned long nbrPaddings = requiredLength - base64String.length;
    
    if (nbrPaddings > 0) {
        NSString *padding = [[NSString string] stringByPaddingToLength:nbrPaddings withString:@"=" startingAtIndex:0];
        base64String = [base64String stringByAppendingString:padding];
    }
    DDLogVerbose(@"padded base64String %@", base64String);
    
    base64String = [base64String stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"_" withString:@"/"];

    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
    NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
    DDLogVerbose(@"decodedString %@", decodedString);

    NSDictionary *jsonDictionary =
    [NSJSONSerialization JSONObjectWithData:[decodedString
                                             dataUsingEncoding:NSUTF8StringEncoding]
                                    options:0 error:nil];
    DDLogVerbose(@"jsonDictionary %@", jsonDictionary);
    return jsonDictionary;
}

@end
