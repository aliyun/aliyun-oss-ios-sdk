//
//  OSSClient.m
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import "OSSClient.h"
#import "OSSDefine.h"
#import "OSSModel.h"
#import "OSSUtil.h"
#import "OSSLog.h"
#import "OSSBolts.h"
#import "OSSNetworking.h"
#import "OSSXMLDictionary.h"
#import "OSSReachabilityManager.h"
#import "NSMutableData+OSS_CRC.h"

static NSString * const oss_partInfos_storage_name = @"oss_partInfos_storage_name";
static NSString * const oss_record_info_suffix_with_crc = @"-crc64";
static NSString * const oss_record_info_suffix_with_sequential = @"-sequential";
static NSUInteger const oss_multipart_max_part_number = 5000;   //max part number

/**
 * extend OSSRequest to include the ref to networking request object
 */
@interface OSSRequest ()
@property (nonatomic, strong) OSSNetworkingRequestDelegate * requestDelegate;
@end



@implementation OSSClient

static NSObject * lock;

- (instancetype)initWithEndpoint:(NSString *)endpoint credentialProvider:(id<OSSCredentialProvider>)credentialProvider {
    return [self initWithEndpoint:endpoint credentialProvider:credentialProvider clientConfiguration:[OSSClientConfiguration new]];
}

- (instancetype)initWithEndpoint:(NSString *)endpoint
              credentialProvider:(id<OSSCredentialProvider>)credentialProvider
             clientConfiguration:(OSSClientConfiguration *)conf {
    if (self = [super init]) {
        lock = [NSObject new];
        // Monitor the network. If the network type is changed, recheck the IPv6 status.
        [OSSReachabilityManager shareInstance];

        NSOperationQueue * queue = [NSOperationQueue new];
        // using for resumable upload and compat old interface
        queue.maxConcurrentOperationCount = 3;
        _ossOperationExecutor = [OSSExecutor executorWithOperationQueue:queue];
        if ([endpoint rangeOfString:@"://"].location == NSNotFound) {
            endpoint = [@"https://" stringByAppendingString:endpoint];
        }
        self.endpoint = [endpoint oss_trim];
        self.credentialProvider = credentialProvider;
        self.clientConfiguration = conf;

        OSSNetworkingConfiguration * netConf = [OSSNetworkingConfiguration new];
        if (conf) {
            netConf.maxRetryCount = conf.maxRetryCount;
            netConf.timeoutIntervalForRequest = conf.timeoutIntervalForRequest;
            netConf.timeoutIntervalForResource = conf.timeoutIntervalForResource;
            netConf.enableBackgroundTransmitService = conf.enableBackgroundTransmitService;
            netConf.backgroundSessionIdentifier = conf.backgroundSesseionIdentifier;
            netConf.proxyHost = conf.proxyHost;
            netConf.proxyPort = conf.proxyPort;
            netConf.maxConcurrentRequestCount = conf.maxConcurrentRequestCount;
        }
        self.networking = [[OSSNetworking alloc] initWithConfiguration:netConf];
    }
    return self;
}

- (OSSTask *)invokeRequest:(OSSNetworkingRequestDelegate *)request requireAuthentication:(BOOL)requireAuthentication {
    /* if content-type haven't been set, we set one */
    if (!request.allNeededMessage.contentType.oss_isNotEmpty
        && ([request.allNeededMessage.httpMethod isEqualToString:@"POST"] || [request.allNeededMessage.httpMethod isEqualToString:@"PUT"])) {

        request.allNeededMessage.contentType = [OSSUtil detemineMimeTypeForFilePath:request.uploadingFileURL.path               uploadName:request.allNeededMessage.objectKey];
    }

    // Checks if the endpoint is in the excluded CName list.
    [self.clientConfiguration.cnameExcludeList enumerateObjectsUsingBlock:^(NSString *exclude, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([self.endpoint hasSuffix:exclude]) {
            request.allNeededMessage.isHostInCnameExcludeList = YES;
            *stop = YES;
        }
    }];

    id<OSSRequestInterceptor> uaSetting = [[OSSUASettingInterceptor alloc] initWithClientConfiguration:self.clientConfiguration];
    [request.interceptors addObject:uaSetting];

    /* check if the authentication is required */
    if (requireAuthentication) {
        id<OSSRequestInterceptor> signer = [[OSSSignerInterceptor alloc] initWithCredentialProvider:self.credentialProvider];
        [request.interceptors addObject:signer];
    }

    request.isHttpdnsEnable = self.clientConfiguration.isHttpdnsEnable;

    return [_networking sendRequest:request];
}

#pragma implement restful apis

- (OSSTask *)getService:(OSSGetServiceRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetService];
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"GET"
                                                bucketName:nil
                                                 objectKey:nil
                                                      type:nil
                                                       md5:nil
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:nil
                                                    querys:[request getQueryDict] sha1:nil];
    requestDelegate.operType = OSSOperationTypeGetService;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)createBucket:(OSSCreateBucketRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    NSMutableDictionary * headerParams = nil;
    if (request.xOssACL) {
        headerParams = [NSMutableDictionary dictionaryWithObjectsAndKeys:request.xOssACL, @"x-oss-acl", nil];
    }
    if (request.location) {
        requestDelegate.uploadingData = [OSSUtil constructHttpBodyForCreateBucketWithLocation:request.location];
    }

    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeCreateBucket];
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"PUT"
                                                bucketName:request.bucketName
                                                 objectKey:nil
                                                      type:nil
                                                       md5:nil
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:headerParams
                                                    querys:nil sha1:nil];
    requestDelegate.operType = OSSOperationTypeCreateBucket;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)deleteBucket:(OSSDeleteObjectRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeDeleteBucket];
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"DELETE"
                                                bucketName:request.bucketName
                                                 objectKey:nil
                                                      type:nil
                                                       md5:nil
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:nil
                                                    querys:nil sha1:nil];
    requestDelegate.operType = OSSOperationTypeDeleteBucket;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)getBucket:(OSSGetBucketRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetBucket];
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"GET"
                                                bucketName:request.bucketName
                                                 objectKey:nil
                                                      type:nil
                                                       md5:nil
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:nil
                                                    querys:[request getQueryDict] sha1:nil];
    requestDelegate.operType = OSSOperationTypeGetBucket;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)getBucketACL:(OSSGetBucketACLRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    NSMutableDictionary * query = [NSMutableDictionary dictionaryWithObject:@"" forKey:@"acl"];
    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetBucketACL];
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"GET"
                                                bucketName:request.bucketName
                                                 objectKey:nil
                                                      type:nil
                                                       md5:nil
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:nil
                                                    querys:query sha1:nil];
    requestDelegate.operType = OSSOperationTypeGetBucketACL;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)headObject:(OSSHeadObjectRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeHeadObject];
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"HEAD"
                                                bucketName:request.bucketName
                                                 objectKey:request.objectKey
                                                      type:nil
                                                       md5:nil
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:nil
                                                    querys:nil sha1:nil];
    requestDelegate.operType = OSSOperationTypeHeadObject;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)getObject:(OSSGetObjectRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    NSString * rangeString = nil;
    if (request.range) {
        rangeString = [request.range toHeaderString];
    }
    if (request.downloadProgress) {
        requestDelegate.downloadProgress = request.downloadProgress;
    }
    if (request.onRecieveData) {
        requestDelegate.onRecieveData = request.onRecieveData;
    }
    NSMutableDictionary * querys = nil;
    if (request.xOssProcess) {
         querys = [NSMutableDictionary dictionaryWithObjectsAndKeys:request.xOssProcess, @"x-oss-process", nil];
    }
    
    [self enableCRC64WithFlag:request.crcFlag requestDelegate:requestDelegate];
    OSSHttpResponseParser *responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetObject];
    responseParser.crc64Verifiable = requestDelegate.crc64Verifiable;
    
    requestDelegate.responseParser = responseParser;
    requestDelegate.responseParser.downloadingFileURL = request.downloadToFileURL;
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"GET"
                                                bucketName:request.bucketName
                                                 objectKey:request.objectKey
                                                      type:nil
                                                       md5:nil
                                                     range:rangeString
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:nil
                                                    querys:querys sha1:nil];
    requestDelegate.operType = OSSOperationTypeGetObject;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)putObject:(OSSPutObjectRequest *)request
{
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    NSMutableDictionary * headerParams = [NSMutableDictionary dictionaryWithDictionary:request.objectMeta];
    [self enableCRC64WithFlag:request.crcFlag requestDelegate:requestDelegate];
    
    if (request.uploadingData) {
        requestDelegate.uploadingData = request.uploadingData;
        if (requestDelegate.crc64Verifiable)
        {
            NSMutableData *mutableData = [NSMutableData dataWithData:request.uploadingData];
            requestDelegate.contentCRC = [NSString stringWithFormat:@"%llu",[mutableData oss_crc64]];
        }
    }
    if (request.uploadingFileURL) {
        requestDelegate.uploadingFileURL = request.uploadingFileURL;
    }
    if (request.callbackParam) {
        [headerParams setObject:[request.callbackParam base64JsonString] forKey:OSSHttpHeaderXOSSCallback];
    }
    if (request.callbackVar) {
        [headerParams setObject:[request.callbackVar base64JsonString] forKey:OSSHttpHeaderXOSSCallbackVar];
    }
    if (request.uploadProgress) {
        requestDelegate.uploadProgress = request.uploadProgress;
    }
    if (request.uploadRetryCallback) {
        requestDelegate.retryCallback = request.uploadRetryCallback;
    }
    if (request.contentDisposition) {
        [headerParams setObject:request.contentDisposition forKey:OSSHttpHeaderContentDisposition];
    }
    if (request.contentEncoding) {
        [headerParams setObject:request.contentEncoding forKey:OSSHttpHeaderContentEncoding];
    }
    if (request.expires) {
        [headerParams setObject:request.expires forKey:OSSHttpHeaderExpires];
    }
    if (request.cacheControl) {
        [headerParams setObject:request.cacheControl forKey:OSSHttpHeaderCacheControl];
    }
    
    
    OSSHttpResponseParser *responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutObject];
    responseParser.crc64Verifiable = requestDelegate.crc64Verifiable;
    requestDelegate.responseParser = responseParser;
    NSString *dateString = [[NSDate oss_clockSkewFixedDate] oss_asStringValue];
    
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                                                 httpMethod:@"PUT" bucketName:request.bucketName objectKey:request.objectKey type:request.contentType md5:request.contentMd5 range:nil
                                                                                       date:dateString
                                                                               headerParams:headerParams querys:nil sha1:request.contentSHA1];
    requestDelegate.operType = OSSOperationTypePutObject;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)putObjectACL:(OSSPutObjectACLRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    if (request.uploadRetryCallback) {
        requestDelegate.retryCallback = request.uploadRetryCallback;
    }
    NSMutableDictionary * headerParams = [NSMutableDictionary dictionary];
    if (request.acl) {
        headerParams[@"x-oss-object-acl"] = request.acl;
    } else {
        headerParams[@"x-oss-object-acl"] = @"default";
    }

    NSMutableDictionary * querys = [NSMutableDictionary dictionaryWithObject:@"" forKey:@"acl"];

    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutObjectACL];
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"PUT"
                                                bucketName:request.bucketName
                                                 objectKey:request.objectKey
                                                      type:nil
                                                       md5:nil
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:headerParams
                                                    querys:querys sha1:nil];
    requestDelegate.operType = OSSOperationTypePutObjectACL;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)appendObject:(OSSAppendObjectRequest *)request
{
    return [self appendObject:request withCrc64ecma:nil];
}

