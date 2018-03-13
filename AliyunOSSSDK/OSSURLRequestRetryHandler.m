//
//  OSSURLRequestRetryHandler.m
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/22.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "OSSURLRequestRetryHandler.h"
#import "OSSNetworkingRequestDelegate.h"
#import "OSSDefine.h"

@implementation OSSURLRequestRetryHandler

- (OSSNetworkingRetryType)shouldRetry:(uint32_t)currentRetryCount
                      requestDelegate:(OSSNetworkingRequestDelegate *)delegate
                             response:(NSHTTPURLResponse *)response
                                error:(NSError *)error {
    
    if (currentRetryCount >= self.maxRetryCount) {
        return OSSNetworkingRetryTypeShouldNotRetry;
    }
    
    /**
     When onRecieveData is set, no retry.
     When the error is task cancellation, no retry.
     */
    if (delegate.onRecieveData != nil) {
        return OSSNetworkingRetryTypeShouldNotRetry;
    }
    
    if ([error.domain isEqualToString:OSSClientErrorDomain]) {
        if (error.code == OSSClientErrorCodeTaskCancelled) {
            return OSSNetworkingRetryTypeShouldNotRetry;
        } else {
            return OSSNetworkingRetryTypeShouldRetry;
        }
    }
    
    switch (response.statusCode) {
        case 403:
            if ([[[error userInfo] objectForKey:@"Code"] isEqualToString:@"RequestTimeTooSkewed"]) {
                return OSSNetworkingRetryTypeShouldCorrectClockSkewAndRetry;
            }
            break;
            
        default:
            break;
    }
    
    return OSSNetworkingRetryTypeShouldNotRetry;
}

- (NSTimeInterval)timeIntervalForRetry:(uint32_t)currentRetryCount retryType:(OSSNetworkingRetryType)retryType {
    switch (retryType) {
        case OSSNetworkingRetryTypeShouldCorrectClockSkewAndRetry:
        case OSSNetworkingRetryTypeShouldRefreshCredentialsAndRetry:
            return 0;
            
        default:
            return pow(2, currentRetryCount) * 200 / 1000;
    }
}

+ (instancetype)defaultRetryHandler {
    OSSURLRequestRetryHandler * retryHandler = [OSSURLRequestRetryHandler new];
    retryHandler.maxRetryCount = OSSDefaultRetryCount;
    return retryHandler;
}

@end
