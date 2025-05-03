//
//  OSSModel.h
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSRequest.h"
#import "OSSResult.h"

@class OSSAllRequestNeededMessage;
@class OSSFederationToken;
@class OSSTask;
@class OSSClientConfiguration;
@class OSSSignerParams;

NS_ASSUME_NONNULL_BEGIN

typedef OSSFederationToken * _Nullable (^OSSGetFederationTokenBlock) (void);

/**
 Categories NSDictionary
 */
@interface NSDictionary (OSS)
- (NSString *)base64JsonString;
@end

/**
 A thread-safe dictionary
 */
@interface OSSSyncMutableDictionary : NSObject
@property (nonatomic, strong) NSMutableDictionary *dictionary;
@property (nonatomic, strong) dispatch_queue_t dispatchQueue;

- (id)objectForKey:(id)aKey;
- (NSArray *)allKeys;
- (void)setObject:(id)anObject forKey:(id <NSCopying>)aKey;
- (void)removeObjectForKey:(id)aKey;
- (void)addObserverForResetCurrentRetryCount;
@end

/**
 FederationToken class
 */
@interface OSSFederationToken : NSObject
@property (nonatomic, copy) NSString * tAccessKey;
@property (nonatomic, copy) NSString * tSecretKey;
@property (nonatomic, copy) NSString * tToken;

/**
 Token's expiration time in milliseconds of the unix time.
 */
@property (atomic, assign) int64_t expirationTimeInMilliSecond;

/**
 Token's expiration time in GMT format string.
 */
@property (atomic, strong, nullable) NSString *expirationTimeInGMTFormat;

- (BOOL)useSecurityToken;

@end

/**
 CredentialProvider protocol, needs to implement sign API.
 */
@protocol OSSCredentialProvider <NSObject>
@optional
- (nullable NSString *)sign:(NSString *)content error:(NSError **)error;
@end

/**
 The plaint text AK/SK credential provider for test purposely.
 */

__attribute__((deprecated("PLEASE DO NOT USE THIS CLASS AGAIN")))
@interface OSSPlainTextAKSKPairCredentialProvider : NSObject <OSSCredentialProvider>
@property (nonatomic, copy) NSString * accessKey;
@property (nonatomic, copy) NSString * secretKey;

- (instancetype)initWithPlainTextAccessKey:(NSString *)accessKey
                                 secretKey:(NSString *)secretKey __attribute__((deprecated("We recommend the STS authentication mode on mobile")));
@end

/**
TODOTODO
 The custom signed credential provider
 */
@interface OSSCustomSignerCredentialProvider : NSObject <OSSCredentialProvider>
@property (nonatomic, copy, readonly,) NSString * _Nonnull (^ _Nonnull signContent)( NSString * _Nonnull , NSError * _Nullable *_Nullable);

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

/**
 * During the task execution, this API is called for signing
 * It's executed at the background thread instead of UI thread.
 */
- (instancetype _Nullable)initWithImplementedSigner:(OSSCustomSignContentBlock)signContent NS_DESIGNATED_INITIALIZER;
@end

/**
TODOTODO
 User's custom federation credential provider.
 */
@interface OSSFederationCredentialProvider : NSObject <OSSCredentialProvider>
@property (nonatomic, strong) OSSFederationToken * cachedToken;
@property (nonatomic, copy) OSSFederationToken * (^federationTokenGetter)(void);

/**
 During the task execution, this method is called to get the new STS token.
 It runs in the background thread, not the UI thread.
 */
- (instancetype)initWithFederationTokenGetter:(OSSGetFederationTokenBlock)federationTokenGetter;
- (nullable OSSFederationToken *)getToken:(NSError **)error;
@end

/**
 The STS token's credential provider.
 */
@interface OSSStsTokenCredentialProvider : NSObject <OSSCredentialProvider>
@property (nonatomic, copy) NSString * accessKeyId;
@property (nonatomic, copy) NSString * secretKeyId;
@property (nonatomic, copy) NSString * securityToken;

- (OSSFederationToken *)getToken;
- (instancetype)initWithAccessKeyId:(NSString *)accessKeyId
                        secretKeyId:(NSString *)secretKeyId
                      securityToken:(NSString *)securityToken;
@end

/**
 Auth credential provider require a STS INFO Server URL,also you can customize a decoder block which returns json data.
 
 
 OSSAuthCredentialProvider *acp = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:@"sts_server_url" responseDecoder:^NSData * (NSData * data) {
        // 1.hanle response from server.
 
 // 2.initialize json object from step 1. json object require message like {AccessKeyId:@"xxx",AccessKeySecret:@"xxx",SecurityToken:@"xxx",Expiration:@"xxx"}
 
        // 3.generate jsonData from step 2 and return it.
 }];
 
 */

