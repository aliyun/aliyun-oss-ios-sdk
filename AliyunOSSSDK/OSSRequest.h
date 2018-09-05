//
//  OSSRequest.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/22.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSConstants.h"

/**
 The base class of request to OSS.
 */
@interface OSSRequest : NSObject
/**
 Flag of requiring authentication. It's per each request.
 */
@property (nonatomic, assign) BOOL isAuthenticationRequired;

/**
 the flag of request canceled.
 */
@property (atomic, assign) BOOL isCancelled;

/**
 the flag of verification about crc64
 */
@property (nonatomic, assign) OSSRequestCRCFlag crcFlag;

/**
 Cancels the request
 */
- (void)cancel;

/**
 Gets the query parameters' dictionary according to the properties.
 */
- (NSDictionary *)requestParams;

@end
