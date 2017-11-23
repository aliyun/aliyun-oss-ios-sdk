//
//  OSSLog.m
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import "OSSLog.h"
#import "OSSUtil.h"

@implementation OSSLog
+ (void)enableLog {
    if([OSSUtil hasPhoneFreeSpace]){
        isEnable = YES;
        [OSSDDLog removeAllLoggers];
        [OSSDDLog addLogger:[OSSNSLogger sharedInstance]];
        OSSDDFileLogger *fileLogger = [[OSSDDFileLogger alloc] init];
        [OSSDDLog addLogger:fileLogger];
    }
}

+ (void)disableLog {
    isEnable = NO;
}

+ (BOOL)isLogEnable {
    return isEnable;
}

@end
