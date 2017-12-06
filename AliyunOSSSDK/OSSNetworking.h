//
//  OSSNetworking.h
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSModel.h"

@class OSSSyncMutableDictionary;
@class OSSNetworkingRequestDelegate;
@class OSSExecutor;

/**
 Retry type definition
 */
typedef NS_ENUM(NSInteger, OSSNetworkingRetryType) {
    OSSNetworkingRetryTypeUnknown,
    OSSNetworkingRetryTypeShouldRetry,
    OSSNetworkingRetryTypeShouldNotRetry,
    OSSNetworkingRetryTypeShouldRefreshCredentialsAndRetry,
    OSSNetworkingRetryTypeShouldCorrectClockSkewAndRetry
};

/**
 The retry handler interface
 */
@interface OSSURLRequestRetryHandler : NSObject
@property (nonatomic, assign) uint32_t maxRetryCount;

- (OSSNetworkingRetryType)shouldRetry:(uint32_t)currentRetryCount
                      requestDelegate:(OSSNetworkingRequestDelegate *)delegate
                             response:(NSHTTPURLResponse *)response
                                error:(NSError *)error;

- (NSTimeInterval)timeIntervalForRetry:(uint32_t)currentRetryCount
                             retryType:(OSSNetworkingRetryType)retryType;

+ (instancetype)defaultRetryHandler;
@end

/**
 Network parameters
 */
@interface OSSNetworkingConfiguration : NSObject
@property (nonatomic, assign) uint32_t maxRetryCount;
@property (nonatomic, assign) uint32_t maxConcurrentRequestCount;
@property (nonatomic, assign) BOOL enableBackgroundTransmitService;
@property (nonatomic, strong) NSString * backgroundSessionIdentifier;
@property (nonatomic, assign) NSTimeInterval timeoutIntervalForRequest;
@property (nonatomic, assign) NSTimeInterval timeoutIntervalForResource;
@property (nonatomic, strong) NSString * proxyHost;
@property (nonatomic, strong) NSNumber * proxyPort;
@end

/**
 The proxy object class for each OSS request.
 */
@interface OSSNetworkingRequestDelegate : NSObject

@property (nonatomic, strong) NSMutableArray * interceptors;
@property (nonatomic, strong) OSSAllRequestNeededMessage * allNeededMessage;
@property (nonatomic, strong) NSMutableURLRequest * internalRequest;
@property (nonatomic, assign) OSSOperationType operType;
@property (nonatomic, assign) BOOL isAccessViaProxy;

@property (nonatomic, assign) BOOL isRequestCancelled;

@property (nonatomic, strong) OSSHttpResponseParser * responseParser;

@property (nonatomic, strong) NSData * uploadingData;
@property (nonatomic, strong) NSURL * uploadingFileURL;

@property (nonatomic, assign) int64_t payloadTotalBytesWritten;

@property (nonatomic, assign) BOOL isBackgroundUploadFileTask;
@property (nonatomic, assign) BOOL isHttpdnsEnable;

@property (nonatomic, strong) OSSURLRequestRetryHandler * retryHandler;
@property (nonatomic, assign) uint32_t currentRetryCount;
@property (nonatomic, strong) NSError * error;
@property (nonatomic, assign) BOOL isHttpRequestNotSuccessResponse;
@property (nonatomic, strong) NSMutableData * httpRequestNotSuccessResponseBody;

@property (atomic, strong) NSURLSessionDataTask * currentSessionTask;

@property (nonatomic, copy) OSSNetworkingUploadProgressBlock uploadProgress;
@property (nonatomic, copy) OSSNetworkingDownloadProgressBlock downloadProgress;
@property (nonatomic, copy) OSSNetworkingRetryBlock retryCallback;
@property (nonatomic, copy) OSSNetworkingCompletionHandlerBlock completionHandler;
@property (nonatomic, copy) OSSNetworkingOnRecieveDataBlock onRecieveData;

/**
 本地计算的数据的crc值(只有当上传操作时才会设置此值),version2.7.2开始添加
 */
@property (nonatomic, copy) NSString *contentCRC;

/** 上一次的crc值 */
@property (nonatomic, copy) NSString *lastCRC;

/**
 是否开启crc校验,version2.7.2开始添加
 */
@property (nonatomic, assign) BOOL crc64Verifiable;



- (OSSTask *)buildInternalHttpRequest;
- (void)reset;
- (void)cancel;
@end

/**
 All necessary information in one OSS request.
 */
@interface OSSAllRequestNeededMessage : NSObject
@property (nonatomic, strong) NSString * endpoint;
@property (nonatomic, strong) NSString * httpMethod;
@property (nonatomic, strong) NSString * bucketName;
@property (nonatomic, strong) NSString * objectKey;
@property (nonatomic, strong) NSString * contentType;
@property (nonatomic, strong) NSString * contentMd5;
@property (nonatomic, strong) NSString * range;
@property (nonatomic, strong) NSString * date;
@property (nonatomic, strong) NSMutableDictionary * headerParams;
@property (nonatomic, strong) NSMutableDictionary * querys;

@property (nonatomic, assign) BOOL isHostInCnameExcludeList;

- (instancetype)initWithEndpoint:(NSString *)endpoint
                      httpMethod:(NSString *)httpMethod
                      bucketName:(NSString *)bucketName
                       objectKey:(NSString *)objectKey
                            type:(NSString *)contentType
                             md5:(NSString *)contentMd5
                           range:(NSString *)range
                            date:(NSString *)date
                    headerParams:(NSMutableDictionary *)headerParams
                          querys:(NSMutableDictionary *)querys;

- (OSSTask *)validateRequestParamsInOperationType:(OSSOperationType)operType;
@end

/**
 The network interface which OSSClient uses for network read and write operations.
 */
@interface OSSNetworking : NSObject <NSURLSessionDelegate, NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSession * dataSession;
@property (nonatomic, strong) NSURLSession * uploadFileSession;
@property (nonatomic, assign) BOOL isUsingBackgroundSession;
@property (nonatomic, strong) OSSSyncMutableDictionary * sessionDelagateManager;
@property (nonatomic, strong) OSSNetworkingConfiguration * configuration;
@property (nonatomic, strong) OSSExecutor * taskExecutor;

- (instancetype)initWithConfiguration:(OSSNetworkingConfiguration *)configuration;
- (OSSTask *)sendRequest:(OSSNetworkingRequestDelegate *)request;
@end
