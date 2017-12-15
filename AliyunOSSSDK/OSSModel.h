//
//  OSSModel.h
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@class OSSAllRequestNeededMessage;
@class OSSFederationToken;
@class OSSTask;
@class OSSClientConfiguration;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OSSOperationType) {
    OSSOperationTypeGetService,
    OSSOperationTypeCreateBucket,
    OSSOperationTypeDeleteBucket,
    OSSOperationTypeGetBucket,
    OSSOperationTypeGetBucketACL,
    OSSOperationTypeHeadObject,
    OSSOperationTypeGetObject,
    OSSOperationTypePutObject,
    OSSOperationTypePutObjectACL,
    OSSOperationTypeAppendObject,
    OSSOperationTypeDeleteObject,
    OSSOperationTypeCopyObject,
    OSSOperationTypeInitMultipartUpload,
    OSSOperationTypeUploadPart,
    OSSOperationTypeCompleteMultipartUpload,
    OSSOperationTypeAbortMultipartUpload,
    OSSOperationTypeListMultipart
};

typedef NS_ENUM(NSInteger, OSSClientErrorCODE) {
    OSSClientErrorCodeNetworkingFailWithResponseCode0,
    OSSClientErrorCodeSignFailed,
    OSSClientErrorCodeFileCantWrite,
    OSSClientErrorCodeInvalidArgument,
    OSSClientErrorCodeNilUploadid,
    OSSClientErrorCodeTaskCancelled,
    OSSClientErrorCodeNetworkError,
    OSSClientErrorCodeInvalidCRC,
    OSSClientErrorCodeCannotResumeUpload,
    OSSClientErrorCodeExcpetionCatched,
    OSSClientErrorCodeNotKnown
};

typedef NS_ENUM(NSUInteger, OSSRequestCRCFlag) {
    OSSRequestCRCUninitialized,
    OSSRequestCRCOpen,
    OSSRequestCRCClosed
};

typedef void (^OSSNetworkingUploadProgressBlock) (int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend);
typedef void (^OSSNetworkingDownloadProgressBlock) (int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite);
typedef void (^OSSNetworkingRetryBlock) (void);
typedef void (^OSSNetworkingCompletionHandlerBlock) (id _Nullable responseObject, NSError * _Nullable error);
typedef void (^OSSNetworkingOnRecieveDataBlock) (NSData * data);

typedef NSString* _Nullable (^OSSCustomSignContentBlock) (NSString * contentToSign, NSError **error);
typedef OSSFederationToken * _Nullable (^OSSGetFederationTokenBlock) (void);
typedef NSData * _Nullable (^OSSResponseDecoderBlock) (NSData * data);

/**
 Categories NSDictionary
 */
@interface NSDictionary (OSS)
- (NSString *)base64JsonString;
@end

/**
 Categories NSDate
 */
@interface NSDate (OSS)
+ (void)oss_setClockSkew:(NSTimeInterval)clockSkew;
+ (NSDate *)oss_dateFromString:(NSString *)string;
+ (NSDate *)oss_clockSkewFixedDate;
- (NSString *)oss_asStringValue;
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
@end

/**
 FederationToken class
 */
@interface OSSFederationToken : NSObject
@property (nonatomic, strong) NSString * tAccessKey;
@property (nonatomic, strong) NSString * tSecretKey;
@property (nonatomic, strong) NSString * tToken;

/**
 Token's expiration time in milliseconds of the unix time.
 */
@property (atomic, assign) int64_t expirationTimeInMilliSecond;

/**
 Token's expiration time in GMT format string.
 */
@property (atomic, strong, nullable) NSString *expirationTimeInGMTFormat;
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

@interface OSSPlainTextAKSKPairCredentialProvider : NSObject <OSSCredentialProvider>
@property (nonatomic, strong) NSString * accessKey;
@property (nonatomic, strong) NSString * secretKey;

- (instancetype)initWithPlainTextAccessKey:(nonnull NSString *)accessKey
                                 secretKey:(nonnull NSString *)secretKey __attribute__((deprecated("We recommend the STS authentication mode on mobile")));
@end

/**
TODOTODO
 The custom signed credential provider
 */
@interface OSSCustomSignerCredentialProvider : NSObject <OSSCredentialProvider>
@property (nonatomic, copy, readonly,) NSString * _Nonnull (^ _Nonnull signContent)( NSString * _Nonnull , NSError * _Nullable *_Nullable);

