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

#ifndef OSSTASK_DEFINED
#define OSSTASK_DEFINED
typedef BFTask OSSTask;
#endif

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
 * Store the completion handler.
 * The completion handler is invoked by the networking delegate
 * method (if all the background tasks have been completed).
 */
- (void)setBackgroundSessionCompletionHandler:(void(^)())completeHandler;

/**
 * corresponding to restful api: putBucket
 */
- (OSSTask *)createBucket:(OSSCreateBucketRequest *)request;

/**
 * corresponding to restful api: deleteBucket
 */
- (OSSTask *)deleteBucket:(OSSDeleteBucketRequest *)request;

/**
 * corresponding to restful api: getBucket
 */
- (OSSTask *)getBucket:(OSSGetBucketRequest *)request;

/**
 * corresponding to restful api: headObject
 */
- (OSSTask *)headObject:(OSSHeadObjectRequest *)request;

/**
 * corresponding to restful api: getObjct
 */
- (OSSTask *)getObject:(OSSGetObjectRequest *)request;

/**
 * corresponding to restful api: putObject
 */
- (OSSTask *)putObject:(OSSPutObjectRequest *)request;

/**
 * corresponding to restful api: appendObject
 */
- (OSSTask *)appendObject:(OSSAppendObjectRequest *)request;

/**
 * corresponding to restful api: copyObject
 */
- (OSSTask *)copyObject:(OSSCopyObjectRequest *)request;

/**
 * corresponding to restful api: deleteObject
 */
- (OSSTask *)deleteObject:(OSSDeleteObjectRequest *)request;

/**
 * corresponding to restful api: initMultipartUpload
 */
- (OSSTask *)multipartUploadInit:(OSSInitMultipartUploadRequest *)request;

/**
 * corresponding to restful api: uploadPart
 */
- (OSSTask *)uploadPart:(OSSUploadPartRequest *)request;

/**
 * corresponding to restful api: completeMultipartUpload
 */
- (OSSTask *)completeMultipartUpload:(OSSCompleteMultipartUploadRequest *)request;

/**
 * corresponding to restful api: listParts
 */
- (OSSTask *)listParts:(OSSListPartsRequest *)request;

/**
 * corresponding to restful api: abortMultipartUpload
 */
- (OSSTask *)abortMultipartUpload:(OSSAbortMultipartUploadRequest *)request;

/**
 * presigned constrain URL for third-party to get Object
 */
- (OSSTask *)presignConstrainURLWithBucketName:(NSString *)bucketName
                                withObjectKey:(NSString *)objectKey
                       withExpirationInterval:(NSTimeInterval)interval;

/**
 * generate public URL for third-party to get Object
 */
- (OSSTask *)presignPublicURLWithBucketName:(NSString *)bucketName
                            withObjectKey:(NSString *)objectKey;

@end