- (OSSTask *)appendObject:(OSSAppendObjectRequest *)request withCrc64ecma:(nullable NSString *)crc64ecma
{
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    NSMutableDictionary * headerParams = [NSMutableDictionary dictionaryWithDictionary:request.objectMeta];
    requestDelegate.lastCRC = crc64ecma;
    [self enableCRC64WithFlag:request.crcFlag requestDelegate:requestDelegate];
    
    if (request.uploadingData)
    {
        requestDelegate.uploadingData = request.uploadingData;
        if (requestDelegate.crc64Verifiable)
        {
            NSMutableData *mutableData = [NSMutableData dataWithData:request.uploadingData];
            requestDelegate.contentCRC = [NSString stringWithFormat:@"%llu",[mutableData oss_crc64]];
        }
    }
    if (request.uploadingFileURL) {
        requestDelegate.uploadingFileURL = request.uploadingFileURL;
    }
    if (request.uploadProgress) {
        requestDelegate.uploadProgress = request.uploadProgress;
    }
    if (request.contentDisposition) {
        [headerParams setObject:request.contentDisposition forKey:OSSHttpHeaderContentDisposition];
    }
    if (request.contentEncoding) {
        [headerParams setObject:request.contentEncoding forKey:OSSHttpHeaderContentEncoding];
    }
    if (request.expires) {
        [headerParams setObject:request.expires forKey:OSSHttpHeaderExpires];
    }
    if (request.cacheControl) {
        [headerParams setObject:request.cacheControl forKey:OSSHttpHeaderCacheControl];
    }
    NSMutableDictionary * querys = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"", @"append",
                                    [@(request.appendPosition) stringValue], @"position", nil];
    
    OSSHttpResponseParser *responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeAppendObject];
    responseParser.crc64Verifiable = requestDelegate.crc64Verifiable;
    requestDelegate.responseParser = responseParser;
    
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                                                 httpMethod:@"POST"
                                                                                 bucketName:request.bucketName
                                                                                  objectKey:request.objectKey
                                                                                       type:request.contentType
                                                                                        md5:request.contentMd5
                                                                                      range:nil
                                                                                       date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                                                               headerParams:headerParams
                                                                                     querys:querys sha1:request.contentSHA1];
    requestDelegate.operType = OSSOperationTypeAppendObject;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)deleteObject:(OSSDeleteObjectRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutObject];
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"DELETE"
                                                bucketName:request.bucketName
                                                 objectKey:request.objectKey
                                                      type:nil
                                                       md5:nil
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:nil
                                                    querys:nil sha1:nil];
    requestDelegate.operType = OSSOperationTypeDeleteObject;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)copyObject:(OSSCopyObjectRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    NSMutableDictionary * headerParams = [NSMutableDictionary dictionaryWithDictionary:request.objectMeta];

    if (request.sourceCopyFrom) {
        [headerParams setObject:request.sourceCopyFrom forKey:@"x-oss-copy-source"];
    }
    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeCopyObject];
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"PUT"
                                                bucketName:request.bucketName
                                                 objectKey:request.objectKey
                                                      type:request.contentType
                                                       md5:request.contentMd5
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:headerParams
                                                    querys:nil sha1:request.contentSHA1];
    requestDelegate.operType = OSSOperationTypeCopyObject;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)multipartUploadInit:(OSSInitMultipartUploadRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    NSMutableDictionary * headerParams = [NSMutableDictionary dictionaryWithDictionary:request.objectMeta];

    if (request.contentDisposition) {
        [headerParams setObject:request.contentDisposition forKey:OSSHttpHeaderContentDisposition];
    }
    if (request.contentEncoding) {
        [headerParams setObject:request.contentEncoding forKey:OSSHttpHeaderContentEncoding];
    }
    if (request.expires) {
        [headerParams setObject:request.expires forKey:OSSHttpHeaderExpires];
    }
    if (request.cacheControl) {
        [headerParams setObject:request.cacheControl forKey:OSSHttpHeaderCacheControl];
    }
    
    NSMutableDictionary *querys = [NSMutableDictionary dictionary];
    [querys setObject:@"" forKey:@"uploads"];
    if (request.sequential) {
        [querys setObject:@"" forKey:@"sequential"];
    }
    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeInitMultipartUpload];
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"POST"
                                                bucketName:request.bucketName
                                                 objectKey:request.objectKey
                                                      type:request.contentType
                                                       md5:nil
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:headerParams
                                                    querys:[querys copy] sha1:nil];
    requestDelegate.operType = OSSOperationTypeInitMultipartUpload;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)uploadPart:(OSSUploadPartRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    NSMutableDictionary * querys = [NSMutableDictionary dictionaryWithObjectsAndKeys:[@(request.partNumber) stringValue], @"partNumber",
                                    request.uploadId, @"uploadId", nil];
    [self enableCRC64WithFlag:request.crcFlag requestDelegate:requestDelegate];
    if (request.uploadPartData) {
        requestDelegate.uploadingData = request.uploadPartData;
        if (requestDelegate.crc64Verifiable)
        {
            NSMutableData *mutableData = [NSMutableData dataWithData:request.uploadPartData];
            requestDelegate.contentCRC = [NSString stringWithFormat:@"%llu",[mutableData oss_crc64]];
        }
    }
    if (request.uploadPartFileURL) {
        requestDelegate.uploadingFileURL = request.uploadPartFileURL;
    }
    if (request.uploadPartProgress) {
        requestDelegate.uploadProgress = request.uploadPartProgress;
    }

    OSSHttpResponseParser *responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeUploadPart];
    responseParser.crc64Verifiable = requestDelegate.crc64Verifiable;
    requestDelegate.responseParser = responseParser;
    
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"PUT"
                                                bucketName:request.bucketName
                                                 objectKey:request.objectkey
                                                      type:nil
                                                       md5:request.contentMd5
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:nil
                                                    querys:querys sha1:request.contentSHA1];
    requestDelegate.operType = OSSOperationTypeUploadPart;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)completeMultipartUpload:(OSSCompleteMultipartUploadRequest *)request
{
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    NSMutableDictionary * headerParams = [NSMutableDictionary dictionary];
    if (request.partInfos) {
        requestDelegate.uploadingData = [OSSUtil constructHttpBodyFromPartInfos:request.partInfos];
    }
    if (request.callbackParam) {
        [headerParams setObject:[request.callbackParam base64JsonString] forKey:OSSHttpHeaderXOSSCallback];
    }
    if (request.callbackVar) {
        [headerParams setObject:[request.callbackVar base64JsonString] forKey:OSSHttpHeaderXOSSCallbackVar];
    }
    if (request.completeMetaHeader) {
        [headerParams addEntriesFromDictionary:request.completeMetaHeader];
    }
    NSMutableDictionary * querys = [NSMutableDictionary dictionaryWithObjectsAndKeys:request.uploadId, @"uploadId", nil];
    
    OSSHttpResponseParser *responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeCompleteMultipartUpload];
    responseParser.crc64Verifiable = requestDelegate.crc64Verifiable;
    requestDelegate.responseParser = responseParser;
    
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"POST"
                                                bucketName:request.bucketName
                                                 objectKey:request.objectKey
                                                      type:nil
                                                       md5:request.contentMd5
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:headerParams
                                                    querys:querys sha1:request.contentSHA1];
    requestDelegate.operType = OSSOperationTypeCompleteMultipartUpload;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)listParts:(OSSListPartsRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    NSMutableDictionary * querys = [NSMutableDictionary dictionaryWithObjectsAndKeys:request.uploadId, @"uploadId", nil];
    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeListMultipart];
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"GET"
                                                bucketName:request.bucketName
                                                 objectKey:request.objectKey
                                                      type:nil
                                                       md5:nil
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:nil
                                                    querys:querys sha1:nil];
    requestDelegate.operType = OSSOperationTypeListMultipart;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)abortMultipartUpload:(OSSAbortMultipartUploadRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    NSMutableDictionary * querys = [NSMutableDictionary dictionaryWithObjectsAndKeys:request.uploadId, @"uploadId", nil];
    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeAbortMultipartUpload];
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"DELETE"
                                                bucketName:request.bucketName
                                                 objectKey:request.objectKey
                                                      type:nil
                                                       md5:nil
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:nil
                                                    querys:querys sha1:nil];
    requestDelegate.operType = OSSOperationTypeAbortMultipartUpload;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)abortResumableMultipartUpload:(OSSResumableUploadRequest *)request
{
    return [self abortMultipartUpload:request sequential:NO resumable:YES];
}

