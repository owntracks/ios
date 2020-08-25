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

#import <CocoaLumberjack/CLIColor.h>
#import <CocoaLumberjack/DDAbstractDatabaseLogger.h>
#import <CocoaLumberjack/DDASLLogCapture.h>
#import <CocoaLumberjack/DDASLLogger.h>
#import <CocoaLumberjack/DDAssertMacros.h>
#import <CocoaLumberjack/DDContextFilterLogFormatter.h>
#import <CocoaLumberjack/DDDispatchQueueLogFormatter.h>
#import <CocoaLumberjack/DDFileLogger+Buffering.h>
#import <CocoaLumberjack/DDFileLogger.h>
#import <CocoaLumberjack/DDLog+LOGV.h>
#import <CocoaLumberjack/DDLog.h>
#import <CocoaLumberjack/DDLoggerNames.h>
#import <CocoaLumberjack/DDLogMacros.h>
#import <CocoaLumberjack/DDMultiFormatter.h>
#import <CocoaLumberjack/DDOSLogger.h>
#import <CocoaLumberjack/DDTTYLogger.h>
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <CocoaLumberjack/DDLegacyMacros.h>

FOUNDATION_EXPORT double CocoaLumberjackVersionNumber;
FOUNDATION_EXPORT const unsigned char CocoaLumberjackVersionString[];

