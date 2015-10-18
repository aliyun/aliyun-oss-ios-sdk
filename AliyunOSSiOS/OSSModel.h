//
//  OSSModel.h
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Bolts/Bolts.h>

@class OSSAllRequestNeededMessage;
@class OSSFederationToken;
@class BFTask;

#ifndef OSSTASK_DEFINED
#define OSSTASK_DEFINED
typedef BFTask OSSTask;
#endif


extern NSString * const OSSListBucketResultXMLTOKEN;
extern NSString * const OSSNameXMLTOKEN;
extern NSString * const OSSDelimiterXMLTOKEN;
extern NSString * const OSSMarkerXMLTOKEN;
extern NSString * const OSSMaxKeyXMLTOKEN;
extern NSString * const OSSIsTruncatedXMLTOKEN;
extern NSString * const OSSContentXMLTOKEN;
extern NSString * const OSSKeyXMLTOKEN;
extern NSString * const OSSLastModifiedXMLTOKEN;
extern NSString * const OSSETagXMLTOKEN;
extern NSString * const OSSTypeXMLTOKEN;
extern NSString * const OSSSizeXMLTOKEN;
extern NSString * const OSSStorageClassXMLTOKEN;
extern NSString * const OSSCommonPrefixesXMLTOKEN;
extern NSString * const OSSPrefixXMLTOKEN;
extern NSString * const OSSUploadIdXMLTOKEN;
extern NSString * const OSSLocationXMLTOKEN;
extern NSString * const OSSNextPartNumberMarkerXMLTOKEN;
extern NSString * const OSSMaxPartsXMLTOKEN;
extern NSString * const OSSPartXMLTOKEN;
extern NSString * const OSSPartNumberXMLTOKEN;

extern NSString * const OSSClientErrorDomain;
extern NSString * const OSSServerErrorDomain;

extern NSString * const OSSErrorMessageTOKEN;

extern NSString * const OSSHttpHeaderContentDisposition;
extern NSString * const OSSHttpHeaderContentEncoding;
extern NSString * const OSSHttpHeaderContentType;
extern NSString * const OSSHttpHeaderContentMD5;
extern NSString * const OSSHttpHeaderCacheControl;
extern NSString * const OSSHttpHeaderExpires;


typedef NS_ENUM(NSInteger, OSSOperationType) {
    OSSOperationTypeCreateBucket,
    OSSOperationTypeDeleteBucket,
    OSSOperationTypeGetBucket,
    OSSOperationTypeHeadObject,
    OSSOperationTypeGetObject,
    OSSOperationTypePutObject,
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
    OSSClientErrorCodeNetworkError
};

typedef void (^OSSNetworkingUploadProgressBlock) (int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend);
typedef void (^OSSNetworkingDownloadProgressBlock) (int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite);
typedef void (^OSSNetworkingCompletionHandlerBlock) (id responseObject, NSError *error);
typedef void (^OSSNetworkingOnRecieveDataBlock) (NSData * data);

typedef NSString * (^OSSCustomSignContentBlock) (NSString * contentToSign, NSError **error);
typedef OSSFederationToken * (^OSSGetFederationTokenBlock) ();

/**
 * extend NSString
 */
@interface NSString (OSS)
- (NSString *)oss_stringByAppendingPathComponentForURL:(NSString *)aString;
@end

/**
 * extend NSDate
 */
@interface NSDate (OSS)
+ (void)oss_setClockSkew:(NSTimeInterval)clockSkew;
+ (NSDate *)oss_dateFromString:(NSString *)string;
+ (NSDate *)oss_clockSkewFixedDate;
- (NSString *)oss_asStringValue;
@end

/**
 * custom sync mutable dictionary
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
 * federation token for oss
 */
@interface OSSFederationToken : NSObject
@property (nonatomic, strong) NSString * tAccessKey;
@property (nonatomic, strong) NSString * tSecretKey;
@property (nonatomic, strong) NSString * tToken;

/* linux time milli second from 1970s(Epoch) which is exactly the time when this token become expired. */
/* it's directly returned from STS server so we don't need to transform it to other format. */
@property (nonatomic, assign) int64_t expirationTimeInMilliSecond;
@end

/**
 * define credential provider protocal
 */
@protocol OSSCredentialProvider <NSObject>
@required
- (NSString *)sign:(NSString *)content error:(NSError **)error;
@end

/**
 * credential provider use plain ak and sk
 */