@interface OSSAuthCredentialProvider : OSSFederationCredentialProvider
@property (nonatomic, copy) NSString * authServerUrl;
@property (nonatomic, copy) NSData * (^responseDecoder)(NSData *);
- (instancetype)initWithAuthServerUrl:(NSString *)authServerUrl;
- (instancetype)initWithAuthServerUrl:(NSString *)authServerUrl responseDecoder:(nullable OSSResponseDecoderBlock)decoder;
@end

/**
 OSSClient side configuration.
 */
@interface OSSClientConfiguration : NSObject

/**
 Max retry count
 */
@property (nonatomic, assign) uint32_t maxRetryCount;

/**
 Max concurrent requests
 */
@property (nonatomic, assign) uint32_t maxConcurrentRequestCount;

/**
 Flag of enabling background file transmit service.
 Note: it's only applicable for file upload.
 */
@property (nonatomic, assign) BOOL enableBackgroundTransmitService;

/**
 Flag of using Http request for DNS resolution.
 */
@property (nonatomic, assign) BOOL isHttpdnsEnable;

/**
Sets the session Id for background file transmission
 */
@property (nonatomic, copy) NSString * backgroundSesseionIdentifier;

/**
 Sets request timeout
 */
@property (nonatomic, assign) NSTimeInterval timeoutIntervalForRequest;

/**
 Sets single object download's max time
 */
@property (nonatomic, assign) NSTimeInterval timeoutIntervalForResource;

/**
 Sets proxy host and port.
 */
@property (nonatomic, copy) NSString * proxyHost;
@property (nonatomic, strong) NSNumber * proxyPort;

/**
 Sets UA
 */
@property (nonatomic, copy) NSString * userAgentMark;

/**
 Sets the flag of using Second Level Domain style to access the endpoint. By default it's false.
 */
@property (nonatomic, assign) BOOL isPathStyleAccessEnable;

/**
 Sets  the flag of using custom path prefix to access the endpoint. By default it's false.
 */
@property (nonatomic, assign) BOOL isCustomPathPrefixEnable;

/**
 Sets CName excluded list.
 */
@property (nonatomic, strong, setter=setCnameExcludeList:) NSArray * cnameExcludeList;

/**
 是否开启crc校验(当同时设置了此选项和请求中的checkCRC开关时，以请求中的checkCRC开关为准)
 */
@property (nonatomic, assign) BOOL crc64Verifiable;

/// Set whether to allow UA to carry system information
@property (nonatomic, assign) BOOL isAllowUACarrySystemInfo;

/// Set whether to allow the redirection with a modified request
@property (nonatomic, assign) BOOL isFollowRedirectsEnable;

/// The maximum number of simultaneous persistent connections per host.
/// The default value is NSURLSessionConfiguration's default value
/// https://developer.apple.com/documentation/foundation/urlsessionconfiguration/1407597-httpmaximumconnectionsperhost
@property (nonatomic, assign) uint32_t HTTPMaximumConnectionsPerHost;

/// Set whether to allow retry attempts when the app switches to the background
@property (nonatomic, assign) BOOL isAllowResetRetryCount;

/// Set whether to allow metric information
@property (nonatomic, assign) BOOL isAllowNetworkMetricInfo;

@property (nonatomic, assign) OSSSignVersion signVersion;

@end

@protocol OSSRequestInterceptor <NSObject>
- (OSSTask *)interceptRequestMessage:(OSSAllRequestNeededMessage *)request;
@end

/**
 Signs the request when it's being created.
 */
@interface OSSSignerInterceptor : NSObject <OSSRequestInterceptor>
@property (nonatomic, strong) id<OSSCredentialProvider> credentialProvider;
@property (nonatomic, assign) OSSSignVersion version;
@property (nonatomic, copy) NSString *region;
@property (nonatomic, copy) NSString *cloudBoxId;

- (instancetype)initWithCredentialProvider:(id<OSSCredentialProvider>)credentialProvider;
@end

/**
 Updates the UA when creating the request.
 */
@interface OSSUASettingInterceptor : NSObject <OSSRequestInterceptor>
@property (nonatomic, weak) OSSClientConfiguration *clientConfiguration;
- (instancetype)initWithClientConfiguration:(OSSClientConfiguration *) clientConfiguration;
@end

/**
 Fixes the time skew issue when creating the request.
 */
@interface OSSTimeSkewedFixingInterceptor : NSObject <OSSRequestInterceptor>
@end

/**
 The download range of OSS object
 */
@interface OSSRange : NSObject
@property (nonatomic, assign) int64_t startPosition;
@property (nonatomic, assign) int64_t endPosition;