+ (instancetype _Nullable)new NS_UNAVAILABLE;
- (instancetype _Nullable)init NS_UNAVAILABLE;

/**
 * During the task execution, this API is called for signing
 * It's executed at the background thread instead of UI thread.
 */
- (instancetype _Nullable)initWithImplementedSigner:(nonnull OSSCustomSignContentBlock)signContent NS_DESIGNATED_INITIALIZER;
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
@property (nonatomic, strong) NSString * accessKeyId;
@property (nonatomic, strong) NSString * secretKeyId;
@property (nonatomic, strong) NSString * securityToken;

- (OSSFederationToken *)getToken;
- (instancetype)initWithAccessKeyId:(NSString *)accessKeyId
                        secretKeyId:(NSString *)secretKeyId
                      securityToken:(NSString *)securityToken;
@end

/**
 auth credential provider.
 */
@interface OSSAuthCredentialProvider : OSSFederationCredentialProvider
@property (nonatomic, strong) NSString * authServerUrl;
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
@property (nonatomic, strong) NSString * backgroundSesseionIdentifier;

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
@property (nonatomic, strong) NSString * proxyHost;
@property (nonatomic, strong) NSNumber * proxyPort;

/**
 Sets UA
 */
@property (nonatomic, strong) NSString * userAgentMark;

/**
 Sets CName excluded list.
 */
@property (nonatomic, strong, setter=setCnameExcludeList:) NSArray * cnameExcludeList;

/**
 是否开启crc校验(当同时设置了此选项和请求中的checkCRC开关时，以请求中的checkCRC开关为准)
 */
@property (nonatomic, assign) BOOL crc64Verifiable;

@end

@protocol OSSRequestInterceptor <NSObject>
- (OSSTask *)interceptRequestMessage:(OSSAllRequestNeededMessage *)request;
@end

/**
 Signs the request when it's being created.
 */
@interface OSSSignerInterceptor : NSObject <OSSRequestInterceptor>
@property (nonatomic, strong) id<OSSCredentialProvider> credentialProvider;

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
 The base class of request to OSS.
 */
@interface OSSRequest : NSObject
/**
 Flag of requiring authentication. It's per each request.
 */
@property (nonatomic, assign) BOOL isAuthenticationRequired;

/**
 Flag of request canceled.
 */
@property (nonatomic, assign) BOOL isCancelled;

/**
 开启crc校验的标志位(默认值0代表未设置,此时会以clientConfiguration中的开关为准,1代表开启crc64
 验证,2代表关闭crc64的验证。
 */
@property (nonatomic, assign) OSSRequestCRCFlag crcFlag;

/**
 Cancels the request
 */
- (void)cancel;
@end

/**
 The base class of result from OSS.
 */
@interface OSSResult : NSObject

/**
 The http response code.
 */
@property (nonatomic, assign) NSInteger httpResponseCode;

/**
 The http headers, in the form of key value dictionary.
 */
@property (nonatomic, strong) NSDictionary * httpResponseHeaderFields;

/**
The request Id. It's the value of header x-oss-request-id, which is created from OSS server.
It's a unique Id represents this request. This is used for troubleshooting when you contact OSS support.
 */
@property (nonatomic, strong) NSString * requestId;

/**
 It's the value of header x-oss-hash-crc64ecma, which is created from OSS server.
 */
@property (nonatomic, copy) NSString *remoteCRC64ecma;

/**
 It's the value of local Data.
 */
@property (nonatomic, copy) NSString *localCRC64ecma;

@end

/**
 The request to list all buckets of current user.
 */
@interface OSSGetServiceRequest : OSSRequest

/**
 The prefix filter for listing buckets---optional.
 */
@property (nonatomic, strong) NSString * prefix;

/**
 The marker filter for listing buckets----optional.
 The marker filter is to ensure any returned bucket name must be greater than the marker in the lexicographic order.
 */
@property (nonatomic, strong) NSString * marker;

/**
 The max entries to return. By default it's 100 and max value of this property is 1000.
 */
@property (nonatomic, assign) int32_t maxKeys;


/**
 Gets the query parameters' dictionary according to the properties.
 */
- (NSMutableDictionary *)getQueryDict;
@end

/**
 The result class of listing all buckets
 */
@interface OSSGetServiceResult : OSSResult

/**
 The owner Id
 */
