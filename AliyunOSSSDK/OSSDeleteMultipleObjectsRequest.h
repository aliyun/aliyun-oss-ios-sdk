//
//  OSSDeleteMultipleObjectsRequest.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/26.
//  Copyright © 2018年 aliyun. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "OSSRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface OSSDeleteMultipleObjectsRequest : OSSRequest

@property (nonatomic, copy) NSString *bucketName;

@property (nonatomic, copy) NSArray<NSString *> *keys;

/**
 invalid value is @"url"
 */
@property (nonatomic, copy, nullable) NSString *encodingType;

/**
 whether to show verbose result,the default value is YES.
 */
@property (nonatomic, assign) BOOL quiet;

@end

NS_ASSUME_NONNULL_END
