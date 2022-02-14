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
@end

/**
 CredentialProvider protocol, needs to implement sign API.
 */
@protocol OSSCredentialProvider <NSObject>
@optional
- (nullable NSString *)sign:(NSString *)content error:(NSError **)error;
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

#pragma mark RequestAndResultClass

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
@property (nonatomic, strong) NSData * uploadingData;

/**
 The local file path to upload.
 */
@property (nonatomic, strong) NSURL * uploadingFileURL;

/**
 The callback parameters.
 */
@property (nonatomic, copy) NSDictionary * callbackParam;

/**
 The callback variables.
 */
@property (nonatomic, copy) NSDictionary * callbackVar;

/**
 The content type.
 */
@property (nonatomic, copy) NSString * contentType;

/**
 The content's MD5 digest.
 It's calculated on the request body (not headers) according to RFC 1864 to get the 128 bit digest data.
 Then use base64 encoding on the 128bit result to get this MD5 value.
 This header is for integrity check on the data. And it's recommended to turn on for every body.
 */
@property (nonatomic, copy) NSString * contentMd5;

/**
 Specifies the download name of the object. Checks out RFC2616 for more details.
 */
@property (nonatomic, copy) NSString * contentDisposition;

/**
 Specifies the content encoding during the download. Checks out RFC2616 for more details.
 */
@property (nonatomic, copy) NSString * contentEncoding;

/**
 Specifies the cache behavior during the download. Checks out RFC2616 for more details.
 */
@property (nonatomic, copy) NSString * cacheControl;

/**
 Expiration time in milliseconds. Checks out RFC2616 for more details.
 */
@property (nonatomic, copy) NSString * expires;

/**
 The object's metadata.
 When the object is being uploaded, it could be specified with http headers prefixed with x-oss-meta for user metadata.
 The total size of all user metadata cannot be more than 8K.
 It also could include standard HTTP headers in this object.
 */
@property (nonatomic, copy) NSDictionary * objectMeta;

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

/**
 * the sha1 of content
 */
@property (nonatomic, copy) NSString *contentSHA1;
 
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
@property (nonatomic, copy) NSString * eTag;

/**
 If the callback is specified, this is the callback response result.
 */
@property (nonatomic, copy) NSString * serverReturnJsonString;
@end


NS_ASSUME_NONNULL_END
