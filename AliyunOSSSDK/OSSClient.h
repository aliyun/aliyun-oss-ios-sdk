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
@class OSSGetObjectTaggingRequest;
@class OSSDeleteObjectTaggingRequest;
@class OSSPutObjectTaggingRequest;

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

#pragma mark restful-api

/**
 The corresponding RESTFul API: GetService
 Gets all the buckets of the current user
 Notes：
 1. STS is not supported yet in this call.
 2. When all buckets are returned, the xml in response body does not have nodes of Prefix, Marker, MaxKeys, IsTruncated and NextMarker.
    If there're remaining buckets to return, the xml will have these nodes. The nextMarker is the value of marker in the next call.
 */
- (OSSTask *)getService:(OSSGetServiceRequest *)request;

@end


@interface OSSClient (Bucket)

/**
 The corresponding RESTFul API: PutBucket
 Creates a bucket--it does not support anonymous access. By default, the datacenter used is oss-cn-hangzhou.
 Callers could explicitly specify the datacenter for the bucket to optimize the performance and cost or meet the regulation requirement.
 Notes:
 1. STS is not supported yet.
 */
- (OSSTask *)createBucket:(OSSCreateBucketRequest *)request;

/**
 The corresponding RESTFul API: DeleteBucket
 Deletes a bucket.
 */
- (OSSTask *)deleteBucket:(OSSDeleteBucketRequest *)request;

/**
 The corresponding RESTFul API: GetBucket
 Lists all objects in a bucket. It could be specified with filters such as prefix, marker, delimeter and max-keys.
 */
- (OSSTask *)getBucket:(OSSGetBucketRequest *)request;

/**
 The corresponding RESTFul API: GetBucketInfo
 Gets the {@link Bucket}'s basic information as well as its ACL.
 */
- (OSSTask *)getBucketInfo:(OSSGetBucketInfoRequest *)request;

/**
 The corresponding RESTFul API: GetBucketACL
 Gets the bucket ACL.
 */
- (OSSTask *)getBucketACL:(OSSGetBucketACLRequest *)request;

@end


@interface OSSClient (Object)

/**
 The corresponding RESTFul API: HeadObject
 Gets the object's metadata information. The object's content is not returned.
 */
- (OSSTask *)headObject:(OSSHeadObjectRequest *)request;

/**
 The corresponding RESTFul API: GetObject
 Gets the whole object (includes content). It requires caller have read permission on the object.
 */
- (OSSTask *)getObject:(OSSGetObjectRequest *)request;

/**
 The corresponding RESTFul API: GetObjectACL
 get the acl of an object.
 */
- (OSSTask *)getObjectACL:(OSSGetObjectACLRequest *)request;

/**
 The corresponding RESTFul API: PutObject
 Uploads a file.
 */
- (OSSTask *)putObject:(OSSPutObjectRequest *)request;

/**
 Sets the object's ACL. Right now an object has three access permissions: private, public-ready, public-read-write.
 The operation specifies the x-oss-object-acl header in the put request. The caller must be the owner of the object.
 If succeeds, it returns HTTP status 200; otherwise it returns related error code and error messages.
 */
- (OSSTask *)putObjectACL:(OSSPutObjectACLRequest *)request;

/**
 The corresponding RESTFul API: AppendObject
 Appends data to an existing or non-existing object. The object created by this operation is appendable.
 As a comparison, the object created by Put Object is normal (non-appendable).
 */
- (OSSTask *)appendObject:(OSSAppendObjectRequest *)request;

/**
 *  @brief      Appends data to an existing or non-existing object on the OSS server.
 *              The object created by this operation is appendable.
 *  @request    request
 *  @crc64ecma  crc64ecma
 *             if object has been stored on OSS server, you need to invoke headObject
 *             api get object's crc64ecma,then use this api to append data to the
 *             object.
 */
- (OSSTask *)appendObject:(OSSAppendObjectRequest *)request withCrc64ecma:(nullable NSString *)crc64ecma;

/**
 The corresponding RESTFul API: copyObject
 Copies an existing object to another one.The operation sends a PUT request with x-oss-copy-source header to specify the source object.
 OSS server side will detect and copy the object. If it succeeds, the new object's metadata information will be returned.
 The operation applies for files less than 1GB. For big files, use UploadPartCopy RESTFul API.
 */