- (instancetype)initWithStart:(int64_t)start
                      withEnd:(int64_t)end;

/**
 * Converts the header to string: 'bytes=${start}-${end}'
 */
- (NSString *)toHeaderString;
@end

#pragma mark RequestAndResultClass

/**
 The request to list all buckets of current user.
 */
@interface OSSGetServiceRequest : OSSRequest

/**
 The prefix filter for listing buckets---optional.
 */
@property (nonatomic, copy) NSString * prefix;

/**
 The marker filter for listing buckets----optional.
 The marker filter is to ensure any returned bucket name must be greater than the marker in the lexicographic order.
 */
@property (nonatomic, copy) NSString * marker;

/**
 The max entries to return. By default it's 100 and max value of this property is 1000.
 */
@property (nonatomic, assign) int32_t maxKeys;


@end

/**
 The result class of listing all buckets
 */
@interface OSSGetServiceResult : OSSResult

/**
 The owner Id
 */
@property (nonatomic, copy) NSString * ownerId;

/**
 Bucket owner name---currently it's same as owner Id.
 */
@property (nonatomic, copy) NSString * ownerDispName;

/**
 The prefix of this query. It's only set when there's remaining buckets to return.
 */
@property (nonatomic, copy) NSString * prefix;

/**
 The marker of this query. It's only set when there's remaining buckets to return.
 */
@property (nonatomic, copy) NSString * marker;

/**
 The max buckets to return. It's only set when there's remaining buckets to return.
 */
@property (nonatomic, assign) int32_t maxKeys;

/**
 Flag of the result is truncated. If it's truncated, it means there's remaining buckets to return.
 */
@property (nonatomic, assign) BOOL isTruncated;

/**
 The marker for the next ListBucket call. It's only set when there's remaining buckets to return.
 */
@property (nonatomic, copy) NSString * nextMarker;

/**
 The container of the buckets. It's a dictionary array, in which every element has keys "Name", "CreationDate" and "Location".
 */
@property (nonatomic, strong, nullable) NSArray * buckets;
@end

/**
 The request to create bucket
 */
@interface OSSCreateBucketRequest : OSSRequest

/**
 *  存储空间,命名规范如下:(1)只能包括小写字母、数字和短横线(-);(2)必须以小写字母或者数字开头和结尾;(3)长度必须在3-63字节之间.
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 The bucket location
 For more information about OSS datacenter and endpoint, please check out <a>https://docs.aliyun.com/#/pub/oss/product-documentation/domain-region</a>
 */
@property (nonatomic, copy) NSString * location __attribute__ ((deprecated));

/**
 Sets Bucket access permission. For now there're three permissions:public-read-write，public-read and private. if this key is not set, the default value is private
 */
@property (nonatomic, copy) NSString * xOssACL;

@property (nonatomic, assign) OSSBucketStorageClass storageClass;


- (NSString *)storageClassAsString;

@end

/**
 Result class of bucket creation
 */
@interface OSSCreateBucketResult : OSSResult

/**
 Bucket datacenter
 */
@property (nonatomic, copy) NSString * location;
@end

/**
 The request class of deleting bucket
 */
@interface OSSDeleteBucketRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;
@end

/**
 Result class of deleting bucket
 */
@interface OSSDeleteBucketResult : OSSResult
@end

/**
 The request class of listing objects under a bucket
 */
@interface OSSGetBucketRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 The delimiter is very important and it determines the behavior of common prefix.
 For most cases, use the default '/' as the delimiter. 
 For example, if a bucket has folder 'prefix/' and a file 'abc'. And inside the folder it has file '123.txt'
 If the delimiter is '/', then the ListObject will return a common prefix 'prefix/' and a file 'abc'.
 If the delimiter is something else, then ListObject will return three files: prefix/, abc and prefix/123.txt. No common prefix!.
 */
@property (nonatomic, copy) NSString * delimiter;

/**
 The marker filter for listing objects----optional.
 The marker filter is to ensure any returned object name must be greater than the marker in the lexicographic order.
 */
@property (nonatomic, copy) NSString * marker;

/**
 The max entries count to return. By default it's 100 and it could be up to 1000.
 */
@property (nonatomic, assign) int32_t maxKeys;

/**
 The filter prefix of the objects to return----the returned objects' name must have the prefix.
 */
@property (nonatomic, copy) NSString * prefix;


@end

/**
 The result class of listing objects.
 */
@interface OSSGetBucketResult : OSSResult

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 The prefix of the objects returned----the returned objects must have this prefix.
 */
@property (nonatomic, copy) NSString * prefix;