- (OSSTask *)abortMultipartUpload:(OSSMultipartUploadRequest *)request sequential:(BOOL)sequential resumable:(BOOL)resumable {
    
    OSSTask *errorTask = nil;
    if(resumable) {
        OSSResumableUploadRequest *resumableRequest = (OSSResumableUploadRequest *)request;
        NSString *uploadingFilePath = [resumableRequest.uploadingFileURL path];
        NSString *uploadingFilePathMd5 = [OSSUtil fileMD5String:uploadingFilePath];
        NSString *nameInfoString = [NSString stringWithFormat:@"%@%@%@%zi",uploadingFilePathMd5, resumableRequest.bucketName, resumableRequest.objectKey, resumableRequest.partSize];
        if (sequential) {
            nameInfoString = [nameInfoString stringByAppendingString:oss_record_info_suffix_with_sequential];
        }
        if (request.crcFlag == OSSRequestCRCOpen) {
            nameInfoString = [nameInfoString stringByAppendingString:oss_record_info_suffix_with_crc];
        }
        
        NSData *data = [nameInfoString dataUsingEncoding:NSUTF8StringEncoding];
        NSString *recordFileName = [OSSUtil dataMD5String:data];
        NSString *recordFilePath = [NSString stringWithFormat:@"%@/%@",resumableRequest.recordDirectoryPath,recordFileName];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *partInfosFilePath = [[[NSString oss_documentDirectory] stringByAppendingPathComponent:oss_partInfos_storage_name] stringByAppendingPathComponent:resumableRequest.uploadId];
        
        if([fileManager fileExistsAtPath:recordFilePath])
        {
            NSError *error;
            if (![fileManager removeItemAtPath:recordFilePath error:&error])
            {
                OSSLogDebug(@"[OSSSDKError]: %@", error);
            }
        }
        
        if ([fileManager fileExistsAtPath:partInfosFilePath]) {
            NSError *error;
            if (![fileManager removeItemAtPath:partInfosFilePath error:&error])
            {
                OSSLogDebug(@"[OSSSDKError]: %@", error);
            }
        }
        
        OSSAbortMultipartUploadRequest * abort = [OSSAbortMultipartUploadRequest new];
        abort.bucketName = request.bucketName;
        abort.objectKey = request.objectKey;
        if (request.uploadId) {
            abort.uploadId = request.uploadId;
        } else {
            abort.uploadId = [[NSString alloc] initWithData:[[NSFileHandle fileHandleForReadingAtPath:recordFilePath] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        }
        
        errorTask = [self abortMultipartUpload:abort];
    }else
    {
        OSSAbortMultipartUploadRequest * abort = [OSSAbortMultipartUploadRequest new];
        abort.bucketName = request.bucketName;
        abort.objectKey = request.objectKey;
        abort.uploadId = request.uploadId;
        errorTask = [self abortMultipartUpload:abort];
    }
    
    return errorTask;
}

- (OSSTask *)presignConstrainURLWithBucketName:(NSString *)bucketName
                                 withObjectKey:(NSString *)objectKey
                        withExpirationInterval:(NSTimeInterval)interval {

    return [self presignConstrainURLWithBucketName:bucketName
                                     withObjectKey:objectKey
                            withExpirationInterval:interval
                                    withParameters:@{}];
}

- (OSSTask *)presignConstrainURLWithBucketName:(NSString *)bucketName
                                 withObjectKey:(NSString *)objectKey
                        withExpirationInterval:(NSTimeInterval)interval
                                withParameters:(NSDictionary *)parameters {

    return [[OSSTask taskWithResult:nil] continueWithBlock:^id(OSSTask *task) {
        NSString * resource = [NSString stringWithFormat:@"/%@/%@", bucketName, objectKey];
        NSString * expires = [@((int64_t)[[NSDate oss_clockSkewFixedDate] timeIntervalSince1970] + interval) stringValue];
        NSString * wholeSign = nil;
        OSSFederationToken * token = nil;
        NSError * error = nil;
        NSMutableDictionary * params = [NSMutableDictionary new];

        if (parameters) {
            [params addEntriesFromDictionary:parameters];
        }

        if ([self.credentialProvider isKindOfClass:[OSSFederationCredentialProvider class]]) {
            token = [(OSSFederationCredentialProvider *)self.credentialProvider getToken:&error];
            if (error) {
                return [OSSTask taskWithError:error];
            }
        } else if ([self.credentialProvider isKindOfClass:[OSSStsTokenCredentialProvider class]]) {
            token = [(OSSStsTokenCredentialProvider *)self.credentialProvider getToken];
        }

        if ([self.credentialProvider isKindOfClass:[OSSFederationCredentialProvider class]]
            || [self.credentialProvider isKindOfClass:[OSSStsTokenCredentialProvider class]]) {
            if (token.tToken) {
                [params setObject:token.tToken forKey:@"security-token"];
            }
            resource = [NSString stringWithFormat:@"%@?%@", resource, [OSSUtil populateSubresourceStringFromParameter:params]];
            NSString * string2sign = [NSString stringWithFormat:@"GET\n\n\n%@\n%@", expires, resource];
            wholeSign = [OSSUtil sign:string2sign withToken:token];
        } else {
            NSString * subresource = [OSSUtil populateSubresourceStringFromParameter:params];
            if ([subresource length] > 0) {
                resource = [NSString stringWithFormat:@"%@?%@", resource, [OSSUtil populateSubresourceStringFromParameter:params]];
            }
            NSString * string2sign = [NSString stringWithFormat:@"GET\n\n\n%@\n%@", expires, resource];
            wholeSign = [self.credentialProvider sign:string2sign error:&error];
            if (error) {
                return [OSSTask taskWithError:error];
            }
        }

        NSArray * splitResult = [wholeSign componentsSeparatedByString:@":"];
        if ([splitResult count] != 2
            || ![((NSString *)[splitResult objectAtIndex:0]) hasPrefix:@"OSS "]) {
            return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                             code:OSSClientErrorCodeSignFailed
                                                         userInfo:@{OSSErrorMessageTOKEN: @"the returned signature is invalid"}]];
        }
        NSString * accessKey = [(NSString *)[splitResult objectAtIndex:0] substringFromIndex:4];
        NSString * signature = [splitResult objectAtIndex:1];

        NSURL * endpointURL = [NSURL URLWithString:self.endpoint];
        NSString * host = endpointURL.host;
        if ([OSSUtil isOssOriginBucketHost:host]) {
            host = [NSString stringWithFormat:@"%@.%@", bucketName, host];
        }
        [params setObject:signature forKey:@"Signature"];
        [params setObject:accessKey forKey:@"OSSAccessKeyId"];
        [params setObject:expires forKey:@"Expires"];
        NSString * stringURL = [NSString stringWithFormat:@"%@://%@/%@?%@",
                                endpointURL.scheme,
                                host,
                                [OSSUtil encodeURL:objectKey],
                                [OSSUtil populateQueryStringFromParameter:params]];
        return [OSSTask taskWithResult:stringURL];
    }];
}

