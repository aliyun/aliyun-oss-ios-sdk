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
@property (nonatomic, assign) BOOL enableFollowRedirects;
@property (nonatomic, assign) uint32_t HTTPMaximumConnectionsPerHost;
@end


/**
 The network interface which OSSClient uses for network read and write operations.
 */
@interface OSSNetworking : NSObject <NSURLSessionDelegate, NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSession * session;
@property (nonatomic, assign) BOOL isUsingBackgroundSession;
@property (nonatomic, strong) OSSSyncMutableDictionary * sessionDelagateManager;
@property (nonatomic, strong) OSSNetworkingConfiguration * configuration;
@property (nonatomic, strong) OSSExecutor * taskExecutor;

- (instancetype)initWithConfiguration:(OSSNetworkingConfiguration *)configuration;
- (OSSTask *)sendRequest:(OSSNetworkingRequestDelegate *)request;
@end