/**
 The marker filter of the objects returned---all objects returned are greater than this marker in lexicographic order.
 */
@property (nonatomic, copy) NSString * marker;

/**
 The max entries to return. By default it's 100 and it could be up to 1000.
 */
@property (nonatomic, assign) int32_t maxKeys;

/**
 The delimiter to differentiate the folder object and file object.
 For object whose name ends with the delimiter, then it's treated as folder or common prefixes.
 */
@property (nonatomic, copy) NSString * delimiter;

/**
 The maker for the next call. If no more entries to return, it's null.
 */
@property (nonatomic, copy) NSString * nextMarker;

/**
 Flag of truncated result. If it's truncated, it means there's more entries to return.
 */
@property (nonatomic, assign) BOOL isTruncated;

/**
 The dictionary arrary, in which each dictionary has keys of "Key", "LastModified", "ETag", "Type", "Size", "StorageClass" and "Owner".
 */
@property (nonatomic, strong, nullable) NSArray * contents;

/**
 The arrary of common prefixes. Each element is one common prefix.
 */
@property (nonatomic, strong) NSArray * commentPrefixes;
@end

/**
 The request class to get the bucket ACL.
 */
@interface OSSGetBucketACLRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;
@end

/**
 The result class to get the bucket ACL.
 */
@interface OSSGetBucketACLResult : OSSResult

/**
 The bucket ACL. It could be one of the three values: private/public-read/public-read-write.
 */
@property (nonatomic, copy) NSString * aclGranted;
@end

/**
 The request class to get object metadata
 */
@interface OSSHeadObjectRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;
@end

/**
 The result class of getting object metadata.
 */
@interface OSSHeadObjectResult : OSSResult

/**
 Object metadata
 */
@property (nonatomic, copy) NSDictionary * objectMeta;
@end

/**
 The request class to get object
 */
@interface OSSGetObjectRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 OSS Download Range: For example, bytes=0-9 means uploading the first to the tenth's character.
 */
@property (nonatomic, strong, nullable) OSSRange * range;

/**
 The local file path to download to.
 */
@property (nonatomic, strong, nullable) NSURL * downloadToFileURL;

/**
 Image processing configuration.
 */
@property (nonatomic, copy, nullable) NSString * xOssProcess;

/**
 Download progress callback.
 It runs at background thread.
 */
@property (nonatomic, copy, nullable) OSSNetworkingDownloadProgressBlock downloadProgress;

/**
 During the object download, the callback is called upon response is received.
 It runs under background thread (not UI thread)
 */
@property (nonatomic, copy, nullable) OSSNetworkingOnRecieveDataBlock onRecieveData;

/**
 * set request headers
 */
@property (nonatomic, copy, nullable) NSDictionary *headerFields;

@end

/**
 Result class of downloading an object.
 */
@interface OSSGetObjectResult : OSSResult

/**
 The in-memory content of the downloaded object, if the local file path is not specified.
 */
@property (nonatomic, strong, nullable) NSData * downloadedData;

/**
 The object metadata dictionary
 */
@property (nonatomic, copy) NSDictionary * objectMeta;
@end


/**
 The response class to update the object ACL.
 */
@interface OSSPutObjectACLResult : OSSResult
@end

/**
 The request class to upload an object.
 */
@interface OSSPutObjectRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 The in-memory data to upload.
 */
@property (nonatomic, strong, nullable) NSData * uploadingData;

/**
 The local file path to upload.
 */
@property (nonatomic, strong, nullable) NSURL * uploadingFileURL;

/**
 The callback parameters.
 */
@property (nonatomic, copy, nullable) NSDictionary * callbackParam;

/**
 The callback variables.
 */
@property (nonatomic, copy, nullable) NSDictionary * callbackVar;

/**
 The content type.
 */
@property (nonatomic, copy, nullable) NSString * contentType;

/**
 The content's MD5 digest. 
 It's calculated on the request body (not headers) according to RFC 1864 to get the 128 bit digest data.
 Then use base64 encoding on the 128bit result to get this MD5 value.
 This header is for integrity check on the data. And it's recommended to turn on for every body.
 */
@property (nonatomic, copy, nullable) NSString * contentMd5;

/**
 Specifies the download name of the object. Checks out RFC2616 for more details.
 */
@property (nonatomic, copy, nullable) NSString * contentDisposition;

/**
 Specifies the content encoding during the download. Checks out RFC2616 for more details.
 */
@property (nonatomic, copy, nullable) NSString * contentEncoding;

/**
 Specifies the cache behavior during the download. Checks out RFC2616 for more details.
 */
@property (nonatomic, copy, nullable) NSString * cacheControl;

/**
 Expiration time in milliseconds. Checks out RFC2616 for more details.
 */
