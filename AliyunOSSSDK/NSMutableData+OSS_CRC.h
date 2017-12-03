//
//  NSMutableData+OSS_CRC.h
//  AliyunOSSSDK
//
//  Created by 怀叙 on 2017/11/29.
//  Copyright © 2017年 阿里云. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableData (OSS_CRC)

- (uint64_t)oss_crc64;
- (uint64_t)oss_crc64ForCombineCRC1:(uint64_t)crc1 CRC2:(uint64_t)crc2 length:(size_t)len2;

@end