- (OSSTask *)presignPublicURLWithBucketName:(NSString *)bucketName
                              withObjectKey:(NSString *)objectKey {

    return [self presignPublicURLWithBucketName:bucketName
                                  withObjectKey:objectKey
                                 withParameters:@{}];
}

- (OSSTask *)presignPublicURLWithBucketName:(NSString *)bucketName
                             withObjectKey:(NSString *)objectKey
                             withParameters:(NSDictionary *)parameters {

    return [[OSSTask taskWithResult:nil] continueWithBlock:^id(OSSTask *task) {
        NSURL * endpointURL = [NSURL URLWithString:self.endpoint];
        NSString * host = endpointURL.host;
        if ([OSSUtil isOssOriginBucketHost:host]) {
            host = [NSString stringWithFormat:@"%@.%@", bucketName, host];
        }
        if ([parameters count] > 0) {
            NSString * stringURL = [NSString stringWithFormat:@"%@://%@/%@?%@",
                                    endpointURL.scheme,
                                    host,
                                    [OSSUtil encodeURL:objectKey],
                                    [OSSUtil populateQueryStringFromParameter:parameters]];
            return [OSSTask taskWithResult:stringURL];
        } else {
            NSString * stringURL = [NSString stringWithFormat:@"%@://%@/%@",
                                    endpointURL.scheme,
                                    host,
                                    [OSSUtil encodeURL:objectKey]];
            return [OSSTask taskWithResult:stringURL];
        }
    }];
}

- (OSSTask *)multipartUpload:(OSSMultipartUploadRequest *)request {
    return [self multipartUpload: request resumable: NO sequential: NO];
}

- (OSSTask *)processCompleteMultipartUpload:(OSSMultipartUploadRequest *)request partInfos:(NSArray<OSSPartInfo *> *)partInfos clientCrc64:(uint64_t)clientCrc64 recordFilePath:(NSString *)recordFilePath localPartInfosPath:(NSString *)localPartInfosPath
{
    OSSCompleteMultipartUploadRequest * complete = [OSSCompleteMultipartUploadRequest new];
    complete.bucketName = request.bucketName;
    complete.objectKey = request.objectKey;
    complete.uploadId = request.uploadId;
    complete.partInfos = partInfos;
    complete.crcFlag = request.crcFlag;
    complete.contentSHA1 = request.contentSHA1;
    
    if (request.completeMetaHeader != nil) {
        complete.completeMetaHeader = request.completeMetaHeader;
    }
    if (request.callbackParam != nil) {
        complete.callbackParam = request.callbackParam;
    }
    if (request.callbackVar != nil) {
        complete.callbackVar = request.callbackVar;
    }
    
    OSSTask * completeTask = [self completeMultipartUpload:complete];
    [completeTask waitUntilFinished];
    
    if (completeTask.error) {
        OSSLogVerbose(@"completeTask.error %@: ",completeTask.error);
        return completeTask;
    } else
    {
        if(recordFilePath && [[NSFileManager defaultManager] fileExistsAtPath:recordFilePath])
        {
            NSError *deleteError;
            if (![[NSFileManager defaultManager] removeItemAtPath:recordFilePath error:&deleteError])
            {
                OSSLogError(@"delete localUploadIdPath failed!Error: %@",deleteError);
            }
        }
        
        if (localPartInfosPath && [[NSFileManager defaultManager] fileExistsAtPath:localPartInfosPath])
        {
            NSError *deleteError;
            if (![[NSFileManager defaultManager] removeItemAtPath:localPartInfosPath error:&deleteError])
            {
                OSSLogError(@"delete localPartInfosPath failed!Error: %@",deleteError);
            }
        }
        OSSCompleteMultipartUploadResult * completeResult = completeTask.result;
        if (complete.crcFlag == OSSRequestCRCOpen && completeResult.remoteCRC64ecma)
        {
            uint64_t remote_crc64 = 0;
            NSScanner *scanner = [NSScanner scannerWithString:completeResult.remoteCRC64ecma];
            if ([scanner scanUnsignedLongLong:&remote_crc64])
            {
                OSSLogVerbose(@"resumableUpload local_crc64 %llu",clientCrc64);
                OSSLogVerbose(@"resumableUpload remote_crc64 %llu", remote_crc64);
                if (remote_crc64 != clientCrc64)
                {
                    NSString *errorMessage = [NSString stringWithFormat:@"local_crc64(%llu) is not equal to remote_crc64(%llu)!",clientCrc64,remote_crc64];
                    NSError *error = [NSError errorWithDomain:OSSClientErrorDomain
                                                         code:OSSClientErrorCodeInvalidCRC
                                                     userInfo:@{OSSErrorMessageTOKEN:errorMessage}];
                    return [OSSTask taskWithError:error];
                }
            }
        }
        
        OSSResumableUploadResult * result = [OSSResumableUploadResult new];
        result.requestId = completeResult.requestId;
        result.httpResponseCode = completeResult.httpResponseCode;
        result.httpResponseHeaderFields = completeResult.httpResponseHeaderFields;
        result.serverReturnJsonString = completeResult.serverReturnJsonString;
        
        return [OSSTask taskWithResult:result];
    }
}


- (OSSTask *)resumableUpload:(OSSResumableUploadRequest *)request
{
    return [self multipartUpload: request resumable: YES sequential: NO];
}