@property (nonatomic, strong) NSString * ownerId;

/**
 Bucket owner name---currently it's same as owner Id.
 */
@property (nonatomic, strong) NSString * ownerDispName;

/**
 The prefix of this query. It's only set when there's remaining buckets to return.
 */
@property (nonatomic, strong) NSString * prefix;

/**
 The marker of this query. It's only set when there's remaining buckets to return.
 */
@property (nonatomic, strong) NSString * marker;

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
@property (nonatomic, strong) NSString * nextMarker;

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
@property (nonatomic, strong) NSString * bucketName;

/**
 The bucket location
 For more information about OSS datacenter and endpoint, please check out <a>https://docs.aliyun.com/#/pub/oss/product-documentation/domain-region</a>
 */
@property (nonatomic, strong) NSString * location __attribute__ ((deprecated));

/**
 Sets Bucket access permission. For now there're three permissions:public-read-write，public-read and private. if this key is not set, the default value is private
 */
@property (nonatomic, strong) NSString * xOssACL;

@end

/**
 Result class of bucket creation
 */
@interface OSSCreateBucketResult : OSSResult

/**
 Bucket datacenter
 */
@property (nonatomic, strong) NSString * location;
@end

/**
 The request class of deleting bucket
 */
@interface OSSDeleteBucketRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, strong) NSString * bucketName;
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
@property (nonatomic, strong) NSString * bucketName;

/**
 The delimiter is very important and it determines the behavior of common prefix.
 For most cases, use the default '/' as the delimiter. 
 For example, if a bucket has folder 'prefix/' and a file 'abc'. And inside the folder it has file '123.txt'
 If the delimiter is '/', then the ListObject will return a common prefix 'prefix/' and a file 'abc'.
 If the delimiter is something else, then ListObject will return three files: prefix/, abc and prefix/123.txt. No common prefix!.
 */
@property (nonatomic, strong) NSString * delimiter;

/**
 The marker filter for listing objects----optional.
 The marker filter is to ensure any returned object name must be greater than the marker in the lexicographic order.
 */
@property (nonatomic, strong) NSString * marker;

/**
 The max entries count to return. By default it's 100 and it could be up to 1000.
 */
@property (nonatomic, assign) int32_t maxKeys;

/**
 The filter prefix of the objects to return----the returned objects' name must have the prefix.
 */
@property (nonatomic, strong) NSString * prefix;

/**
 Generates the query parameter dictionary according to the properties.
 */
- (NSMutableDictionary *)getQueryDict;
@end

/**
 The result class of listing objects.
 */
@interface OSSGetBucketResult : OSSResult

/**
 Bucket name
 */
@property (nonatomic, strong) NSString * bucketName;

/**
 The prefix of the objects returned----the returned objects must have this prefix.
 */
@property (nonatomic, strong) NSString * prefix;

/**
 The marker filter of the objects returned---all objects returned are greater than this marker in lexicographic order.
 */
@property (nonatomic, strong) NSString * marker;

/**
 The max entries to return. By default it's 100 and it could be up to 1000.
 */
@property (nonatomic, assign) int32_t maxKeys;

/**
 The delimiter to differentiate the folder object and file object.
 For object whose name ends with the delimiter, then it's treated as folder or common prefixes.
 */
@property (nonatomic, strong) NSString * delimiter;

/**
 The maker for the next call. If no more entries to return, it's null.
 */
@property (nonatomic, strong) NSString * nextMarker;

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
@property (nonatomic, strong) NSString * bucketName;
@end

/**
 The result class to get the bucket ACL.
 */
@interface OSSGetBucketACLResult : OSSResult

/**
 The bucket ACL. It could be one of the three values: private/public-read/public-read-write.
 */
@property (nonatomic, strong) NSString * aclGranted;
@end

/**
 The request class to get object metadata
 */
@interface OSSHeadObjectRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, strong) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, strong) NSString * objectKey;
@end

/**
 The result class of getting object metadata.
 */
@interface OSSHeadObjectResult : OSSResult

/**
 Object metadata
 */
@property (nonatomic, strong) NSDictionary * objectMeta;
@end

/**
 The request class to get object
 */
@interface OSSGetObjectRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, strong) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, strong) NSString * objectKey;

/**
 OSS Download Range: For example, bytes=0-9 means uploading the first to the tenth's character.
 */
@property (nonatomic, strong) OSSRange * range;

/**
 The local file path to download to.
 */
