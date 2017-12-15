//
//  OSSInputStreamHelper.h
//  AliyunOSSSDK
//
//  Created by 怀叙 on 2017/12/7.
//  Copyright © 2017年 阿里云. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface OSSInputStreamHelper : NSObject

@property (nonatomic, assign) uint64_t crc64;

- (instancetype)initWithFileAtPath:(nonnull NSString *)path;
- (instancetype)initWithURL:(nonnull NSURL *)URL;

- (void)syncReadBuffers;

@end
NS_ASSUME_NONNULL_END
