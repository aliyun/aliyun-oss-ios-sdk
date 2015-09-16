//
//  OSSClient.h
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@class OSSCreateBucketRequest;
@class OSSDeleteBucketRequest;
@class OSSHeadObjectRequest;
@class OSSGetBucketRequest;
@class OSSGetObjectRequest;
@class OSSPutObjectRequest;
@class OSSDeleteObjectRequest;
@class OSSCopyObjectRequest;
@class OSSInitMultipartUploadRequest;
@class OSSUploadPartRequest;
@class OSSCompleteMultipartUploadRequest;
@class OSSListPartsRequest;
@class OSSAbortMultipartUploadRequest;
@class OSSAppendObjectRequest;
@class BFTask;

@class OSSNetworking;
@class OSSClientConfiguration;
@protocol OSSCredentialProvider;


/**
 * a oss client to interact with a region-specified oss service
 */
@interface OSSClient : NSObject
@property (nonatomic, strong) NSString * endpoint;
@property (nonatomic, strong) OSSNetworking * networking;
@property (nonatomic, strong) id<OSSCredentialProvider> credentialProvider;
@property (nonatomic, strong) OSSClientConfiguration * clientConfiguration;

/**
 * init with endpoint, credentialprovider and default configuration
 */
- (instancetype)initWithEndpoint:(NSString *)endpoint
              credentialProvider:(id<OSSCredentialProvider>) credentialProvider;

/**
 * init with endpoint, credentialprovider and custom configuration
 */
- (instancetype)initWithEndpoint:(NSString *)endpoint
              credentialProvider:(id<OSSCredentialProvider>)credentialProvider
             clientConfiguration:(OSSClientConfiguration *)conf;


/**
 * corresponding to restful api: putBucket
 */
- (BFTask *)createBucket:(OSSCreateBucketRequest *)request;

/**
 * corresponding to restful api: deleteBucket
 */
- (BFTask *)deleteBucket:(OSSDeleteBucketRequest *)request;

/**
 * corresponding to restful api: getBucket
 */
- (BFTask *)getBucket:(OSSGetBucketRequest *)request;

/**
 * corresponding to restful api: headObject
 */
- (BFTask *)headObject:(OSSHeadObjectRequest *)request;

/**
 * corresponding to restful api: getObjct
 */
- (BFTask *)getObject:(OSSGetObjectRequest *)request;

/**
 * corresponding to restful api: putObject
 */
- (BFTask *)putObject:(OSSPutObjectRequest *)request;

/**
 * corresponding to restful api: appendObject
 */
- (BFTask *)appendObject:(OSSAppendObjectRequest *)request;

/**
 * corresponding to restful api: copyObject
 */
- (BFTask *)copyObject:(OSSCopyObjectRequest *)request;

/**
 * corresponding to restful api: deleteObject
 */
- (BFTask *)deleteObject:(OSSDeleteObjectRequest *)request;

/**
 * corresponding to restful api: initMultipartUpload
 */
- (BFTask *)multipartUploadInit:(OSSInitMultipartUploadRequest *)request;

/**
 * corresponding to restful api: uploadPart
 */
- (BFTask *)uploadPart:(OSSUploadPartRequest *)request;

/**
 * corresponding to restful api: completeMultipartUpload
 */
- (BFTask *)completeMultipartUpload:(OSSCompleteMultipartUploadRequest *)request;

/**
 * corresponding to restful api: listParts
 */
- (BFTask *)listParts:(OSSListPartsRequest *)request;

/**
 * corresponding to restful api: abortMultipartUpload
 */
- (BFTask *)abortMultipartUpload:(OSSAbortMultipartUploadRequest *)request;

@end
