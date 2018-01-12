//
//  OSSInputStreamHelper.m
//  AliyunOSSSDK
//
//  Created by 怀叙 on 2017/12/7.
//  Copyright © 2017年 阿里云. All rights reserved.
//

#import "OSSInputStreamHelper.h"
#import "OSSLog.h"
#import "aos_crc64.h"

@interface OSSInputStreamHelper ()
{
    NSInputStream *_inputStream;
    CFAbsoluteTime _startTime;
    dispatch_semaphore_t _semaphore;
}

@end

@implementation OSSInputStreamHelper

- (instancetype)initWithFileAtPath:(nonnull NSString *)path
{
    self = [super init];
    if (self) {
        _crc64 = 0;
        _inputStream = [NSInputStream inputStreamWithFileAtPath:path];
        _semaphore = dispatch_semaphore_create(1);
    }
    return self;
}

- (instancetype)initWithURL:(nonnull NSURL *)URL
{
    self = [super init];
    if (self) {
        _crc64 = 0;
        _inputStream = [NSInputStream inputStreamWithURL:URL];
        _semaphore = dispatch_semaphore_create(1);
    }
    return self;
}

- (void)syncReadBuffers
{
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);

    _startTime = CFAbsoluteTimeGetCurrent();
    [_inputStream open];
    NSInteger length = 1;
    while (length > 0)
    {
        @autoreleasepool{
            uint8_t streamData[1024 * 4];
            length = [_inputStream read:streamData maxLength:1024 * 4];
            if (length > 0) {
                _crc64 = aos_crc64(_crc64, streamData, length);
            }
        }
    }
    
    if (length < 0) {
        OSSLogError(@"there is an error when reading buffer from file!");
    }
    [_inputStream close];
    
    CFAbsoluteTime duration =  CFAbsoluteTimeGetCurrent() - _startTime;
    OSSLogDebug(@"read file cost time is :%f",duration);
    
    dispatch_semaphore_signal(_semaphore);
}

- (uint64_t)crc64
{
    return _crc64;
}

@end