@interface OSSPlainTextAKSKPairCredentialProvider : NSObject <OSSCredentialProvider>
@property (nonatomic, strong) NSString * accessKey;
@property (nonatomic, strong) NSString * secretKey;

- (instancetype)initWithPlainTextAccessKey:(NSString *)accessKey
                                 secretKey:(NSString *)secretKey;
@end

/**
 * credential provider with user-implemented signer
 */
@interface OSSCustomSignerCredentialProvider : NSObject <OSSCredentialProvider>
@property (nonatomic, copy) NSString * (^signContent)(NSString *, NSError **);

- (instancetype)initWithImplementedSigner:(OSSCustomSignContentBlock)signContent;
@end

/**
 * credential provider by fetching federation token to sign content
 */
@interface OSSFederationCredentialProvider : NSObject <OSSCredentialProvider>
@property (nonatomic, strong) OSSFederationToken * cachedToken;
@property (nonatomic, copy) OSSFederationToken * (^federationTokenGetter)();

- (instancetype)initWithFederationTokenGetter:(OSSGetFederationTokenBlock)federationTokenGetter;

- (OSSFederationToken *)getToken:(NSError **)error;
- (uint64_t)currentTagNumber;
@end

/**
 * configuration for client side
 */
@interface OSSClientConfiguration : NSObject
@property (nonatomic, assign) uint32_t maxRetryCount;
@property (nonatomic, assign) BOOL enableBackgroundTransmitService;
@property (nonatomic, strong) NSString * backgroundSesseionIdentifier;
@property (nonatomic, assign) NSTimeInterval timeoutIntervalForRequest;
@property (nonatomic, assign) NSTimeInterval timeoutIntervalForResource;
@property (nonatomic, strong) NSString * proxyHost;
@property (nonatomic, strong) NSNumber * proxyPort;
@end

/**
 * define interceptor protocal for intercept request message
 */
@protocol OSSRequestInterceptor <NSObject>
- (OSSTask *)interceptRequestMessage:(OSSAllRequestNeededMessage *)request;
@end

/**
 * interceptor to intercept request message for signing
 */
@interface OSSSignerInterceptor : NSObject <OSSRequestInterceptor>
@property (nonatomic, strong) id<OSSCredentialProvider> credentialProvider;

- (instancetype)initWithCredentialProvider:(id<OSSCredentialProvider>)credentialProvider;
@end

/**
 * interceptor to intercept request message for setting UA
 */
@interface OSSUASettingInterceptor : NSObject <OSSRequestInterceptor>
@end

/**
 * interceptor to refresh the date in request header
 */
@interface OSSTimeSkewedFixingInterceptor : NSObject <OSSRequestInterceptor>
@end

/**
 * range
 */
@interface OSSRange : NSObject
@property (nonatomic, assign) int64_t startPosition;
@property (nonatomic, assign) int64_t endPosition;

- (instancetype)initWithStart:(int64_t)start
                      withEnd:(int64_t)end;

/**
 * transform to string as format: 'bytes=${start}-${end}'
 */
- (NSString *)toHeaderString;
@end


#pragma mark RequestAndResultClass

/**
 * based class of request
 */
@interface OSSRequest : NSObject
@property (nonatomic, assign) BOOL isAuthenticationRequired;

- (void)cancel;
@end

/**
 * based class of result
 */
@interface OSSResult : NSObject
@property (nonatomic, assign) NSInteger httpResponseCode;
@property (nonatomic, strong) NSDictionary * httpResponseHeaderFields;
@property (nonatomic, strong) NSString * requestId;
@end

/**
 * create bucket request
 */
@interface OSSCreateBucketRequest : OSSRequest
@property (nonatomic, strong) NSString * bucketName;
@property (nonatomic, strong) NSString * location;
@property (nonatomic, strong) NSString * xOssACL;
@end

/**
 * create bucket result
 */
@interface OSSCreateBucketResult : OSSResult
@property (nonatomic, strong) NSString * location;
@end

/**
 * delete bucket request
 */
@interface OSSDeleteBucketRequest : OSSRequest
@property (nonatomic, strong) NSString * bucketName;
@end

/**
 * delete bucket result
 */
@interface OSSDeleteBucketResult : OSSResult
@end

/**
 * get bucket (list objects)
 */
@interface OSSGetBucketRequest : OSSRequest
@property (nonatomic, strong) NSString * bucketName;
@property (nonatomic, strong) NSString * delimiter;
@property (nonatomic, strong) NSString * marker;
@property (nonatomic, assign) int32_t maxKeys;
@property (nonatomic, strong) NSString * prefix;