@property (nonatomic, copy, nullable) NSString * expires;

/**
 The object's metadata.
 When the object is being uploaded, it could be specified with http headers prefixed with x-oss-meta for user metadata.
 The total size of all user metadata cannot be more than 8K. 
 It also could include standard HTTP headers in this object.
 */
@property (nonatomic, copy, nullable) NSDictionary * objectMeta;

/**
 The upload progress callback.
 It runs in background thread (not UI thread).
 */
@property (nonatomic, copy, nullable) OSSNetworkingUploadProgressBlock uploadProgress;

/**
 The upload retry callback.
 It runs in background thread (not UI thread).
 */
@property (nonatomic, copy, nullable) OSSNetworkingRetryBlock uploadRetryCallback;

/**
 * the sha1 of content
 */
@property (nonatomic, copy, nullable) NSString *contentSHA1;
 
@end

/**
 The request class to update the object ACL.
 */
@interface OSSPutObjectACLRequest : OSSPutObjectRequest

/**
 *@brief:指定oss创建object时的访问权限,合法值:public-read、private、public-read-write
 */
@property (nonatomic, copy, nullable) NSString *acl;

@end

/**
 The result class to put an object
 */
@interface OSSPutObjectResult : OSSResult

/**
ETag (entity tag) is the tag during the object creation in OSS server side.
It's the MD5 value for put object request. If the object is created by other APIs, the ETag is the UUID of the content.
 ETag could be used to check if the object has been updated.
 */
@property (nonatomic, copy, nullable) NSString * eTag;

/**
 If the callback is specified, this is the callback response result.
 */
@property (nonatomic, copy, nullable) NSString * serverReturnJsonString;
@end

/**
 * append object request
 */
@interface OSSAppendObjectRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 Specifies which position to append. For a new file, the first append should start from 0. And the subsequential calls will start from the current length of the object.
 For example, if the first append's size is 65536, then the appendPosition value in the next call will be 65536.
 In its response, the header x-oss-next-append-position is included for next call.
 */
@property (nonatomic, assign) int64_t appendPosition;

/**
 The in-memory data to upload from.
 */
@property (nonatomic, strong, nullable) NSData * uploadingData;

/**
 The local file path to upload from.
 */
@property (nonatomic, strong, nullable) NSURL * uploadingFileURL;

/**
 Sets the content type
 */
@property (nonatomic, copy, nullable) NSString * contentType;

/**
 The content's MD5 digest value.
 It's calculated from the MD5 value of the request body according to RFC 1864 and then encoded by base64.
 */
@property (nonatomic, copy, nullable) NSString *contentMd5;

/**
 The object's name during the download according to RFC 2616.
 */
@property (nonatomic, copy, nullable) NSString * contentDisposition;

/**
 The content encoding during the object upload. Checks out RFC2616 for more detail.
 */
@property (nonatomic, copy, nullable) NSString * contentEncoding;

/**
 Specifies the cache control behavior when it's being downloaded.Checks out RFC 2616 for more details.
 */
@property (nonatomic, copy, nullable) NSString * cacheControl;

/**
 Expiration time. Checks out RFC2616 for more information.
 */
@property (nonatomic, copy, nullable) NSString * expires;

/**
 The object's metadata, which start with x-oss-meta-, such as x-oss-meta-location.
 Each request can have multiple metadata as long as the total size of all metadata is no bigger than 8KB.
 It could include standard headers as well.
 */
@property (nonatomic, copy, nullable) NSDictionary * objectMeta;

/**
 Upload progress callback.
 It's called on the background thread.
 */
@property (nonatomic, copy, nullable) OSSNetworkingUploadProgressBlock uploadProgress;

/**
 * the sha1 of content
 */
@property (nonatomic, copy, nullable) NSString *contentSHA1;


@end

/**
 * append object result
 */
@interface OSSAppendObjectResult : OSSResult

/**
 TODOTODO
 ETag (entity tag). It's created for every object when it's created.
 For Objects created by PUT, ETag is the MD5 value of the content data. For others, ETag is the UUID of the content.
 ETag is used for checking data integrity.
 */
@property (nonatomic, copy, nullable) NSString * eTag;

/**
 Specifies the next starting position. It's essentially the current object size.
 This header is included in the successful response or the error response when the start position does not match the object size.
 */
@property (nonatomic, assign, readwrite) int64_t xOssNextAppendPosition;
@end

/**
 The request of deleting an object.
 */
@interface OSSDeleteObjectRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object object
 */
@property (nonatomic, copy) NSString * objectKey;
@end

/**
 Result class of deleting an object
 */
@interface OSSDeleteObjectResult : OSSResult
@end