@property (nonatomic, strong) NSURL * downloadToFileURL;

/**
 Image processing configuration.
 */
@property (nonatomic, strong) NSString * xOssProcess;

/**
 Download progress callback.
 It runs at background thread.
 */
@property (nonatomic, copy) OSSNetworkingDownloadProgressBlock downloadProgress;

/**
 During the object download, the callback is called upon response is received.
 It runs under background thread (not UI thread)
 */
@property (nonatomic, copy) OSSNetworkingOnRecieveDataBlock onRecieveData;
@end

/**
 Result class of downloading an object.
 */
@interface OSSGetObjectResult : OSSResult

/**
 The in-memory content of the downloaded object, if the local file path is not specified.
 */
@property (nonatomic, strong) NSData * downloadedData;

/**
 The object metadata dictionary
 */
@property (nonatomic, strong) NSDictionary * objectMeta;
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
@property (nonatomic, strong) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, strong) NSString * objectKey;

/**
 The in-memory data to upload.
 */
@property (nonatomic, strong) NSData * uploadingData;

/**
 The local file path to upload.
 */
@property (nonatomic, strong) NSURL * uploadingFileURL;

/**
 The callback parameters.
 */
@property (nonatomic, strong) NSDictionary * callbackParam;

/**
 The callback variables.
 */
@property (nonatomic, strong) NSDictionary * callbackVar;

/**
 The content type.
 */
@property (nonatomic, strong) NSString * contentType;

/**
 The content's MD5 digest. 
 It's calculated on the request body (not headers) according to RFC 1864 to get the 128 bit digest data.
 Then use base64 encoding on the 128bit result to get this MD5 value.
 This header is for integrity check on the data. And it's recommended to turn on for every body.
 */
@property (nonatomic, strong) NSString * contentMd5;

/**
 Specifies the download name of the object. Checks out RFC2616 for more details.
 */
@property (nonatomic, strong) NSString * contentDisposition;

/**
 Specifies the content encoding during the download. Checks out RFC2616 for more details.
 */
@property (nonatomic, strong) NSString * contentEncoding;

/**
 Specifies the cache behavior during the download. Checks out RFC2616 for more details.
 */
@property (nonatomic, strong) NSString * cacheControl;

/**
 Expiration time in milliseconds. Checks out RFC2616 for more details.
 */
@property (nonatomic, strong) NSString * expires;

/**
 The object's metadata.
 When the object is being uploaded, it could be specified with http headers prefixed with x-oss-meta for user metadata.
 The total size of all user metadata cannot be more than 8K. 
 It also could include standard HTTP headers in this object.
 */
@property (nonatomic, strong) NSDictionary * objectMeta;

/**
 The upload progress callback.
 It runs in background thread (not UI thread).
 */
@property (nonatomic, copy) OSSNetworkingUploadProgressBlock uploadProgress;

/**
 The upload retry callback.
 It runs in background thread (not UI thread).
 */
@property (nonatomic, copy) OSSNetworkingRetryBlock uploadRetryCallback;
 
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
@property (nonatomic, strong) NSString * eTag;

/**
 If the callback is specified, this is the callback response result.
 */
@property (nonatomic, strong) NSString * serverReturnJsonString;
@end

/**
 * append object request
 */
@interface OSSAppendObjectRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, strong) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, strong) NSString * objectKey;

/**
 Specifies which position to append. For a new file, the first append should start from 0. And the subsequential calls will start from the current length of the object.
 For example, if the first append's size is 65536, then the appendPosition value in the next call will be 65536.
 In its response, the header x-oss-next-append-position is included for next call.
 */
@property (nonatomic, assign) int64_t appendPosition;

/**
 The in-memory data to upload from.
 */
@property (nonatomic, strong) NSData * uploadingData;

/**
 The local file path to upload from.
 */
@property (nonatomic, strong) NSURL * uploadingFileURL;

/**
 Sets the content type
 */
@property (nonatomic, strong) NSString * contentType;

/**
 The content's MD5 digest value.
 It's calculated from the MD5 value of the request body according to RFC 1864 and then encoded by base64.
 */
@property (nonatomic, strong) NSString *contentMd5;

/**
 The object's name during the download according to RFC 2616.
 */
@property (nonatomic, strong) NSString * contentDisposition;

/**
 The content encoding during the object upload. Checks out RFC2616 for more detail.
 */
