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

@end
