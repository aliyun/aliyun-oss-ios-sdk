//
//  OSSURLRequestRetryHandler.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/22.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSConstants.h"

@class OSSNetworkingRequestDelegate;


NS_ASSUME_NONNULL_BEGIN

/**
 The retry handler interface
 */
@interface OSSURLRequestRetryHandler : NSObject

@property (nonatomic, assign) uint32_t maxRetryCount;


+ (instancetype)defaultRetryHandler;

- (OSSNetworkingRetryType)shouldRetry:(uint32_t)currentRetryCount
                      requestDelegate:(OSSNetworkingRequestDelegate *)delegate
                             response:(NSHTTPURLResponse *)response
                                error:(NSError *)error;

- (NSTimeInterval)timeIntervalForRetry:(uint32_t)currentRetryCount
                             retryType:(OSSNetworkingRetryType)retryType;
@end

NS_ASSUME_NONNULL_END