- (NSMutableDictionary *)getQueryDict;
@end

/**
 * get bucket (list objects) result
 */
@interface OSSGetBucketResult : OSSResult
@property (nonatomic, strong) NSString * bucketName;
@property (nonatomic, strong) NSString * prefix;
@property (nonatomic, strong) NSString * marker;
@property (nonatomic, assign) int32_t maxKeys;
@property (nonatomic, strong) NSString * delimiter;
@property (nonatomic, assign) BOOL isTruncated;
@property (nonatomic, strong) NSArray * contents;
@property (nonatomic, strong) NSArray * commentPrefixes;
@end

/**
 * head object request
 */
@interface OSSHeadObjectRequest : OSSRequest
@property (nonatomic, strong) NSString * bucketName;
@property (nonatomic, strong) NSString * objectKey;
@end

/**
 * head object result
 */
@interface OSSHeadObjectResult : OSSResult
@property (nonatomic, strong) NSDictionary * objectMeta;
@end

/**
 * get object request
 */
@interface OSSGetObjectRequest : OSSRequest
@property (nonatomic, strong) NSString * bucketName;
@property (nonatomic, strong) NSString * objectKey;
@property (nonatomic, strong) OSSRange * range;
@property (nonatomic, strong) NSURL * downloadToFileURL;
@property (nonatomic, copy) OSSNetworkingDownloadProgressBlock downloadProgress;
@property (nonatomic, copy) OSSNetworkingOnRecieveDataBlock onRecieveData;
@end

/**
 * get object result
 */
@interface OSSGetObjectResult : OSSResult
@property (nonatomic, strong) NSData * downloadedData;
@property (nonatomic, strong) NSDictionary * objectMeta;
@end

/**
 * put object request
 */
@interface OSSPutObjectRequest : OSSRequest
@property (nonatomic, strong) NSString * bucketName;
@property (nonatomic, strong) NSString * objectKey;
@property (nonatomic, strong) NSData * uploadingData;
@property (nonatomic, strong) NSURL * uploadingFileURL;
@property (nonatomic, strong) NSString * contentType;
@property (nonatomic, strong) NSString * contentMd5;
@property (nonatomic, strong) NSString * contentDisposition;
@property (nonatomic, strong) NSString * contentEncoding;
@property (nonatomic, strong) NSString * cacheControl;
@property (nonatomic, strong) NSString * expires;
@property (nonatomic, strong) NSDictionary * objectMeta;
@property (nonatomic, copy) OSSNetworkingUploadProgressBlock uploadProgress;
@end

/**
 * put object result
 */
@interface OSSPutObjectResult : OSSResult
@property (nonatomic, strong) NSString * eTag;
@property (nonatomic, strong) NSString * serverReturnJsonString;
@end

/**
 * append object request
 */
@interface OSSAppendObjectRequest : OSSRequest
@property (nonatomic, strong) NSString * bucketName;
@property (nonatomic, strong) NSString * objectKey;
@property (nonatomic, assign) int64_t appendPosition;
@property (nonatomic, strong) NSData * uploadingData;
@property (nonatomic, strong) NSURL * uploadingFileURL;
@property (nonatomic, strong) NSString * contentType;
@property (nonatomic, strong) NSString * contentMd5;
@property (nonatomic, strong) NSString * contentDisposition;
@property (nonatomic, strong) NSString * contentEncoding;
@property (nonatomic, strong) NSString * cacheControl;
@property (nonatomic, strong) NSString * expires;
@property (nonatomic, strong) NSDictionary * objectMeta;
@property (nonatomic, copy) OSSNetworkingUploadProgressBlock uploadProgress;
@end

/**
 * append object result
 */
@interface OSSAppendObjectResult : OSSResult
@property (nonatomic, strong) NSString * eTag;
@property (nonatomic, assign, readwrite) int64_t xOssNextAppendPosition;
@end

/**
 * delete object request
 */
@interface OSSDeleteObjectRequest : OSSRequest
@property (nonatomic, strong) NSString * bucketName;
@property (nonatomic, strong) NSString * objectKey;
@end

/**
 * delete object result
 */
@interface OSSDeleteObjectResult : OSSResult
@end

/**
 * copy object request
 */
@interface OSSCopyObjectRequest : OSSRequest
@property (nonatomic, strong) NSString * bucketName;
@property (nonatomic, strong) NSString * objectKey;
@property (nonatomic, strong) NSString * sourceCopyFrom;
@property (nonatomic, strong) NSString * contentType;
@property (nonatomic, strong) NSString * contentMd5;
@property (nonatomic, strong) NSDictionary * objectMeta;
@end