- (OSSTask *)processListPartsWithObjectKey:(nonnull NSString *)objectKey bucket:(nonnull NSString *)bucket uploadId:(NSString * _Nonnull *)uploadId uploadedParts:(nonnull NSMutableArray *)uploadedParts uploadedLength:(NSUInteger *)uploadedLength totalSize:(NSUInteger)totalSize partSize:(NSUInteger)partSize
{
    OSSListPartsRequest * listParts = [OSSListPartsRequest new];
    listParts.bucketName = bucket;
    listParts.objectKey = objectKey;
    listParts.uploadId = *uploadId;
    OSSTask * listPartsTask = [self listParts:listParts];
    [listPartsTask waitUntilFinished];
    if (listPartsTask.error)
    {
        if ([listPartsTask.error.domain isEqualToString: OSSServerErrorDomain] && listPartsTask.error.code == -1 * 404)
        {
            OSSLogVerbose(@"local record existes but the remote record is deleted");
            *uploadId = nil;
        } else
        {
            return listPartsTask;
        }
    }
    else
    {
        OSSLogVerbose(@"resumableUpload listpart ok");
        OSSListPartsResult * result = listPartsTask.result;
        if (result.parts.count) {
            [uploadedParts addObjectsFromArray:result.parts];
        }
        __block NSUInteger firstPartSize = 0;
        __block NSUInteger bUploadedLength = 0;
        [uploadedParts enumerateObjectsUsingBlock:^(NSDictionary *part, NSUInteger idx, BOOL * _Nonnull stop) {
            unsigned long long iPartSize = 0;
            NSString *partSizeString = [part objectForKey:OSSSizeXMLTOKEN];
            NSScanner *scanner = [NSScanner scannerWithString:partSizeString];
            [scanner scanUnsignedLongLong:&iPartSize];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
            bUploadedLength += iPartSize;
            if (idx == 0)
            {
                firstPartSize = iPartSize;
            }
#pragma clang diagnostic pop
        }];
        *uploadedLength = bUploadedLength;
        
        if (totalSize < bUploadedLength)
        {
            return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                              code:OSSClientErrorCodeCannotResumeUpload
                                                          userInfo:@{OSSErrorMessageTOKEN: @"The uploading file is inconsistent with before"}]];
        }
        else if (firstPartSize != 0 && firstPartSize != partSize && totalSize != firstPartSize)
        {
            return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                              code:OSSClientErrorCodeCannotResumeUpload
                                                          userInfo:@{OSSErrorMessageTOKEN: @"The part size setting is inconsistent with before"}]];
        }
    }
    return nil;
}

- (OSSTask *)processResumableInitMultipartUpload:(OSSInitMultipartUploadRequest *)request recordFilePath:(NSString *)recordFilePath
{
    OSSTask *task = [self multipartUploadInit:request];
    [task waitUntilFinished];
    
    if(task.result && [recordFilePath oss_isNotEmpty])
    {
        OSSInitMultipartUploadResult *result = task.result;
        if (![result.uploadId oss_isNotEmpty])
        {
            NSString *errorMessage = [NSString stringWithFormat:@"Can not get uploadId!"];
            NSError *error = [NSError errorWithDomain:OSSServerErrorDomain
                                                 code:OSSClientErrorCodeNilUploadid userInfo:@{OSSErrorMessageTOKEN:   errorMessage}];
            return [OSSTask taskWithError:error];
        }
        
        NSFileManager *defaultFM = [NSFileManager defaultManager];
        if (![defaultFM fileExistsAtPath:recordFilePath])
        {
            if (![defaultFM createFileAtPath:recordFilePath contents:nil attributes:nil]) {
                NSError *error = [NSError errorWithDomain:OSSClientErrorDomain
                                                     code:OSSClientErrorCodeFileCantWrite
                                                 userInfo:@{OSSErrorMessageTOKEN: @"uploadId for this task can't be stored persistentially!"}];
                OSSLogDebug(@"[Error]: %@", error);
                return [OSSTask taskWithError:error];
            }
        }
        NSFileHandle * write = [NSFileHandle fileHandleForWritingAtPath:recordFilePath];
        [write writeData:[result.uploadId dataUsingEncoding:NSUTF8StringEncoding]];
        [write closeFile];
    }
    return task;
}

- (OSSTask *)upload:(OSSMultipartUploadRequest *)request
        uploadIndex:(NSMutableArray *)alreadyUploadIndex
         uploadPart:(NSMutableArray *)alreadyUploadPart
              count:(NSUInteger)partCout
     uploadedLength:(NSUInteger *)uploadedLength
           fileSize:(unsigned long long)uploadFileSize
{
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount: 5];
    
    OSSRequestCRCFlag crcFlag = request.crcFlag;
    __block BOOL isCancel = NO;
    __block OSSTask *errorTask;
    __block NSMutableDictionary *localPartInfos = nil;
    
    if (crcFlag == OSSRequestCRCOpen) {
        localPartInfos = [self localPartInfosDictoryWithUploadId:request.uploadId];
    }
    
    if (!localPartInfos) {
        localPartInfos = [NSMutableDictionary dictionary];
    }
    
    NSInputStream *inputStream = [NSInputStream inputStreamWithURL:request.uploadingFileURL];
    [inputStream open];
    
    NSData * uploadPartData;
    NSInteger realPartLength = request.partSize;
    
    for (int i = 1; i <= partCout; i++) {
        // if current transport is sequential and has error occurs,stop upload and return error!
        if (isCancel) {
            errorTask = [OSSTask taskWithError:[OSSClient cancelError]];
            break;
        }
        @autoreleasepool{
            if (i == partCout) {
                realPartLength = uploadFileSize - request.partSize * (i - 1);
            }
            NSMutableData *myBuffer = [NSMutableData dataWithLength:realPartLength];
            uint8_t *buffer = [myBuffer mutableBytes];
            NSInteger length = [inputStream read:buffer maxLength:realPartLength];
            uploadPartData = [NSData dataWithBytes:buffer length:length];
        
            if (![inputStream hasBytesAvailable]) {
                [inputStream close];
            }
            //alreadyUploadIndex 为空 return false
            if (alreadyUploadIndex && [alreadyUploadIndex containsObject:@(i)]) {
                continue;
            }
            
            NSBlockOperation * operation = [[NSBlockOperation alloc] init];
            [operation addExecutionBlock:^{
                @autoreleasepool {
                    if (request.isCancelled) {
                        @synchronized(lock){
                            if(!isCancel){
                                isCancel = YES;
                                [queue cancelAllOperations];
                            }
                        }
                    }else{
                        OSSUploadPartRequest * uploadPart = [OSSUploadPartRequest new];
                        uploadPart.bucketName = request.bucketName;
                        uploadPart.objectkey = request.objectKey;
                        uploadPart.partNumber = i;
                        uploadPart.uploadId = request.uploadId;
                        uploadPart.uploadPartData = uploadPartData;
                        uploadPart.contentMd5 = [OSSUtil base64Md5ForData:uploadPartData];
                        uploadPart.crcFlag = request.crcFlag;
                        
                        OSSTask * uploadPartTask = [self uploadPart:uploadPart];
                        [uploadPartTask waitUntilFinished];
                        if (uploadPartTask.error && uploadPartTask.error.code != 409) {
                            errorTask = uploadPartTask;
                        } else {
                            OSSUploadPartResult * result = uploadPartTask.result;
                            OSSPartInfo * partInfo = [OSSPartInfo new];
                            partInfo.partNum = i;
                            partInfo.eTag = result.eTag;
                            partInfo.size = realPartLength;
                            uint64_t crc64OfPart;
                            @try {
                                NSScanner *scanner = [NSScanner scannerWithString:result.remoteCRC64ecma];
                                [scanner scanUnsignedLongLong:&crc64OfPart];
                                partInfo.crc64 = crc64OfPart;
                            } @catch (NSException *exception) {
                                OSSLogError(@"multipart upload error with nil remote crc64!");
                            }
                            
                            @synchronized(lock){
                                [alreadyUploadPart addObject:partInfo];
                                
                                if (crcFlag == OSSRequestCRCOpen)
                                {
                                    [self processForLocalPartInfos:localPartInfos
                                                          partInfo:partInfo
                                                          uploadId:request.uploadId];
                                    [self persistencePartInfos:localPartInfos
                                                  withUploadId:request.uploadId];
                                }
                                
                                *uploadedLength += realPartLength;
                                if (request.uploadProgress)
                                {
                                    request.uploadProgress(realPartLength, *uploadedLength, uploadFileSize);
                                }
                            }
                        }
                    }
                }
            }];
            [queue addOperation:operation];
            
            if (queue.operationCount >= 5) {
                [queue waitUntilAllOperationsAreFinished];
            }
        }
    }
    [queue waitUntilAllOperationsAreFinished];
    
    return errorTask;
}

- (void)processForLocalPartInfos:(NSMutableDictionary *)localPartInfoDict partInfo:(OSSPartInfo *)partInfo uploadId:(NSString *)uploadId
{
    NSDictionary *partInfoDict = [partInfo entityToDictionary];
    NSString *keyString = [NSString stringWithFormat:@"%zi",partInfo.partNum];
    [localPartInfoDict setObject:partInfoDict
                          forKey:keyString];
}

