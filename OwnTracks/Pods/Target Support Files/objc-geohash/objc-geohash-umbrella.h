#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "cgeohash.h"
#import "GeoHash.h"
#import "GHArea.h"
#import "GHNeighbors.h"
#import "GHRange.h"

FOUNDATION_EXPORT double objc_geohashVersionNumber;
FOUNDATION_EXPORT const unsigned char objc_geohashVersionString[];

