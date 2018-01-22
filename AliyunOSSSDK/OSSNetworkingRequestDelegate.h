//
//  OSSNetworkingRequestDelegate.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/22.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSConstants.h"
#import "OSSTask.h"

@class OSSAllRequestNeededMessage;
@class OSSURLRequestRetryHandler;
@class OSSHttpResponseParser;

/**
 The proxy object class for each OSS request.
 */
@interface OSSNetworkingRequestDelegate : NSObject

@property (nonatomic, strong) NSMutableArray * interceptors;

@property (nonatomic, strong) NSMutableURLRequest *internalRequest;
@property (nonatomic, assign) OSSOperationType operType;
@property (nonatomic, assign) BOOL isAccessViaProxy;

@property (nonatomic, assign) BOOL isRequestCancelled;

@property (nonatomic, strong) OSSAllRequestNeededMessage *allNeededMessage;
@property (nonatomic, strong) OSSURLRequestRetryHandler *retryHandler;
@property (nonatomic, strong) OSSHttpResponseParser *responseParser;

@property (nonatomic, strong) NSData * uploadingData;
@property (nonatomic, strong) NSURL * uploadingFileURL;

@property (nonatomic, assign) int64_t payloadTotalBytesWritten;

@property (nonatomic, assign) BOOL isBackgroundUploadFileTask;
@property (nonatomic, assign) BOOL isHttpdnsEnable;


@property (nonatomic, assign) uint32_t currentRetryCount;
@property (nonatomic, strong) NSError * error;
@property (nonatomic, assign) BOOL isHttpRequestNotSuccessResponse;
@property (nonatomic, strong) NSMutableData *httpRequestNotSuccessResponseBody;

@property (atomic, strong) NSURLSessionDataTask *currentSessionTask;

@property (nonatomic, copy) OSSNetworkingUploadProgressBlock uploadProgress;
@property (nonatomic, copy) OSSNetworkingDownloadProgressBlock downloadProgress;
@property (nonatomic, copy) OSSNetworkingRetryBlock retryCallback;
@property (nonatomic, copy) OSSNetworkingCompletionHandlerBlock completionHandler;
@property (nonatomic, copy) OSSNetworkingOnRecieveDataBlock onRecieveData;

/**
 * when put object to server,client caculate crc64 code and assigns it to
 * this property.
 */
@property (nonatomic, copy) NSString *contentCRC;

/** last crc64 code */
@property (nonatomic, copy) NSString *lastCRC;

/**
 * determine whether to verify crc64 code
 */
@property (nonatomic, assign) BOOL crc64Verifiable;



- (OSSTask *)buildInternalHttpRequest;
- (void)reset;
- (void)cancel;

@end