- (BOOL)doesObjectExistInBucket:(NSString *)bucketName
                      objectKey:(NSString *)objectKey
                          error:(const NSError **)error {

    OSSHeadObjectRequest * headRequest = [OSSHeadObjectRequest new];
    headRequest.bucketName = bucketName;
    headRequest.objectKey = objectKey;
    OSSTask * headTask = [self headObject:headRequest];
    [headTask waitUntilFinished];
    NSError *headError = headTask.error;
    if (!headError) {
        return YES;
    } else {
        if ([headError.domain isEqualToString: OSSServerErrorDomain] && headError.code == -404) {
            return NO;
        } else {
            if (error != nil) {
                *error = headError;
            }
            return NO;
        }
    }
}

- (OSSTask *)sequentialMultipartUpload:(OSSResumableUploadRequest *)request
{
    return [self multipartUpload:request resumable:YES sequential:YES];
}
            
- (OSSTask *)multipartUpload:(OSSMultipartUploadRequest *)request resumable:(BOOL)resumable sequential:(BOOL)sequential
{
    if (resumable) {
        if (![request isKindOfClass:[OSSResumableUploadRequest class]]) {
            NSError *typoError = [NSError errorWithDomain:OSSClientErrorDomain
                                                     code:OSSClientErrorCodeInvalidArgument
                                                 userInfo:@{OSSErrorMessageTOKEN: @"resumable multipart request should use instance of class OSSMultipartUploadRequest!"}];
            return [OSSTask taskWithError: typoError];
        }
    }

    [self checkRequestCrc64Setting:request];
    OSSTask *preTask = [self preChecksForRequest:request];
    if (preTask) {
        return preTask;
    }
    
    return [[OSSTask taskWithResult:nil] continueWithExecutor:self.ossOperationExecutor withBlock:^id(OSSTask *task) {
        
        static NSUInteger uploadedLength = 0;
        uploadedLength = 0;
        __block OSSTask * errorTask;
        __block NSString *uploadId;
        
        NSError *error;
        unsigned long long uploadFileSize = [self getSizeWithFilePath:request.uploadingFileURL.path error:&error];
        if (error) {
            return [OSSTask taskWithError:error];
        }
        
        NSUInteger partCount = [self judgePartSizeForMultipartRequest:request fileSize:uploadFileSize];
        
        if (request.isCancelled) {
            return [OSSTask taskWithError:[OSSClient cancelError]];
        }
        
        NSString *recordFilePath = nil;
        NSMutableArray * uploadedPart = [NSMutableArray array];
        NSString *localPartInfosPath = nil;
        NSDictionary *localPartInfos = nil;
        
        NSMutableArray<OSSPartInfo *> *uploadedPartInfos = [NSMutableArray array];
        NSMutableArray * alreadyUploadIndex = [NSMutableArray array];
        
        if (resumable) {
            OSSResumableUploadRequest *resumableRequest = (OSSResumableUploadRequest *)request;
            NSString *recordDirectoryPath = resumableRequest.recordDirectoryPath;
            localPartInfosPath = [[[NSString oss_documentDirectory] stringByAppendingPathComponent:oss_partInfos_storage_name] stringByAppendingPathComponent:uploadId];
            localPartInfos = [NSDictionary dictionaryWithContentsOfFile:localPartInfosPath];
            if ([recordDirectoryPath oss_isNotEmpty]) {
                uploadId = [self readUploadIdWithFilePath: request.uploadingFileURL.path
                                               recordPath: recordDirectoryPath
                                                   bucket: request.bucketName
                                                objectKey: request.objectKey
                                                 partSize: request.partSize
                                           recordFilePath: &recordFilePath
                                               sequential: sequential
                                                  crcFlag:request.crcFlag];
                OSSLogVerbose(@"local uploadId: %@,recordFilePath: %@",uploadId, recordFilePath);
            }
            
            if(uploadId.oss_isNotEmpty)
            {
                NSString *localPartInfosPath = [NSString oss_documentDirectory];
                localPartInfosPath = [[localPartInfosPath stringByAppendingPathComponent:oss_partInfos_storage_name] stringByAppendingPathComponent:uploadId];
                
                localPartInfos = [[NSDictionary alloc] initWithContentsOfURL:[NSURL fileURLWithPath:localPartInfosPath]];
                
                OSSTask *listPartTask = [self processListPartsWithObjectKey:request.objectKey
                                                                     bucket:request.bucketName
                                                                   uploadId:&uploadId
                                                              uploadedParts:uploadedPart
                                                             uploadedLength:&uploadedLength
                                                                  totalSize:uploadFileSize
                                                                   partSize:request.partSize];
                if (listPartTask.error)
                {
                    return listPartTask;
                }
            }
            
            [uploadedPart enumerateObjectsUsingBlock:^(NSDictionary *partInfo, NSUInteger idx, BOOL * _Nonnull stop) {
                unsigned long long iPartNum = 0;
                NSString *partNumberString = [partInfo objectForKey:OSSPartNumberXMLTOKEN];
                NSScanner *scanner = [NSScanner scannerWithString:partNumberString];
                [scanner scanUnsignedLongLong:&iPartNum];
                
                unsigned long long iPartSize = 0;
                NSString *partSizeString = [partInfo objectForKey:OSSSizeXMLTOKEN];
                scanner = [NSScanner scannerWithString:partSizeString];
                [scanner scanUnsignedLongLong:&iPartSize];
                
                NSString *eTag = [partInfo objectForKey:OSSETagXMLTOKEN];
                
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
                
                OSSPartInfo * info = [OSSPartInfo partInfoWithPartNum:iPartNum
                                                                 eTag:eTag
                                                                 size:iPartSize
                                                                crc64:0];
#pragma clang diagnostic pop
                
                NSDictionary *tPartInfo = [localPartInfos objectForKey:[NSString stringWithFormat:@"%zi",iPartNum]];
                if (tPartInfo)
                {
                    info.crc64 = [tPartInfo[@"crc64"] unsignedLongLongValue];
                }
                
                [uploadedPartInfos addObject:info];
                [alreadyUploadIndex addObject:@(info.partNum)];
            }];
            
            if ([alreadyUploadIndex count] > 0 && request.uploadProgress && uploadFileSize) {
                request.uploadProgress(0, uploadedLength, uploadFileSize);
            }
        }
        
        if (![uploadId oss_isNotEmpty]) {
            OSSInitMultipartUploadRequest *initRequest = [OSSInitMultipartUploadRequest new];
            initRequest.bucketName = request.bucketName;
            initRequest.objectKey = request.objectKey;
            initRequest.contentType = request.contentType;
            initRequest.objectMeta = request.completeMetaHeader;
            initRequest.sequential = sequential;
            initRequest.crcFlag = request.crcFlag;
            
            OSSTask *task = [self processResumableInitMultipartUpload:initRequest
                                                       recordFilePath:recordFilePath];
            if (task.error)
            {
                return task;
            }
            OSSInitMultipartUploadResult *initResult = (OSSInitMultipartUploadResult *)task.result;
            uploadId = initResult.uploadId;
        }
        
        request.uploadId = uploadId;
        if (request.isCancelled)
        {
            if(resumable)
            {
                OSSResumableUploadRequest *resumableRequest = (OSSResumableUploadRequest *)request;
                if (resumableRequest.deleteUploadIdOnCancelling) {
                    OSSTask *abortTask = [self abortMultipartUpload:request sequential:sequential resumable:resumable];
                    [abortTask waitUntilFinished];
                }
            }
            
            return [OSSTask taskWithError:[OSSClient cancelError]];
        }
        
        if (sequential) {
            errorTask = [self sequentialUpload:request
                                   uploadIndex:alreadyUploadIndex
                                    uploadPart:uploadedPartInfos
                                         count:partCount
                                uploadedLength:&uploadedLength
                                      fileSize:uploadFileSize];
        } else {
            errorTask = [self upload:request
                         uploadIndex:alreadyUploadIndex
                          uploadPart:uploadedPartInfos
                               count:partCount
                      uploadedLength:&uploadedLength
                            fileSize:uploadFileSize];
        }
        
        if(errorTask.error)
        {
            OSSTask *abortTask;
            if(resumable)
            {
                OSSResumableUploadRequest *resumableRequest = (OSSResumableUploadRequest *)request;
                if (resumableRequest.deleteUploadIdOnCancelling || errorTask.error.code == OSSClientErrorCodeFileCantWrite) {
                    abortTask = [self abortMultipartUpload:request sequential:sequential resumable:resumable];
                }
            }else
            {
                abortTask =[self abortMultipartUpload:request sequential:sequential resumable:resumable];
            }
            [abortTask waitUntilFinished];
            
            return errorTask;
        }
        
        [uploadedPartInfos sortUsingComparator:^NSComparisonResult(OSSPartInfo *part1,OSSPartInfo* part2) {
            if(part1.partNum < part2.partNum){
                return NSOrderedAscending;
            }else if(part1.partNum > part2.partNum){
                return NSOrderedDescending;
            }else{
                return NSOrderedSame;
            }
        }];
        
        // 如果开启了crc64的校验
        uint64_t local_crc64 = 0;
        if (request.crcFlag == OSSRequestCRCOpen)
        {
            for (NSUInteger index = 0; index< uploadedPartInfos.count; index++)
            {
                uint64_t partCrc64 = uploadedPartInfos[index].crc64;
                int64_t partSize = uploadedPartInfos[index].size;
                local_crc64 = [OSSUtil crc64ForCombineCRC1:local_crc64 CRC2:partCrc64 length:partSize];
            }
        }
        return [self processCompleteMultipartUpload:request
                                          partInfos:uploadedPartInfos
                                        clientCrc64:local_crc64
                                     recordFilePath:recordFilePath
                                 localPartInfosPath:localPartInfosPath];
    }];
}

