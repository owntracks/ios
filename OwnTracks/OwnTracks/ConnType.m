//
//  ConnType.m
//  OwnTracks
//
//  Created by Christoph Krey on 05.10.16.
//  Copyright © 2016 -2019 OwnTracks. All rights reserved.
//

#import "ConnType.h"
#import <SystemConfiguration/SystemConfiguration.h>

@implementation ConnType

+ (ConnectionType)connectionType:(NSString *)host {
    if (!host) {
        return ConnectionTypeUnknown;
    }

    const char *hostCString = [host cStringUsingEncoding:NSASCIIStringEncoding];
    if (hostCString == NULL) {
        return ConnectionTypeUnknown;
    }

    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, hostCString);
    if (reachability == NULL) {
        return ConnectionTypeUnknown;
    }

    SCNetworkReachabilityFlags flags;
    BOOL success = SCNetworkReachabilityGetFlags(reachability, &flags);
    CFRelease(reachability);
    if (!success) {
        return ConnectionTypeUnknown;
    }
    
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    BOOL needsConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    BOOL isNetworkReachable = (isReachable && !needsConnection);

    if (!isNetworkReachable) {
        return ConnectionTypeNone;
    } else if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
        return ConnectionTypeWWAN;
    } else {
        return ConnectionTypeWIFI;
    }
}


@end