/**
 Request class of copying an object in OSS.
 */
@interface OSSCopyObjectRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 * Source object's address (the caller needs the read permission on this object)
 */
@property (nonatomic, copy) NSString * sourceCopyFrom DEPRECATED_MSG_ATTRIBUTE("please use sourceBucketName & sourceObjectKey instead!it will be removed in next version.");

@property (nonatomic, copy) NSString * sourceBucketName;

@property (nonatomic, copy) NSString * sourceObjectKey;

/**
 The content type
 */
@property (nonatomic, copy, nullable) NSString * contentType;

/**
 The content's MD5 digest.
 It's calculated according to RFC 1864 and encoded in base64.
 Though it's optional, it's recommended to turn it on for integrity check.
 */
@property (nonatomic, copy, nullable) NSString * contentMd5;

/**
 The user metadata dictionary, which starts with x-oss-meta-. 
 The total size of user metadata can be no more than 8KB.
 It could include standard http headers as well.
 */
@property (nonatomic, copy, nullable) NSDictionary * objectMeta;

/**
 * the sha1 of content
 */
@property (nonatomic, copy, nullable) NSString *contentSHA1;


@end

/**
 The result class of copying an object
 */
@interface OSSCopyObjectResult : OSSResult

/**
 The last modified time
 */
@property (nonatomic, copy, nullable) NSString * lastModifed;

/**
 The ETag of the new object.
 */
@property (nonatomic, copy, nullable) NSString * eTag;
@end

/**
 Request class of initiating a multipart upload.
 */
@interface OSSInitMultipartUploadRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 Content type
 */
@property (nonatomic, copy, nullable) NSString * contentType;

/**
 The object's download name. Checks out RFC 2616 for more details.
 */
@property (nonatomic, copy, nullable) NSString * contentDisposition;

/**
 The content encoding. Checks out RFC 2616.
 */
@property (nonatomic, copy, nullable) NSString * contentEncoding;

/**
 Specifies the cache control behavior when it's downloaded. Checks out RFC 2616 for more details.
 */
@property (nonatomic, copy, nullable) NSString * cacheControl;

/**
 Expiration time in milliseconds. Checks out RFC 2616 for more details.
 */
@property (nonatomic, copy, nullable) NSString * expires;

/**
 The dictionary of object's custom metadata, which starts with x-oss-meta-. 
 The total size of user metadata is no more than 8KB.
 It could include other standard http headers.
 */
@property (nonatomic, copy, nullable) NSDictionary * objectMeta;

/**
 * When Setting this value to YES , parts will be uploaded in order. Default value is NO.
 */
@property (nonatomic, assign) BOOL sequential;

@end

/**
 The resutl class of initiating a multipart upload.
 */
@interface OSSInitMultipartUploadResult : OSSResult

/**
 The upload Id of the multipart upload
 */
@property (nonatomic, copy, nullable) NSString * uploadId;
@end

/**
 The request class of uploading one part.
 */
@interface OSSUploadPartRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectkey;

/**
 Multipart Upload id.
 */
@property (nonatomic, copy) NSString * uploadId;

/**
 The part number of this part.
 */
@property (nonatomic, assign) int partNumber;

/**
 The content MD5 value.
 It's calculated according to RFC 1864 and encoded in base64.
 Though it's optional, it's recommended to turn it on for integrity check.
 */
@property (nonatomic, copy, nullable) NSString * contentMd5;

/**
 The in-memory data to upload from.
 */
@property (nonatomic, strong, nullable) NSData * uploadPartData;

/**
 The local file path to upload from
 */
@property (nonatomic, strong, nullable) NSURL * uploadPartFileURL;

/**
 The upload progress callback.
 It runs in background thread (not UI thread);
 */
@property (nonatomic, copy, nullable) OSSNetworkingUploadProgressBlock uploadPartProgress;

/**
 * the sha1 of content
 */
@property (nonatomic, copy, nullable) NSString *contentSHA1;

@end

/**
 The result class of uploading one part.
 */
@interface OSSUploadPartResult : OSSResult
@property (nonatomic, copy, nullable) NSString * eTag;
@end

/**
 The Part information. It's called by CompleteMultipartUpload().
 */
@interface OSSPartInfo : NSObject<NSCopying>

/**
 The part number in this part upload.
 */
@property (nonatomic, assign) int32_t partNum;

/**
 ETag value of this part returned by OSS.
 */
@property (nonatomic, copy) NSString * eTag;

/**
 The part size.
 */
@property (nonatomic, assign) int64_t size;

@property (nonatomic, assign) uint64_t crc64;