- (OSSTask *)triggerCallBack:(OSSCallBackRequest *)request
{
    if (![request.bucketName oss_isNotEmpty]) {
        NSError *error = [NSError errorWithDomain:OSSTaskErrorDomain
                                             code:OSSClientErrorCodeInvalidArgument
                                         userInfo:@{OSSErrorMessageTOKEN: @"bucketName should not be empty!"}];
        return [OSSTask taskWithError:error];
    }
    if (![request.objectName oss_isNotEmpty]) {
        NSError *error = [NSError errorWithDomain:OSSTaskErrorDomain
                                             code:OSSClientErrorCodeInvalidArgument
                                         userInfo:@{OSSErrorMessageTOKEN: @"objectName should not be empty!"}];
        return [OSSTask taskWithError:error];
    }
    OSSNetworkingRequestDelegate *requestDelegate = request.requestDelegate;
    NSMutableDictionary *querys = [NSMutableDictionary dictionary];
    [querys setObject:@"" forKey:@"x-oss-process"];
    NSString *paramString = [request.callbackParam base64JsonString];
    NSString *variblesString = [request.callbackVar base64JsonString];
    requestDelegate.uploadingData = [OSSUtil constructHttpBodyForTriggerCallback:paramString callbackVaribles:variblesString];
    NSString *md5String = [OSSUtil base64Md5ForData:requestDelegate.uploadingData];
    
    
    OSSHttpResponseParser *responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeTriggerCallBack];
    requestDelegate.responseParser = responseParser;
    NSString *dateString = [[NSDate oss_clockSkewFixedDate] oss_asStringValue];
    
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                                                 httpMethod:@"POST" bucketName:request.bucketName objectKey:request.objectName type:nil
                                                                                        md5:md5String
                                                                                      range:nil
                                                                                       date:dateString
                                                                               headerParams:nil
                                                                                     querys:querys
                                                                                       sha1:nil];
    requestDelegate.operType = OSSOperationTypeTriggerCallBack;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

# pragma mark - Private Methods

- (void)enableCRC64WithFlag:(OSSRequestCRCFlag)flag requestDelegate:(OSSNetworkingRequestDelegate *)delegate
{
    switch (flag) {
        case OSSRequestCRCOpen:
            delegate.crc64Verifiable = YES;
            break;
        case OSSRequestCRCClosed:
            delegate.crc64Verifiable = NO;
            break;
        default:
            delegate.crc64Verifiable = self.clientConfiguration.crc64Verifiable;
            break;
    }
}

- (OSSTask *)preChecksForRequest:(OSSMultipartUploadRequest *)request
{
    OSSTask *preTask = [self checkFileSizeWithRequest:request];
    if (preTask) {
        return preTask;
    }
    
    preTask = [self checkNecessaryParamsOfRequest:request];
    if (preTask) {
        return preTask;
    }
    
    preTask = [self checkPartSizeForRequest:request];
    if (preTask) {
        return preTask;
    }
    
    
    return preTask;
}

- (void)checkRequestCrc64Setting:(OSSRequest *)request
{
    if (request.crcFlag == OSSRequestCRCUninitialized)
    {
        if (self.clientConfiguration.crc64Verifiable)
        {
            request.crcFlag = OSSRequestCRCOpen;
        }else
        {
            request.crcFlag = OSSRequestCRCClosed;
        }
    }
}

- (OSSTask *)checkNecessaryParamsOfRequest:(OSSMultipartUploadRequest *)request
{
    NSError *error = nil;
    if (![request.objectKey oss_isNotEmpty]) {
        error = [NSError errorWithDomain:OSSClientErrorDomain
                                    code:OSSClientErrorCodeInvalidArgument
                                userInfo:@{OSSErrorMessageTOKEN: @"checkNecessaryParamsOfRequest requires nonnull objectKey!"}];
    }else if (![request.bucketName oss_isNotEmpty]) {
        error = [NSError errorWithDomain:OSSClientErrorDomain
                                    code:OSSClientErrorCodeInvalidArgument
                                userInfo:@{OSSErrorMessageTOKEN: @"checkNecessaryParamsOfRequest requires nonnull bucketName!"}];
    }else if (![request.uploadingFileURL.path oss_isNotEmpty]) {
        error = [NSError errorWithDomain:OSSClientErrorDomain
                                    code:OSSClientErrorCodeInvalidArgument
                                userInfo:@{OSSErrorMessageTOKEN: @"checkNecessaryParamsOfRequest requires nonnull uploadingFileURL!"}];
    }
    
    OSSTask *errorTask = nil;
    if (error) {
        errorTask = [OSSTask taskWithError:error];
    }
    
    return errorTask;
}

- (OSSTask *)checkPartSizeForRequest:(OSSMultipartUploadRequest *)request
{
    OSSTask *errorTask = nil;
    if (request.partSize < 100 * 1024) {
        NSError *error = [NSError errorWithDomain:OSSClientErrorDomain
                                             code:OSSClientErrorCodeInvalidArgument
                                         userInfo:@{OSSErrorMessageTOKEN: @"Part size must be greater than equal to 100KB"}];
        errorTask = [OSSTask taskWithError:error];
    }
    return errorTask;
}

- (NSInteger)judgePartSizeForMultipartRequest:(OSSMultipartUploadRequest *)request fileSize:(int64_t)fileSize
{
    BOOL divisible = (fileSize % request.partSize == 0);
    NSInteger partCount = (fileSize / request.partSize) + (divisible? 0 : 1);
    
    if(partCount > oss_multipart_max_part_number)
    {
        request.partSize = fileSize / oss_multipart_max_part_number;
        partCount = oss_multipart_max_part_number;
    }
    return partCount;
}

- (unsigned long long)getSizeWithFilePath:(nonnull NSString *)filePath error:(NSError **)error
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attributes = [fm attributesOfItemAtPath:filePath error:error];
    NSNumber *fileSizeNumber = attributes[NSFileSize];
    return [fileSizeNumber unsignedLongLongValue];
}

