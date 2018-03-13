//
//  OSSHttpResponseParser.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/22.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSConstants.h"
#import "OSSTask.h"

NS_ASSUME_NONNULL_BEGIN

/**
 HTTP response parser
 */
@interface OSSHttpResponseParser : NSObject

@property (nonatomic, copy) OSSNetworkingOnRecieveDataBlock onRecieveBlock;

@property (nonatomic, strong) NSURL *downloadingFileURL;

/**
 *  A Boolean value that determines whether verfifying crc64.
 When set to YES, it will verify crc64 when transmission is completed normally.
 The default value of this property is NO.
 */
@property (nonatomic, assign) BOOL crc64Verifiable;

- (instancetype)initForOperationType:(OSSOperationType)operationType;
- (void)consumeHttpResponse:(NSHTTPURLResponse *)response;
- (OSSTask *)consumeHttpResponseBody:(NSData *)data;
- (nullable id)constructResultObject;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