- (OSSTask *)copyObject:(OSSCopyObjectRequest *)request;

/**
 * Batch deletes the specified files under a specific bucket. If the files
 * are non-exist, the operation will still return successful.
 *
 * @param request
 *            A OSSDeleteMultipleObjectsRequest instance which specifies the
 *            bucket and file keys to delete.
 * @return A OSSTask with result of OSSDeleteMultipleObjectsResult instance which specifies each
 *         file's result in normal mode or only failed deletions in quite
 *         mode. By default it's quite mode.
 */
- (OSSTask *)deleteMultipleObjects:(OSSDeleteMultipleObjectsRequest *)request;

/**
 The corresponding RESTFul API: DeleteObject
 Deletes an object
 */
- (OSSTask *)deleteObject:(OSSDeleteObjectRequest *)request;

/**
 * Creates a symbol link to a target file under the bucket---this is not
 * supported for archive class bucket.
 *
 * @param request
 *            A OSSPutSymlinkRequest instance that specifies the
 *            bucket name, symlink name.
 * @return An instance of OSSTask. On successful execution, `task.result` will
 *         contain an instance of `OSSPutSymlinkResult`,otherwise will contain
 *         an instance of NSError.
 *
 * for more information,please refer to https://help.aliyun.com/document_detail/45126.html
 */
- (OSSTask *)putSymlink:(OSSPutSymlinkRequest *)request;

/**
 * Gets the symlink information for the given symlink name.
 *
 * @param request
 *            A OSSGetSymlinkRequest instance which specifies the bucket
 *            name and symlink name.
 * @return An instance of OSSTask. On successful execution, `task.result` will
 *         contain an instance of `OSSGetSymlinkResult`,otherwise will contain
 *         an instance of NSError.
 *
 * for more information,please refer to https://help.aliyun.com/document_detail/45146.html
 */
- (OSSTask *)getSymlink:(OSSGetSymlinkRequest *)request;

/**
 * Restores the object of archive storage. The function is not applicable to
 * Normal or IA storage. The restoreObject() needs to be called prior to
 * calling getObject() on an archive object.
 *
 * @param request
 *          A container for the necessary parameters to execute the RestoreObject
 *          service method.
 *
 * @return An instance of OSSTask. On successful execution, `task.result` will
 *         contain an instance of `OSSRestoreObjectResult`,otherwise will contain
 *         an instance of NSError.
 *
 * for more information,please refer to https://help.aliyun.com/document_detail/52930.html
 */
- (OSSTask *)restoreObject:(OSSRestoreObjectRequest *)request;

/**
 * You can call this operation to query the tags of an object.
 *
 * @param request
 *          A OSSGetObjectTaggingRequest instance which specifies the bucket
 *            name and object key.
 *
 * @return An instance of OSSTask. On successful execution, `task.result` will
 *         contain an instance of `OSSGetObjectTaggingResult`,otherwise will contain
 *         an instance of NSError.
 *
 * for more information,please refer to https://help.aliyun.com/document_detail/114878.html
 */
- (OSSTask *)getObjectTagging:(OSSGetObjectTaggingRequest *)request;

/**
 * You can call this operation to add tags to an object or update the tags added to
 *  the bucket. The object tagging feature uses a key-value pair to tag an object.
 *
 * @param request
 *          A OSSPutObjectTaggingRequest instance which specifies the bucket
 *            name、object key and tags.
 *
 * @return An instance of OSSTask. On successful execution, `task.result` will
 *         contain an instance of `OSSPutObjectTaggingResult`,otherwise will contain
 *         an instance of NSError.
 *
 * for more information,please refer to https://help.aliyun.com/document_detail/114855.html
 */
- (OSSTask *)putObjectTagging:(OSSPutObjectTaggingRequest *)request;

/**
 * You can call this operation to delete the tags of a specified object.
 *
 * @param request
 *          A OSSDeleteObjectTaggingRequest instance which specifies the bucket
 *            name and object key.
 *
 * @return An instance of OSSTask. On successful execution, `task.result` will
 *         contain an instance of `OSSDeleteObjectTaggingResult`,otherwise will contain
 *         an instance of NSError.
 *
 * for more information,please refer to https://help.aliyun.com/document_detail/114879.html
 */
