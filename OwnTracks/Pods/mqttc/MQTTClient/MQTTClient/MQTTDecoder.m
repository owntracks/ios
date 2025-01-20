//
// MQTTDecoder.m
// MQTTClient.framework
//
// Copyright © 2013-2025, Christoph Krey. All rights reserved.
//

#import <mqttc/MQTTDecoder.h>

#import <mqttc/MQTTLog.h>

typedef NS_ENUM(unsigned int, MQTTDecoderState) {
    MQTTDecoderStateInitializing,
    MQTTDecoderStateDecodingHeader,
    MQTTDecoderStateDecodingLength,
    MQTTDecoderStateDecodingData
};

@interface MQTTDecoder()
@property (nonatomic) MQTTDecoderState state;
@property (nonatomic) UInt32 length;
@property (nonatomic) UInt32 lengthMultiplier;
@property (nonatomic) int offset;
@property (strong, nonatomic) NSMutableData *dataBuffer;

@end

@implementation MQTTDecoder

- (instancetype)init {
    self = [super init];
    self.state = MQTTDecoderStateInitializing;
    return self;
}

- (void)dealloc {
    [self close];
}

- (void)decodeMessage:(NSData *)data {
    NSInteger readHere = 0;
    while (self.state != MQTTDecoderStateInitializing &&
           data.length > readHere) {

        if (self.state == MQTTDecoderStateDecodingHeader) {
            if (data.length <= readHere) {
                self.state = MQTTDecoderStateInitializing;
                [self.delegate decoder:self
                           handleEvent:MQTTDecoderEventProtocolError
                                 error:nil];
            }

            UInt8 header;
            DDLogDebug(@"[MQTTDecoder] header getBytes %ld/%lu",
                       (long)readHere, (unsigned long)data.length);
            [data getBytes:&header range:NSMakeRange(readHere, 1)];
            readHere++;

            self.length = 0;
            self.lengthMultiplier = 1;
            self.state = MQTTDecoderStateDecodingLength;
            self.dataBuffer = [[NSMutableData alloc] init];
            [self.dataBuffer appendBytes:&header length:1];
            self.offset = 1;
            DDLogVerbose(@"[MQTTDecoder] fixedHeader=0x%02x", header);
        }

        while (self.state == MQTTDecoderStateDecodingLength) {
            // TODO: check max packet length(prevent evil server response)
            if (data.length <= readHere) {
                break;
            }

            UInt8 digit;
                DDLogDebug(@"[MQTTDecoder] length getBytes %ld/%lu",
                           (long)readHere, (unsigned long)data.length);
            [data getBytes:&digit range:NSMakeRange(readHere, 1)];
            readHere++;
            DDLogVerbose(@"[MQTTDecoder] digit=0x%02x 0x%02x %d %d",
                      digit, digit & 0x7f, (unsigned int)self.length, (unsigned int)self.lengthMultiplier);
            [self.dataBuffer appendBytes:&digit length:1];
            self.offset++;
            self.length += ((digit & 0x7f) * self.lengthMultiplier);
            if ((digit & 0x80) == 0x00) {
                self.state = MQTTDecoderStateDecodingData;
                DDLogVerbose(@"[MQTTDecoder] remainingLength=%d", (unsigned int)self.length);
            } else {
                self.lengthMultiplier *= 128;
            }
        }

        if (self.state == MQTTDecoderStateDecodingData) {
            if (self.length > 0) {
                NSInteger toRead;
                UInt8 buffer[768];
                toRead = self.length + self.offset - self.dataBuffer.length;
                if (toRead > sizeof buffer) {
                    toRead = sizeof buffer;
                }
                if (data.length - readHere < toRead) {
                    toRead = data.length - readHere;
                }

                if (toRead > 0) {
                    DDLogDebug(@"[MQTTDecoder] buffer getBytes %ld/%lu %ld", (long)readHere, (unsigned long)data.length, (long)toRead);

                    [data getBytes:&buffer range:NSMakeRange(readHere, toRead)];
                    readHere += toRead;
                    [self.dataBuffer appendBytes:buffer length:toRead];
                }
            }
            if (self.dataBuffer.length == self.length + self.offset) {
                DDLogDebug(@"[MQTTDecoder] received (%lu)=%@...", (unsigned long)self.dataBuffer.length,
                             [self.dataBuffer subdataWithRange:NSMakeRange(0, MIN(256, self.dataBuffer.length))]);
                [self.delegate decoder:self didReceiveMessage:self.dataBuffer];
                self.dataBuffer = nil;
                self.state = MQTTDecoderStateDecodingHeader;
            } else {
                DDLogDebug(@"[MQTTDecoder] oops received (%lu)=%@...",
                           (unsigned long)self.dataBuffer.length,
                           [self.dataBuffer subdataWithRange:NSMakeRange(0, MIN(256, self.dataBuffer.length))]);
            }
        }        
    }
}

- (void)open {
    self.state = MQTTDecoderStateDecodingHeader;
}

- (void)close {
    self.state = MQTTDecoderStateInitializing;
}

@end
