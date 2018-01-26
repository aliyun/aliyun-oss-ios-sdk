//
//  OSSResult.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/26.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 The base class of result from OSS.
 */
@interface OSSResult : NSObject

/**
 The http response code.
 */
@property (nonatomic, assign) NSInteger httpResponseCode;

/**
 The http headers, in the form of key value dictionary.
 */
@property (nonatomic, strong) NSDictionary * httpResponseHeaderFields;

/**
 The request Id. It's the value of header x-oss-request-id, which is created from OSS server.
 It's a unique Id represents this request. This is used for troubleshooting when you contact OSS support.
 */
@property (nonatomic, strong) NSString * requestId;

/**
 It's the value of header x-oss-hash-crc64ecma, which is created from OSS server.
 */
@property (nonatomic, copy) NSString *remoteCRC64ecma;

/**
 It's the value of local Data.
 */
@property (nonatomic, copy) NSString *localCRC64ecma;

@end