- (OSSTask *)deleteObjectTagging:(OSSDeleteObjectTaggingRequest *)request;



@end

@interface OSSClient (MultipartUpload)

/**
 The corresponding RESTFul API: InitiateMultipartUpload
 Initiates a multipart upload to get a upload Id. It's needed before starting uploading parts data.
 The upload Id is used for subsequential operations such as aborting the upload, querying the uploaded parts, etc.
 */
- (OSSTask *)multipartUploadInit:(OSSInitMultipartUploadRequest *)request;

/**
 The corresponding RESTFul API: UploadPart
 After the multipart upload is initiated, this API could be called to upload the data to the target file with the upload Id.
 Every uploaded part has a unique id called part number, which ranges from 1 to 10,000.
 For a given upload Id, the part number identifies the specific range of the data in the whole file.
 If the same part number is used for another upload, the existing data will be overwritten by the new upload.
 Except the last part, all other part's minimal size is 100KB.
 But no minimal size requirement on the last part.
 */
- (OSSTask *)uploadPart:(OSSUploadPartRequest *)request;

/**
 The corresponding RESTFul API: CompleteMultipartUpload
 This API is to complete the multipart upload after all parts data have been uploaded.
 It must be provided with a valid part list (each part has the part number and ETag).
 OSS will validate every part and then complete the multipart upload.
 If any part is invalid (e.g. the part is updated by another part upload), this API will fail.
 */
- (OSSTask *)completeMultipartUpload:(OSSCompleteMultipartUploadRequest *)request;

/**
 The corresponding RESTFul API: ListParts
 Lists all uploaded parts of the specified upload id.
 */
- (OSSTask *)listParts:(OSSListPartsRequest *)request;

/**
 The corresponding RESTFul API: ListMultipartUploads
 Lists all multipart uploads with the specified bucket.
 */
- (OSSTask *)listMultipartUploads:(OSSListMultipartUploadsRequest *)request;

/**
 The corresponding RESTFul API: AbortMultipartUpload
 Aborts the multipart upload by the specified upload Id.
 Once the multipart upload is aborted by this API, all parts data will be deleted and the upload Id is invalid anymore.
 */
- (OSSTask *)abortMultipartUpload:(OSSAbortMultipartUploadRequest *)request;

- (OSSTask *)abortResumableMultipartUpload:(OSSResumableUploadRequest *)request;

/**
 Multipart upload API
 */
- (OSSTask *)multipartUpload:(OSSMultipartUploadRequest *)request;
/**
 TODOTODO
 Resumable upload API
 This API wraps the multipart upload and also enables resuming upload by reading/writing  the checkpoint data.
 For a new file, multipartUploadInit() needs to be called first to get the upload Id. Then use this upload id to call this API to upload the data.
 If the upload fails, checks the error messages:
 If it's a recoverable error, then call this API again with the same upload Id to retry. The uploaded data will not be uploaded again.
 Otherwise then you may need to recreates a new upload Id and call this method again.
 Check out demo for the detail.
 */
- (OSSTask *)resumableUpload:(OSSResumableUploadRequest *)request;

/**
 * multipart upload sequentially in order,support resume upload
 */
- (OSSTask *)sequentialMultipartUpload:(OSSResumableUploadRequest *)request;

@end


@interface OSSClient (PresignURL)

/**
 Generates a signed URL for the object and anyone has this URL will get the GET permission on the object.
 @bucketName object's bucket name
 @objectKey Object name
 @interval Expiration time in seconds. The URL could be specified with the expiration time to limit the access window on the object.
 */
- (OSSTask *)presignConstrainURLWithBucketName:(NSString *)bucketName
                                 withObjectKey:(NSString *)objectKey
                        withExpirationInterval:(NSTimeInterval)interval;

/**
 Generates a signed URL for the object and anyone has this URL will get the specified permission on the object.
 @bucketName object's bucket name
 @objectKey Object name
 @interval Expiration time in seconds. The URL could be specified with the expiration time to limit the access window on the object.
 @parameter it could specify allowed HTTP methods
 */