- (NSString *)readUploadIdWithFilePath:(NSString *)filePath
                            recordPath:(NSString *)recordPath
                                bucket:(NSString *)bucket
                             objectKey:(NSString *)objectKey
                              partSize:(NSInteger)partSize
                        recordFilePath:(NSString **)recordFilePath
                            sequential:(BOOL)sequential
                               crcFlag:(OSSRequestCRCFlag)flag
{
    NSString *uploadId = nil;
    NSString *uploadingFilePathMd5 = [OSSUtil fileMD5String: filePath];
    NSString *record = [NSString stringWithFormat:@"%@%@%@%zi", uploadingFilePathMd5, bucket, objectKey, partSize];
    if (sequential) {
        record = [record stringByAppendingString:oss_record_info_suffix_with_sequential];
    }
    if (flag == OSSRequestCRCOpen) {
        record = [record stringByAppendingString:oss_record_info_suffix_with_crc];
    }
    
    NSData *data = [record dataUsingEncoding:NSUTF8StringEncoding];
    NSString *recordFileName = [OSSUtil dataMD5String:data];
    *recordFilePath = [recordPath stringByAppendingPathComponent: recordFileName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath: *recordFilePath]) {
        NSFileHandle * read = [NSFileHandle fileHandleForReadingAtPath:*recordFilePath];
        uploadId = [[NSString alloc] initWithData:[read readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        [read closeFile];
    } else {
        [fileManager createFileAtPath:*recordFilePath contents:nil attributes:nil];
    }
    return uploadId;
}

#pragma mark - sequential multipart upload

- (OSSTask *)sequentialUpload:(OSSMultipartUploadRequest *)request
                  uploadIndex:(NSMutableArray *)alreadyUploadIndex
                   uploadPart:(NSMutableArray *)alreadyUploadPart
                        count:(NSUInteger)partCout
               uploadedLength:(NSUInteger *)uploadedLength
                     fileSize:(unsigned long long)uploadFileSize
{
    OSSRequestCRCFlag crcFlag = request.crcFlag;
    __block BOOL isCancel = NO;
    __block OSSTask *errorTask;
    __block NSMutableDictionary *localPartInfos = nil;
    
    if (crcFlag == OSSRequestCRCOpen) {
        localPartInfos = [self localPartInfosDictoryWithUploadId:request.uploadId];
    }
    
    if (!localPartInfos) {
        localPartInfos = [NSMutableDictionary dictionary];
    }
    
    NSInputStream *inputStream = [NSInputStream inputStreamWithURL:request.uploadingFileURL];
    [inputStream open];
    
    NSData * uploadPartData;
    NSInteger realPartLength = request.partSize;
    
    for (int i = 1; i <= partCout; i++) {
        @autoreleasepool{
            if (i == partCout) {
                realPartLength = uploadFileSize - request.partSize * (i - 1);
            }
            NSMutableData *myBuffer = [NSMutableData dataWithLength:realPartLength];
            uint8_t *buffer = [myBuffer mutableBytes];
            NSInteger length = [inputStream read:buffer maxLength:realPartLength];
            uploadPartData = [NSData dataWithBytes:buffer length:length];
            
            if (![inputStream hasBytesAvailable]) {
                [inputStream close];
            }
            //alreadyUploadIndex 为空 return false
            if (alreadyUploadIndex && [alreadyUploadIndex containsObject:@(i)]) {
                continue;
            }
            
            if (request.isCancelled) {
                @synchronized(lock){
                    if(!isCancel){
                        isCancel = YES;
                    }
                }
            } else {
                OSSUploadPartRequest * uploadPart = [OSSUploadPartRequest new];
                uploadPart.bucketName = request.bucketName;
                uploadPart.objectkey = request.objectKey;
                uploadPart.partNumber = i;
                uploadPart.uploadId = request.uploadId;
                uploadPart.uploadPartData = uploadPartData;
                uploadPart.contentMd5 = [OSSUtil base64Md5ForData:uploadPartData];
                uploadPart.crcFlag = request.crcFlag;
                
                OSSTask * uploadPartTask = [self uploadPart:uploadPart];
                [uploadPartTask waitUntilFinished];
                if (uploadPartTask.error && uploadPartTask.error.code != 409) {
                    errorTask = uploadPartTask;
                    break;
                } else {
                    OSSUploadPartResult * result = uploadPartTask.result;
                    OSSPartInfo * partInfo = [OSSPartInfo new];
                    partInfo.partNum = i;
                    partInfo.eTag = result.eTag;
                    partInfo.size = realPartLength;
                    uint64_t crc64OfPart;
                    @try {
                        NSScanner *scanner = [NSScanner scannerWithString:result.remoteCRC64ecma];
                        [scanner scanUnsignedLongLong:&crc64OfPart];
                        partInfo.crc64 = crc64OfPart;
                    } @catch (NSException *exception) {
                        OSSLogError(@"multipart upload error with nil remote crc64!");
                    }
                    
                    @synchronized(lock){
                        
                        [alreadyUploadPart addObject:partInfo];
                        
                        if (crcFlag == OSSRequestCRCOpen)
                        {
                            [self processForLocalPartInfos:localPartInfos
                                                  partInfo:partInfo
                                                  uploadId:request.uploadId];
                            [self persistencePartInfos:localPartInfos
                                          withUploadId:request.uploadId];
                        }
                        *uploadedLength += realPartLength;
                        if (request.uploadProgress)
                        {
                            request.uploadProgress(realPartLength, *uploadedLength, uploadFileSize);
                        }
                    }
                }
            }
            if (isCancel) {
                errorTask = [OSSTask taskWithError:[OSSClient cancelError]];
                break;
            }
        }
    }
    
    return errorTask;
}

- (NSMutableDictionary *)localPartInfosDictoryWithUploadId:(NSString *)uploadId
{
    NSMutableDictionary *localPartInfoDict = nil;
    NSString *partInfosDirectory = [[NSString oss_documentDirectory] stringByAppendingPathComponent:oss_partInfos_storage_name];
    NSString *partInfosPath = [partInfosDirectory stringByAppendingPathComponent:uploadId];
    BOOL isDirectory;
    NSFileManager *defaultFM = [NSFileManager defaultManager];
    if (!([defaultFM fileExistsAtPath:partInfosDirectory isDirectory:&isDirectory] && isDirectory))
    {
        if (![defaultFM createDirectoryAtPath:partInfosDirectory
                                       withIntermediateDirectories:NO
                                                        attributes:nil error:nil]) {
            OSSLogError(@"create Directory(%@) failed!",partInfosDirectory);
        };
    }
    
    if (![defaultFM fileExistsAtPath:partInfosPath])
    {
        if (![defaultFM createFileAtPath:partInfosPath
                               contents:nil
                             attributes:nil])
        {
            OSSLogError(@"create local partInfo file failed!");
        }
    }
    localPartInfoDict = [[NSMutableDictionary alloc] initWithContentsOfURL:[NSURL fileURLWithPath:partInfosPath]];
    return localPartInfoDict;
}

- (OSSTask *)persistencePartInfos:(NSDictionary *)partInfos withUploadId:(NSString *)uploadId
{
    NSString *filePath = [[[NSString oss_documentDirectory] stringByAppendingPathComponent:oss_partInfos_storage_name] stringByAppendingPathComponent:uploadId];
    if (![partInfos writeToFile:filePath atomically:YES])
    {
        NSError *error = [NSError errorWithDomain:OSSClientErrorDomain
                                             code:OSSClientErrorCodeFileCantWrite
                                         userInfo:@{OSSErrorMessageTOKEN: @"uploadId for this task can't be stored persistentially!"}];
        OSSLogDebug(@"[Error]: %@", error);
        return [OSSTask taskWithError:error];
    }
    return nil;
}

- (OSSTask *)checkFileSizeWithRequest:(OSSMultipartUploadRequest *)request {
    NSError *error = nil;
    if (!request.uploadingFileURL || ![request.uploadingFileURL.path oss_isNotEmpty]) {
        error = [NSError errorWithDomain:OSSClientErrorDomain
                                    code:OSSClientErrorCodeInvalidArgument
                                userInfo:@{OSSErrorMessageTOKEN: @"Please check your request's uploadingFileURL!"}];
    }else
    {
        NSFileManager *dfm = [NSFileManager defaultManager];
        NSDictionary *attributes = [dfm attributesOfItemAtPath:request.uploadingFileURL.path error:&error];
        unsigned long long fileSize = [attributes[NSFileSize] unsignedLongLongValue];
        if (!error && fileSize == 0) {
            error = [NSError errorWithDomain:OSSClientErrorDomain
                                        code:OSSClientErrorCodeInvalidArgument
                                    userInfo:@{OSSErrorMessageTOKEN: @"File length must not be 0!"}];
        }
    }
    
    if (error) {
        return [OSSTask taskWithError:error];
    } else {
        return nil;
    }
}

+ (NSError *)cancelError{
    static NSError *error = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        error = [NSError errorWithDomain:OSSClientErrorDomain
                                    code:OSSClientErrorCodeTaskCancelled
                                userInfo:@{OSSErrorMessageTOKEN: @"This task has been cancelled!"}];
    });
    return error;
}

@end
