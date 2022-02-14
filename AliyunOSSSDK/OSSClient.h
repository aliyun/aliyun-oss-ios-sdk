//
//  OSSClient.h
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import <Foundation/Foundation.h>
@class OSSGetServiceRequest;
@class OSSCreateBucketRequest;
@class OSSDeleteBucketRequest;
@class OSSHeadObjectRequest;
@class OSSGetBucketRequest;
@class OSSGetBucketACLRequest;
@class OSSGetObjectRequest;
@class OSSGetObjectACLRequest;
@class OSSPutObjectRequest;
@class OSSPutObjectACLRequest;
@class OSSDeleteObjectRequest;
@class OSSDeleteMultipleObjectsRequest;
@class OSSCopyObjectRequest;
@class OSSInitMultipartUploadRequest;
@class OSSUploadPartRequest;
@class OSSCompleteMultipartUploadRequest;
@class OSSListPartsRequest;
@class OSSListMultipartUploadsRequest;
@class OSSAbortMultipartUploadRequest;
@class OSSAppendObjectRequest;
@class OSSResumableUploadRequest;
@class OSSMultipartUploadRequest;
@class OSSCallBackRequest;
@class OSSImagePersistRequest;
@class OSSGetBucketInfoRequest;
@class OSSPutSymlinkRequest;
@class OSSGetSymlinkRequest;
@class OSSRestoreObjectRequest;

@class OSSTask;
@class OSSExecutor;
@class OSSNetworking;
@class OSSClientConfiguration;
@protocol OSSCredentialProvider;

NS_ASSUME_NONNULL_BEGIN

/**
 OSSClient is the entry class to access OSS in an iOS client. It provides all the methods to communicate with OSS.
 Generally speaking, only one instance of OSSClient is needed in the whole app.
 */
@interface OSSClient : NSObject

/**
 OSS endpoint. It varies in different regions. Please check out OSS official website for the exact endpoints for your data.
 */
@property (nonatomic, strong) NSString * endpoint;

/**
 The networking instance for sending and receiving data
 */
@property (nonatomic, strong) OSSNetworking * networking;

/**
 The credential provider instance
 */
@property (nonatomic, strong) id<OSSCredentialProvider> credentialProvider;

/**
 Client configuration instance
 */
@property (nonatomic, strong) OSSClientConfiguration * clientConfiguration;

/**
 oss operation task queue
 */
@property (nonatomic, strong, readonly) OSSExecutor * ossOperationExecutor;

/**
 Initializes an OSSClient instance with the default client configuration.
 @endpoint it specifies domain of the bucket's region. Starting 2017, the domain must be prefixed with "https://" to follow Apple's ATS policy.
             For example: "https://oss-cn-hangzhou.aliyuncs.com"
 @credentialProvider The credential provider
 */
- (instancetype)initWithEndpoint:(NSString *)endpoint
              credentialProvider:(id<OSSCredentialProvider>) credentialProvider;

/**
 Initializes an OSSClient with the custom client configuration.
 @endpoint it specifies domain of the bucket's region. Starting 2017, the domain must be prefixed with "https://" to follow Apple's ATS policy.
             For example: "https://oss-cn-hangzhou.aliyuncs.com"
 @credentialProvider The credential provider
 @conf The custom client configuration such as retry time, timeout values, etc.
 */
- (instancetype)initWithEndpoint:(NSString *)endpoint
              credentialProvider:(id<OSSCredentialProvider>)credentialProvider
             clientConfiguration:(OSSClientConfiguration *)conf;

@end

@interface OSSClient (Object)

/**
 The corresponding RESTFul API: PutObject
 Uploads a file.
 */
- (OSSTask *)putObject:(OSSPutObjectRequest *)request;

@end

NS_ASSUME_NONNULL_END