/**
 * copy object result
 */
@interface OSSCopyObjectResult : OSSResult
@property (nonatomic, strong) NSString * lastModifed;
@property (nonatomic, strong) NSString * eTag;
@end

/**
 * init multipart upload request
 */
@interface OSSInitMultipartUploadRequest : OSSRequest
@property (nonatomic, strong) NSString * bucketName;
@property (nonatomic, strong) NSString * objectKey;
@property (nonatomic, strong) NSString * contentType;
@property (nonatomic, strong) NSString * contentDisposition;
@property (nonatomic, strong) NSString * contentEncoding;
@property (nonatomic, strong) NSString * cacheControl;
@property (nonatomic, strong) NSString * expires;
@property (nonatomic, strong) NSDictionary * objectMeta;
@end

/**
 * init multipart upload result
 */
@interface OSSInitMultipartUploadResult : OSSResult
@property (nonatomic, strong) NSString * uploadId;
@end

/**
 * upload single part request
 */
@interface OSSUploadPartRequest : OSSRequest
@property (nonatomic, strong) NSString * bucketName;
@property (nonatomic, strong) NSString * objectkey;
@property (nonatomic, strong) NSString * uploadId;
@property (nonatomic, assign) int partNumber;
@property (nonatomic, strong) NSString * contentMd5;
@property (nonatomic, strong) NSData * uploadPartData;
@property (nonatomic, strong) NSURL * uploadPartFileURL;
@property (nonatomic, copy) OSSNetworkingDownloadProgressBlock uploadPartProgress;
@end

/**
 * upload single part result
 */
@interface OSSUploadPartResult : OSSResult
@property (nonatomic, strong) NSString * eTag;
@end

/**
 * part infos of each part which are needed when completing multipart upload
 */
@interface OSSPartInfo : NSObject
@property (nonatomic, assign) int32_t partNum;
@property (nonatomic, strong) NSString * eTag;
@property (nonatomic, assign) int64_t size;

+ (instancetype)partInfoWithPartNum:(int32_t)partNum
                               eTag:(NSString *)eTag
                               size:(int64_t)size;
@end

/**
 * complete multipart upload request
 */
@interface OSSCompleteMultipartUploadRequest : OSSRequest
@property (nonatomic, strong) NSString * bucketName;
@property (nonatomic, strong) NSString * objectKey;
@property (nonatomic, strong) NSString * uploadId;
@property (nonatomic, strong) NSString * contentMd5;
@property (nonatomic, strong) NSArray * partInfos;
@end

/**
 * complete multipart upload result
 */
@interface OSSCompleteMultipartUploadResult : OSSResult
@property (nonatomic, strong) NSString * location;
@property (nonatomic, strong) NSString * eTag;
@end

/**
 * list multipart upload part request
 */
@interface OSSListPartsRequest : OSSRequest
@property (nonatomic, strong) NSString * bucketName;
@property (nonatomic, strong) NSString * objectKey;
@property (nonatomic, strong) NSString * uploadId;
@property (nonatomic, assign) int maxParts;
@property (nonatomic, assign) int partNumberMarker;
@end

/**
 * list multipart upload part result
 */
@interface OSSListPartsResult : OSSResult
@property (nonatomic, assign) int nextPartNumberMarker;
@property (nonatomic, assign) int maxParts;
@property (nonatomic, assign) BOOL isTruncate;
@property (nonatomic, strong) NSArray * parts;
@end

/**
 * abort multipart upload request
 */
@interface OSSAbortMultipartUploadRequest : OSSRequest
@property (nonatomic, strong) NSString * bucketName;
@property (nonatomic, strong) NSString * objectKey;
@property (nonatomic, strong) NSString * uploadId;
@end

/**
 * abort multipart upload result
 */
@interface OSSAbortMultipartUploadResult : OSSResult
@end

/**
 * parse http response to result class
 */
@interface OSSHttpResponseParser : NSObject
@property (nonatomic, strong) NSURL * downloadingFileURL;
@property (nonatomic, copy) OSSNetworkingOnRecieveDataBlock onRecieveBlock;

- (instancetype)initForOperationType:(OSSOperationType)operationType;
- (void)consumeHttpResponse:(NSHTTPURLResponse *)response;
- (OSSTask *)consumeHttpResponseBody:(NSData *)data;
- (id)constructResultObject;
- (void)reset;
@end