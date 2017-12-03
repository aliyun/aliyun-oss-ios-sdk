//
//  NSMutableData+OSS_CRC.m
//  AliyunOSSSDK
//
//  Created by 怀叙 on 2017/11/29.
//  Copyright © 2017年 阿里云. All rights reserved.
//

#import "NSMutableData+OSS_CRC.h"
#include "aos_crc64.h"

@implementation NSMutableData (OSS_CRC)

- (uint64_t)oss_crc64
{
    return aos_crc64(0, self.mutableBytes, self.length);
}

@end