- (OSSTask *)presignConstrainURLWithBucketName:(NSString *)bucketName
                                 withObjectKey:(NSString *)objectKey
                        withExpirationInterval:(NSTimeInterval)interval
                                withParameters:(NSDictionary *)parameters;

/**
 Generates a signed URL for the object and anyone has this URL will get the specified permission on the object. currently only support get and head method.
 @bucketName object's bucket name
 @objectKey Object name
 @httpMethod http method.currently only support get and head.
 @interval Expiration time in seconds. The URL could be specified with the expiration time to limit the access window on the object.
 @parameter it could specify allowed HTTP methods
 */
- (OSSTask *)presignConstrainURLWithBucketName:(NSString *)bucketName
                                 withObjectKey:(NSString *)objectKey
                                    httpMethod:(NSString *)method
                        withExpirationInterval:(NSTimeInterval)interval
                                withParameters:(NSDictionary *)parameters;


/// Generates a signed URL for the object and anyone has this URL will get the specified permission on the object.
/// @param bucketName object's bucket name
/// @param objectKey Object name
/// @param method http method.currently only support get and head.
/// @param interval Expiration time in seconds. The URL could be specified with the expiration time to limit the access window on the object.
/// @param parameters it could specify allowed HTTP methods
/// @param contentType Content-Type to url sign
/// @param contentMd5 Content-MD5 to url sign
- (OSSTask *)presignConstrainURLWithBucketName:(NSString *)bucketName
                                 withObjectKey:(NSString *)objectKey
                                    httpMethod:(NSString *)method
                        withExpirationInterval:(NSTimeInterval)interval
                                withParameters:(NSDictionary *)parameters
                                   contentType:(nullable NSString *)contentType
                                    contentMd5:(nullable NSString *)contentMd5;

/// Generates a signed URL for the object and anyone has this URL will get the specified permission on the object.
/// @param bucketName object's bucket name
/// @param objectKey Object name
/// @param method http method.currently only support get and head.
/// @param interval Expiration time in seconds. The URL could be specified with the expiration time to limit the access window on the object.
/// @param parameters it could specify allowed HTTP methods
/// @param headers Content Type, Content-MD5, and all HTTP headers prefixed with 'x-oss-*'
- (OSSTask *)presignConstrainURLWithBucketName:(NSString *)bucketName
                                 withObjectKey:(NSString *)objectKey
                                    httpMethod:(NSString *)method
                        withExpirationInterval:(NSTimeInterval)interval
                                withParameters:(NSDictionary *)parameters
                                   withHeaders:(nullable NSDictionary *)headers;

/**
 If the object's ACL is public read or public read-write, use this API to generate a signed url for sharing.
 @bucketName Object's bucket name
 @objectKey Object name
 */
- (OSSTask *)presignPublicURLWithBucketName:(NSString *)bucketName
                              withObjectKey:(NSString *)objectKey;

/** TODOTODO
 If the object's ACL is public read or public read-write, use this API to generate a signed url for sharing.
 @bucketName Object's bucket name
 @objectKey Object name
 @parameter the request parameters.
 */
- (OSSTask *)presignPublicURLWithBucketName:(NSString *)bucketName
                              withObjectKey:(NSString *)objectKey
                             withParameters:(NSDictionary *)parameters;

@end


@interface OSSClient (ImageService)

/*
 * image persist action
 * https://help.aliyun.com/document_detail/55811.html
 */
- (OSSTask *)imageActionPersist:(OSSImagePersistRequest *)request;

@end


@interface OSSClient (Utilities)

/**
 Checks if the object exists
 @bucketName Object's bucket name
 @objectKey Object name
 
 return YES                     Object exists
 return NO && *error = nil      Object does not exist
 return NO && *error != nil     Error occured.
 */
- (BOOL)doesObjectExistInBucket:(NSString *)bucketName
                      objectKey:(NSString *)objectKey
                          error:(const NSError **)error;

@end


@interface OSSClient (Callback)

- (OSSTask *)triggerCallBack:(OSSCallBackRequest *)request;

@end

NS_ASSUME_NONNULL_END