@property (nonatomic, strong) NSString * contentEncoding;

/**
 Specifies the cache control behavior when it's being downloaded.Checks out RFC 2616 for more details.
 */
@property (nonatomic, strong) NSString * cacheControl;

/**
 Expiration time. Checks out RFC2616 for more information.
 */
@property (nonatomic, strong) NSString * expires;

/**
 The object's metadata, which start with x-oss-meta-, such as x-oss-meta-location.
 Each request can have multiple metadata as long as the total size of all metadata is no bigger than 8KB.
 It could include standard headers as well.
 */
@property (nonatomic, strong) NSDictionary * objectMeta;

/**
 Upload progress callback.
 It's called on the background thread.
 */
@property (nonatomic, copy) OSSNetworkingUploadProgressBlock uploadProgress;
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
@property (nonatomic, strong) NSString * eTag;

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
@property (nonatomic, strong) NSString * bucketName;

/**
 Object object
 */
@property (nonatomic, strong) NSString * objectKey;
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
@property (nonatomic, strong) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, strong) NSString * objectKey;

/**
 Source object's address (the caller needs the read permission on this object)
 */
@property (nonatomic, strong) NSString * sourceCopyFrom;

/**
 The content type
 */
@property (nonatomic, strong) NSString * contentType;

/**
 The content's MD5 digest.
 It's calculated according to RFC 1864 and encoded in base64.
 Though it's optional, it's recommended to turn it on for integrity check.
 */
@property (nonatomic, strong) NSString * contentMd5;

/**
 The user metadata dictionary, which starts with x-oss-meta-. 
 The total size of user metadata can be no more than 8KB.
 It could include standard http headers as well.
 */
@property (nonatomic, strong) NSDictionary * objectMeta;
@end

/**
 The result class of copying an object
 */
@interface OSSCopyObjectResult : OSSResult

/**
 The last modified time
 */
@property (nonatomic, strong) NSString * lastModifed;

/**
 The ETag of the new object.
 */
@property (nonatomic, strong) NSString * eTag;
@end

/**
 Request class of initiating a multipart upload.
 */
@interface OSSInitMultipartUploadRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, strong) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, strong) NSString * objectKey;

/**
 Content type
 */
@property (nonatomic, strong) NSString * contentType;

/**
 The object's download name. Checks out RFC 2616 for more details.
 */
@property (nonatomic, strong) NSString * contentDisposition;

/**
 The content encoding. Checks out RFC 2616.
 */
@property (nonatomic, strong) NSString * contentEncoding;

/**
 Specifies the cache control behavior when it's downloaded. Checks out RFC 2616 for more details.
 */
@property (nonatomic, strong) NSString * cacheControl;

/**
 Expiration time in milliseconds. Checks out RFC 2616 for more details.
 */
@property (nonatomic, strong) NSString * expires;

/**
 The dictionary of object's custom metadata, which starts with x-oss-meta-. 
 The total size of user metadata is no more than 8KB.
 It could include other standard http headers.
 */
@property (nonatomic, strong) NSDictionary * objectMeta;
@end

/**
 The resutl class of initiating a multipart upload.
 */
@interface OSSInitMultipartUploadResult : OSSResult

/**
 The upload Id of the multipart upload
 */
@property (nonatomic, strong) NSString * uploadId;
@end

/**
 The request class of uploading one part.
 */
@interface OSSUploadPartRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, strong) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, strong) NSString * objectkey;

/**
 Multipart Upload id.
 */
@property (nonatomic, strong) NSString * uploadId;

/**
 The part number of this part.
 */
@property (nonatomic, assign) int partNumber;

/**
 The content MD5 value.
 It's calculated according to RFC 1864 and encoded in base64.
 Though it's optional, it's recommended to turn it on for integrity check.
 */
@property (nonatomic, strong) NSString * contentMd5;

/**
 The in-memory data to upload from.
 */
@property (nonatomic, strong) NSData * uploadPartData;

/**
 The local file path to upload from
 */
@property (nonatomic, strong) NSURL * uploadPartFileURL;

/**
 The upload progress callback.
 It runs in background thread (not UI thread);
 */
@property (nonatomic, copy) OSSNetworkingUploadProgressBlock uploadPartProgress;
@end

/**
 The result class of uploading one part.
 */
@interface OSSUploadPartResult : OSSResult
@property (nonatomic, strong) NSString * eTag;
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
@property (nonatomic, strong) NSString * eTag;

