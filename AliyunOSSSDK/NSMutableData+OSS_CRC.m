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

- (uint64_t)oss_crc64ForCombineCRC1:(uint64_t)crc1 CRC2:(uint64_t)crc2 length:(size_t)len2
{
    return aos_crc64_combine(crc1, crc2, len2);
}

@end
