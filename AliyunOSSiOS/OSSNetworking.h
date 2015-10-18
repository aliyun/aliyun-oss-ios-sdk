//
//  OSSNetworking.h
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSModel.h"

@class BFTask;
@class OSSSyncMutableDictionary;

#ifndef OSSTASK_DEFINED
#define OSSTASK_DEFINED
typedef BFTask OSSTask;
#endif

/**
 * enum request retry type
 */
typedef NS_ENUM(NSInteger, OSSNetworkingRetryType) {
    OSSNetworkingRetryTypeUnknown,
    OSSNetworkingRetryTypeShouldRetry,
    OSSNetworkingRetryTypeShouldNotRetry,
    OSSNetworkingRetryTypeShouldRefreshCredentialsAndRetry,
    OSSNetworkingRetryTypeShouldCorrectClockSkewAndRetry
};

/**
 * define request retry handler
 */
@interface OSSURLRequestRetryHandler : NSObject
@property (nonatomic, assign) uint32_t maxRetryCount;

- (OSSNetworkingRetryType)shouldRetry:(uint32_t)currentRetryCount
                             response:(NSHTTPURLResponse *)response
                                error:(NSError *)error;

- (NSTimeInterval)timeIntervalForRetry:(uint32_t)currentRetryCount
                             retryType:(OSSNetworkingRetryType)retryType;

+ (instancetype)defaultRetryHandler;
@end

/**
 * networking configuration
 */
@interface OSSNetworkingConfiguration : NSObject
@property (nonatomic, assign) uint32_t maxRetryCount;
@property (nonatomic, assign) BOOL enableBackgroundTransmitService;
@property (nonatomic, strong) NSString * backgroundSessionIdentifier;
@property (nonatomic, assign) NSTimeInterval timeoutIntervalForRequest;
@property (nonatomic, assign) NSTimeInterval timeoutIntervalForResource;
@property (nonatomic, strong) NSString * proxyHost;
@property (nonatomic, strong) NSNumber * proxyPort;
@end

/**
 * one delegate for one request session
 */
@interface OSSNetworkingRequestDelegate : NSObject

@property (nonatomic, strong) NSMutableArray * interceptors;
@property (nonatomic, strong) OSSAllRequestNeededMessage * allNeededMessage;
@property (nonatomic, strong) NSMutableURLRequest * internalRequest;
@property (nonatomic, assign) OSSOperationType operType;
@property (nonatomic, assign) BOOL isAccessViaProxy;

@property (nonatomic, strong) OSSHttpResponseParser * responseParser;

@property (nonatomic, strong) NSData * uploadingData;
@property (nonatomic, strong) NSURL * uploadingFileURL;

@property (nonatomic, assign) int64_t payloadTotalBytesWritten;

@property (nonatomic, assign) BOOL isBackgroundUploadTask;

@property (nonatomic, strong) OSSURLRequestRetryHandler * retryHandler;
@property (nonatomic, assign) uint32_t currentRetryCount;
@property (nonatomic, strong) NSError * error;
@property (nonatomic, assign) BOOL isHttpRequestNotSuccessResponse;
@property (nonatomic, strong) NSMutableData * httpRequestNotSuccessResponseBody;

@property (atomic, strong) NSURLSessionDataTask * currentSessionTask;

@property (nonatomic, copy) OSSNetworkingUploadProgressBlock uploadProgress;
@property (nonatomic, copy) OSSNetworkingDownloadProgressBlock downloadProgress;
@property (nonatomic, copy) OSSNetworkingCompletionHandlerBlock completionHandler;
@property (nonatomic, copy) OSSNetworkingOnRecieveDataBlock onRecieveData;

- (OSSTask *)buildInternalHttpRequest;
- (void)reset;
- (void)cancel;
@end

/**
 * contail all necessary message to send request to oss server
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
 * represent a networking client which manager all the networking operations for an ossclient
 */
@interface OSSNetworking : NSObject <NSURLSessionDelegate>
@property (nonatomic, strong) NSURLSession * dataSession;
@property (nonatomic, strong) NSURLSession * uploadSession;
@property (nonatomic, assign) BOOL isUsingBackgroundSession;
@property (nonatomic, strong) OSSSyncMutableDictionary * sessionDelagateManager;
@property (nonatomic, strong) OSSNetworkingConfiguration * configuration;
@property (nonatomic, strong) BFExecutor * taskExecutor;
@property (atomic, copy) void (^backgroundSessionCompletionHandler)();

- (instancetype)initWithConfiguration:(OSSNetworkingConfiguration *)configuration;
- (OSSTask *)sendRequest:(OSSNetworkingRequestDelegate *)request;
@end