+ (instancetype)partInfoWithPartNum:(int32_t)partNum eTag:(NSString *)eTag size:(int64_t)size __attribute__((deprecated("Use partInfoWithPartNum:eTag:size:crc64: to instead!")));
+ (instancetype)partInfoWithPartNum:(int32_t)partNum eTag:(NSString *)eTag size:(int64_t)size crc64:(uint64_t)crc64;

- (NSDictionary *)entityToDictionary;

@end

/**
 The request class of completing a multipart upload.
 */
@interface OSSCompleteMultipartUploadRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 Multipart upload Id
 */
@property (nonatomic, copy) NSString * uploadId;

/**
 The content MD5 value.
 It's calculated according to RFC 1864 and encoded in base64.
 Though it's optional, it's recommended to turn it on for integrity check. 
 */
@property (nonatomic, copy, nullable) NSString * contentMd5;

/**
 All parts' information.
 */
@property (nonatomic, strong) NSArray * partInfos;

/**
 Server side callback parameter
 */
@property (nonatomic, copy, nullable) NSDictionary * callbackParam;

/**
 Callback variables 
 */
@property (nonatomic, copy, nullable) NSDictionary * callbackVar;

/**
 The metadata header
 */
@property (nonatomic, copy, nullable) NSDictionary * completeMetaHeader;

/**
 * the sha1 of content
 */
@property (nonatomic, copy, nullable) NSString *contentSHA1;

@end

/**
 The resutl class of completing a multipart upload.
 */
@interface OSSCompleteMultipartUploadResult : OSSResult

/**
 The object's URL
 */
@property (nonatomic, copy, nullable) NSString * location;

/**
 ETag (entity tag).
 It's generated when the object is created. 
 */
@property (nonatomic, copy, nullable) NSString * eTag;

/**
 The callback response if the callback is specified.
 The resutl class of initiating a multipart upload.
 */
@property (nonatomic, copy, nullable) NSString * serverReturnJsonString;
@end

/**
 The request class of listing all parts that have been uploaded.
 */
@interface OSSListPartsRequest : OSSRequest

/**
 Bucket name
 The request class of uploading one part.*/
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 The multipart upload Id.
 */
@property (nonatomic, copy) NSString * uploadId;

/**
 The max part count to return
 */
@property (nonatomic, assign) int maxParts;

/**
 The part number marker filter---only parts whose part number is greater than this value will be returned.
 */
@property (nonatomic, assign) int partNumberMarker;
@end

/**
The result class of listing uploaded parts.
*/
@interface OSSListPartsResult : OSSResult

/**
 The next part number marker. If the response does not include all data, this header specifies what's the start point for the next list call.
 */
@property (nonatomic, assign) int nextPartNumberMarker;

/**
 The max parts count to return.
 */
@property (nonatomic, assign) int maxParts;

/**
 Flag of truncated data in the response. If it's true, it means there're more data to come.
 If it's false, it means all data have been returned.
 */
@property (nonatomic, assign) BOOL isTruncated;

/**
 The array of the part information.
 */
@property (nonatomic, strong, nullable) NSArray * parts;
@end

/**
 The request class of listing all multipart uploads.
 */
@interface OSSListMultipartUploadsRequest : OSSRequest
/**
 Bucket name.
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 The delimiter.
 */
@property (nonatomic, copy, nullable) NSString * delimiter;

/**
 The prefix.
 */
@property (nonatomic, copy, nullable) NSString * prefix;

/**
 The max number of uploads.
 */
@property (nonatomic, assign) int32_t maxUploads;

/**
 The key marker filter.
 */
@property (nonatomic, copy, nullable) NSString * keyMarker;

/**
 The upload Id marker.
 */
@property (nonatomic, copy, nullable) NSString * uploadIdMarker;

/**
 The encoding type of the object in the response body.
 */
@property (nonatomic, copy, nullable) NSString * encodingType;

@end

/**
 The result class of listing multipart uploads.
 */
@interface OSSListMultipartUploadsResult : OSSResult
/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 The marker filter of the objects returned---all objects returned are greater than this marker in lexicographic order.
 */
@property (nonatomic, copy, nullable) NSString * keyMarker;

/**
 The delimiter to differentiate the folder object and file object.
 For object whose name ends with the delimiter, then it's treated as folder or common prefixes.
 */
@property (nonatomic, copy, nullable) NSString * delimiter;

/**
 The prefix of the objects returned----the returned objects must have this prefix.
 */
@property (nonatomic, copy, nullable) NSString * prefix;

/**
 The upload Id marker.
 */
@property (nonatomic, copy, nullable) NSString * uploadIdMarker;

/**
 The max entries to return. By default it's 100 and it could be up to 1000.
 */
@property (nonatomic, assign) int32_t maxUploads;

