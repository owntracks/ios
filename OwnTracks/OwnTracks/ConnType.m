//
//  ConnType.m
//  OwnTracks
//
//  Created by Christoph Krey on 05.10.16.
//  Copyright © 2016-2024  OwnTracks. All rights reserved.
//

#import "ConnType.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <SystemConfiguration/CaptiveNetwork.h>

@implementation ConnType

+ (NSString *)SSID {
    NSString *ssid;

    CFArrayRef siRef = CNCopySupportedInterfaces();
    if (siRef != NULL) {
        CFDictionaryRef niRef = CNCopyCurrentNetworkInfo(CFArrayGetValueAtIndex(siRef, 0));
        if (niRef != NULL) {
            CFStringRef ssidRef = CFDictionaryGetValue(niRef, kCNNetworkInfoKeySSID);
            if (ssidRef != NULL) {
                ssid = (__bridge NSString *)ssidRef;
            }
            CFRelease(niRef);
        }
        CFRelease(siRef);
    }
    return ssid;
}

+ (NSString *)BSSID {
    NSString *bssid;

    CFArrayRef siRef = CNCopySupportedInterfaces();
    if (siRef != NULL) {
        CFDictionaryRef niRef = CNCopyCurrentNetworkInfo(CFArrayGetValueAtIndex(siRef, 0));
        if (niRef != NULL) {
            CFStringRef bssidRef = CFDictionaryGetValue(niRef, kCNNetworkInfoKeyBSSID);
            if (bssidRef != NULL) {
                bssid = (__bridge NSString *)(bssidRef);
            }
            CFRelease(niRef);
        }
        CFRelease(siRef);
    }
    return bssid;
}

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