/**
 The part size.
 */
@property (nonatomic, assign) int64_t size;

@property (nonatomic, assign) uint64_t crc64;

+ (instancetype)partInfoWithPartNum:(int32_t)partNum eTag:(NSString *)eTag size:(int64_t)size __attribute__((deprecated("Use partInfoWithPartNum:eTag:size:crc64: to instead!")));
+ (instancetype)partInfoWithPartNum:(int32_t)partNum eTag:(NSString *)eTag size:(int64_t)size crc64:(uint64_t)crc64;

- (nonnull NSDictionary *)entityToDictionary;

@end

/**
 The request class of completing a multipart upload.
 */
@interface OSSCompleteMultipartUploadRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, strong) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, strong) NSString * objectKey;

/**
 Multipart upload Id
 */
@property (nonatomic, strong) NSString * uploadId;

/**
 The content MD5 value.
 It's calculated according to RFC 1864 and encoded in base64.
 Though it's optional, it's recommended to turn it on for integrity check. 
 */
@property (nonatomic, strong) NSString * contentMd5;

/**
 All parts' information.
 */
@property (nonatomic, strong) NSArray * partInfos;

/**
 Server side callback parameter
 */
@property (nonatomic, strong) NSDictionary * callbackParam;

/**
 Callback variables 
 */
@property (nonatomic, strong) NSDictionary * callbackVar;

/**
 The metadata header
 */
@property (nonatomic, strong) NSDictionary * completeMetaHeader;
@end

/**
 The resutl class of completing a multipart upload.
 */
@interface OSSCompleteMultipartUploadResult : OSSResult

/**
 The object's URL
 */
@property (nonatomic, strong) NSString * location;

/**
 ETag (entity tag).
 It's generated when the object is created. 
 */
@property (nonatomic, strong) NSString * eTag;

/**
 The callback response if the callback is specified.
 The resutl class of initiating a multipart upload.
 */
@property (nonatomic, strong) NSString * serverReturnJsonString;
@end

/**
 The request class of listing all parts that have been uploaded.
 */
@interface OSSListPartsRequest : OSSRequest

/**
 Bucket name
 The request class of uploading one part.*/
@property (nonatomic, strong) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, strong) NSString * objectKey;

/**
 The multipart upload Id.
 */
@property (nonatomic, strong) NSString * uploadId;

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
 Request to abort a multipart upload
 */
@interface OSSAbortMultipartUploadRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, strong) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, strong) NSString * objectKey;

/**
 The multipart upload Id.
 */
@property (nonatomic, strong) NSString * uploadId;
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
@property (nonatomic, strong) NSString * uploadId;

/**
 Bucket name
 */
@property (nonatomic, strong) NSString * bucketName;

/**
 Object object
 */
@property (nonatomic, strong) NSString * objectKey;

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
@property (nonatomic, copy) OSSNetworkingUploadProgressBlock uploadProgress;

/**
 The callback parmeters
 */
@property (nonatomic, strong) NSDictionary * callbackParam;

/**
 The callback variables
 */
@property (nonatomic, strong) NSDictionary * callbackVar;

/**
 Content type
 */
@property (nonatomic, strong) NSString * contentType;

/**
 The metadata header
 */
@property (nonatomic, strong) NSDictionary * completeMetaHeader;


- (void)cancel;
@end

/**
 The request class of resumable upload.
 */
@interface OSSResumableUploadRequest : OSSMultipartUploadRequest


/**
 directory path about create record uploadId file 
 */
@property (nonatomic, strong) NSString * recordDirectoryPath;


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
@property (nonatomic, strong) NSString * serverReturnJsonString;
@end

#pragma mark Others

/**
 HTTP response parser
 */
@interface OSSHttpResponseParser : NSObject
@property (nonatomic, strong) NSURL * downloadingFileURL;
@property (nonatomic, copy) OSSNetworkingOnRecieveDataBlock onRecieveBlock;
/** 是否开启crc64校验 */
@property (nonatomic, assign) BOOL crc64Verifiable;

- (instancetype)initForOperationType:(OSSOperationType)operationType;
- (void)consumeHttpResponse:(NSHTTPURLResponse *)response;
- (OSSTask *)consumeHttpResponseBody:(NSData *)data;
- (nullable id)constructResultObject;
- (void)reset;
@end

NS_ASSUME_NONNULL_END