/**
 If not all results are returned this time, the response request includes the NextKeyMarker element to indicate the value of KeyMarker in the next request.
 */
@property (nonatomic, copy, nullable) NSString * nextKeyMarker;

/**
 If not all results are returned this time, the response request includes the NextUploadMarker element to indicate the value of UploadMarker in the next request.
 */
@property (nonatomic, copy, nullable) NSString * nextUploadIdMarker;

/**
 Flag of truncated result. If it's truncated, it means there's more entries to return.
 */
@property (nonatomic, assign) BOOL isTruncated;

@property (nonatomic, strong, nullable) NSArray * uploads;

/**
 The arrary of common prefixes. Each element is one common prefix.
 */
@property (nonatomic, strong, nullable) NSArray * commonPrefixes;
@end

/**
 Request to abort a multipart upload
 */
@interface OSSAbortMultipartUploadRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 The multipart upload Id.
 */
@property (nonatomic, copy) NSString * uploadId;
@end

/**
 The result class of aborting a multipart upload
 */
@interface OSSAbortMultipartUploadResult : OSSResult
@end

/**
 The request class of multipart upload.
 */
@interface OSSMultipartUploadRequest : OSSRequest

/**
 The upload Id
 */
@property (nonatomic, copy, nullable) NSString * uploadId;

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object object
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 The local file path to upload from.
 */
@property (nonatomic, strong) NSURL * uploadingFileURL;

/**
 The part size, minimal value is 100KB.
 */
@property (nonatomic, assign) NSUInteger partSize;

/**
 Upload progress callback.
 It runs at the background thread (not UI thread).
 */
@property (nonatomic, copy, nullable) OSSNetworkingUploadProgressBlock uploadProgress;

/**
 The callback parmeters
 */
@property (nonatomic, copy, nullable) NSDictionary * callbackParam;

/**
 The callback variables
 */
@property (nonatomic, copy, nullable) NSDictionary * callbackVar;

/**
 Content type
 */
@property (nonatomic, copy, nullable) NSString * contentType;

/**
 The metadata header
 */
@property (nonatomic, copy, nullable) NSDictionary * completeMetaHeader;

/**
 * the sha1 of content
 */
@property (nonatomic, copy, nullable) NSString *contentSHA1;

/**
 * the md5 of content
 */
@property (nonatomic, copy, nullable) NSString *md5String;

/// The concurrent number of shard uploads
@property (nonatomic, assign) uint32_t threadNum;

@property (nonatomic, assign) OSSTerminationMode terminationMode;

- (void)cancel;
@end

/**
 The request class of resumable upload.
 */
@interface OSSResumableUploadRequest : OSSMultipartUploadRequest


/**
 directory path about create record uploadId file 
 */
@property (nonatomic, copy, nullable) NSString * recordDirectoryPath;


/**
 need or not delete uploadId with cancel
 */
@property (nonatomic, assign) BOOL deleteUploadIdOnCancelling;

/**
 All running children requests
 */
@property (atomic, weak) OSSRequest * runningChildrenRequest;

@end


/**
 The result class of resumable uploading
 */
@interface OSSResumableUploadResult : OSSResult

/**
 The callback response, if the callback is specified.
 */
@property (nonatomic, copy, nullable) NSString * serverReturnJsonString;

@end


/**
 for more information,Please refer to the link https://help.aliyun.com/document_detail/31989.html
 */
@interface OSSCallBackRequest : OSSRequest

@property (nonatomic, copy) NSString *bucketName;

@property (nonatomic, copy) NSString *objectName;
/**
 The callback parameters.when you set this value,there are required params as below:
 {
    "callbackUrl": xxx
    "callbackBody": xxx
 }
 */
@property (nonatomic, copy) NSDictionary *callbackParam;
/**
 The callback variables.
 */
@property (nonatomic, copy) NSDictionary *callbackVar;

@end



@interface OSSCallBackResult : OSSResult

@property (nonatomic, copy) NSDictionary *serverReturnXML;

/**
 If the callback is specified, this is the callback response result.
 */
@property (nonatomic, copy) NSString *serverReturnJsonString;

@end


/**
 for more information,Please refer to the link https://help.aliyun.com/document_detail/55811.html
 */
@interface OSSImagePersistRequest : OSSRequest

@property (nonatomic, copy) NSString *fromBucket;

@property (nonatomic, copy) NSString *fromObject;

@property (nonatomic, copy) NSString *toBucket;

@property (nonatomic, copy) NSString *toObject;

@property (nonatomic, copy) NSString *action;

@end

@interface OSSImagePersistResult : OSSResult

@end

NS_ASSUME_NONNULL_END
