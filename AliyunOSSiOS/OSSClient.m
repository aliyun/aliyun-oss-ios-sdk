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
    if (!request.allNeededMessage.contentType.oss_notEmpty
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
                                                    querys:[request getQueryDict]];
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
                                                    querys:nil];
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
                                                    querys:nil];
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
                                                    querys:[request getQueryDict]];
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
                                                    querys:query];
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
                                                    querys:nil];
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
    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetObject];
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
                                                    querys:querys];
    requestDelegate.operType = OSSOperationTypeGetObject;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)putObject:(OSSPutObjectRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    NSMutableDictionary * headerParams = [NSMutableDictionary dictionaryWithDictionary:request.objectMeta];

    if (request.uploadingData) {
        requestDelegate.uploadingData = request.uploadingData;
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
    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutObject];
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"PUT"
                                                bucketName:request.bucketName
                                                 objectKey:request.objectKey
                                                      type:request.contentType
                                                       md5:request.contentMd5
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:headerParams
                                                    querys:nil];
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
                                                    querys:querys];
    requestDelegate.operType = OSSOperationTypePutObjectACL;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)appendObject:(OSSAppendObjectRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    NSMutableDictionary * headerParams = [NSMutableDictionary dictionaryWithDictionary:request.objectMeta];

    if (request.uploadingData) {
        requestDelegate.uploadingData = request.uploadingData;
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
    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeAppendObject];
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"POST"
                                                bucketName:request.bucketName
                                                 objectKey:request.objectKey
                                                      type:request.contentType
                                                       md5:request.contentMd5
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:headerParams
                                                    querys:querys];
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
                                                    querys:nil];
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
                                                    querys:nil];
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
    NSMutableDictionary * querys = [NSMutableDictionary dictionaryWithObject:@"" forKey:@"uploads"];
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
                                                    querys:querys];
    requestDelegate.operType = OSSOperationTypeInitMultipartUpload;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)uploadPart:(OSSUploadPartRequest *)request {
    OSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    NSMutableDictionary * querys = [NSMutableDictionary dictionaryWithObjectsAndKeys:[@(request.partNumber) stringValue], @"partNumber",
                                    request.uploadId, @"uploadId", nil];
    if (request.uploadPartData) {
        requestDelegate.uploadingData = request.uploadPartData;
    }
    if (request.uploadPartFileURL) {
        requestDelegate.uploadingFileURL = request.uploadPartFileURL;
    }
    if (request.uploadPartProgress) {
        requestDelegate.uploadProgress = request.uploadPartProgress;
    }
    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeUploadPart];
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"PUT"
                                                bucketName:request.bucketName
                                                 objectKey:request.objectkey
                                                      type:nil
                                                       md5:request.contentMd5
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:nil
                                                    querys:querys];
    requestDelegate.operType = OSSOperationTypeUploadPart;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)completeMultipartUpload:(OSSCompleteMultipartUploadRequest *)request {
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
    requestDelegate.responseParser = [[OSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeCompleteMultipartUpload];
    requestDelegate.allNeededMessage = [[OSSAllRequestNeededMessage alloc] initWithEndpoint:self.endpoint
                                                httpMethod:@"POST"
                                                bucketName:request.bucketName
                                                 objectKey:request.objectKey
                                                      type:nil
                                                       md5:request.contentMd5
                                                     range:nil
                                                      date:[[NSDate oss_clockSkewFixedDate] oss_asStringValue]
                                              headerParams:headerParams
                                                    querys:querys];
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
                                                    querys:querys];
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
                                                    querys:querys];
    requestDelegate.operType = OSSOperationTypeAbortMultipartUpload;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (OSSTask *)abortResumableMultipartUpload:(OSSResumableUploadRequest *)request {
    
    if(request.recordDirectoryPath){
        NSString *recordPathMd5 = [OSSUtil fileMD5String:[request.uploadingFileURL path]];
        NSData *data = [[NSString stringWithFormat:@"%@%@%@%lld",recordPathMd5,request.bucketName,request.objectKey,request.partSize] dataUsingEncoding:NSUTF8StringEncoding];
        NSString *recordFileName = [OSSUtil dataMD5String:data];
        NSString *recordFilePath = [NSString stringWithFormat:@"%@/%@",request.recordDirectoryPath,recordFileName];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if([fileManager fileExistsAtPath:recordFilePath]){
            OSSAbortMultipartUploadRequest * abort = [OSSAbortMultipartUploadRequest new];
            abort.bucketName = request.bucketName;
            abort.objectKey = request.objectKey;
            abort.uploadId = [[NSString alloc] initWithData:[[NSFileHandle fileHandleForReadingAtPath:recordFilePath] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
            
            NSError *error;
            [fileManager removeItemAtPath:recordFilePath error:&error];
            
            return [self abortMultipartUpload:abort];
        }
    }
    return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                      code:OSSClientErrorCodeInvalidArgument
                                                  userInfo:@{OSSErrorMessageTOKEN: @"resumableupload record file is not exist"}]];
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
    
    __block int64_t expectedUploadLength = 0;
    __block int partCount;
    __block OSSTask *errorTask;
    
    return [[OSSTask taskWithResult:nil] continueWithExecutor:self.ossOperationExecutor withBlock:^id(OSSTask *task) {
        if (!request.objectKey || !request.bucketName || !request.uploadingFileURL) {
            return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                              code:OSSClientErrorCodeInvalidArgument
                                                          userInfo:@{OSSErrorMessageTOKEN: @"MultipartUpload requires uploadId/bucketName/objectKey/uploadingFile."}]];
        }
        if (request.partSize < 100 * 1024) {
            return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                              code:OSSClientErrorCodeInvalidArgument
                                                          userInfo:@{OSSErrorMessageTOKEN: @"Part size must be set bigger than 100KB"}]];
        }
        
        static dispatch_once_t onceToken;
        static NSError * cancelError;
        dispatch_once(&onceToken, ^{
            cancelError = [NSError errorWithDomain:OSSClientErrorDomain
                                              code:OSSClientErrorCodeTaskCancelled
                                          userInfo:@{OSSErrorMessageTOKEN: @"This task is cancelled!"}];
        });
        
        __block int64_t uploadedLength = 0;
        
        OSSInitMultipartUploadRequest * init = [OSSInitMultipartUploadRequest new];
        init.bucketName = request.bucketName;
        init.objectKey = request.objectKey;
        init.objectMeta = request.completeMetaHeader;
        OSSTask * initTask = [self multipartUploadInit:init];
        [[initTask continueWithBlock:^id(OSSTask *task) {
            OSSInitMultipartUploadResult * result = task.result;
            request.uploadId = result.uploadId;
            return nil;
        }] waitUntilFinished];
        
        NSFileManager * fm = [NSFileManager defaultManager];
        NSError * error = nil;;
        int64_t uploadFileSize = [[[fm attributesOfItemAtPath:[request.uploadingFileURL path] error:&error] objectForKey:NSFileSize] longLongValue];
        expectedUploadLength = uploadFileSize;
        if (error) {
            return [OSSTask taskWithError:error];
        }
        partCount = (int)(expectedUploadLength / request.partSize) + (expectedUploadLength % request.partSize != 0);
        
        int maxPartSize = 5000;
        
        if(partCount > maxPartSize){ // check part size
            request.partSize = uploadFileSize / maxPartSize;
            partCount = maxPartSize;
        }
        
        if (request.isCancelled) {
            return [OSSTask taskWithError:cancelError];
        }
        
        NSMutableArray * alreadyUploadPart = [NSMutableArray new];
        
        errorTask = [self upload:request
                     uploadIndex:nil
                      uploadPart:alreadyUploadPart
                           count:partCount
                  uploadedLength:&uploadedLength
                        fileSize:uploadFileSize
                     cancelError:cancelError];
        
        if(errorTask != nil && errorTask.error){
            OSSAbortMultipartUploadRequest * abort = [OSSAbortMultipartUploadRequest new];
            abort.bucketName = request.bucketName;
            abort.objectKey = request.objectKey;
            abort.uploadId = request.uploadId;
            [[self abortMultipartUpload:abort] waitUntilFinished];
            return errorTask;
        }
        
        [alreadyUploadPart sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            OSSPartInfo *partInfo1 = obj1;
            OSSPartInfo *partInfo2 = obj2;
            if(partInfo1.partNum < partInfo2.partNum){
                return NSOrderedAscending;
            }else if(partInfo1.partNum > partInfo2.partNum){
                return NSOrderedDescending;
            }else{
                return NSOrderedSame;
            }
        }];
        OSSCompleteMultipartUploadRequest * complete = [OSSCompleteMultipartUploadRequest new];
        complete.bucketName = request.bucketName;
        complete.objectKey = request.objectKey;
        complete.uploadId = request.uploadId;
        complete.partInfos = alreadyUploadPart;
        if (request.callbackParam != nil) {
            complete.callbackParam = request.callbackParam;
        }
        if (request.callbackVar != nil) {
            complete.callbackVar = request.callbackVar;
        }
        if (request.completeMetaHeader != nil) {
            complete.completeMetaHeader = request.completeMetaHeader;
        }
        OSSTask * completeTask = [self completeMultipartUpload:complete];
        [completeTask waitUntilFinished];
        
        if (completeTask.error) {
            return completeTask;
        } else {
            OSSCompleteMultipartUploadResult * completeResult = completeTask.result;
            return [OSSTask taskWithResult:completeResult];
        }
    }];
}



- (OSSTask *)resumableUpload:(OSSResumableUploadRequest *)request {
    
    return [[OSSTask taskWithResult:nil] continueWithExecutor:self.ossOperationExecutor withBlock:^id(OSSTask *task) {
        if (!request.objectKey || !request.bucketName || !request.uploadingFileURL) {
            return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                             code:OSSClientErrorCodeInvalidArgument
                                                         userInfo:@{OSSErrorMessageTOKEN: @"ResumableUpload requires uploadId/bucketName/objectKey/uploadingFile."}]];
        }
        if (request.partSize < 100 * 1024) {
            return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                             code:OSSClientErrorCodeInvalidArgument
                                                         userInfo:@{OSSErrorMessageTOKEN: @"Part size must be set bigger than 100KB"}]];
        }


        static dispatch_once_t onceToken;
        static NSError * cancelError;
        dispatch_once(&onceToken, ^{
            cancelError = [NSError errorWithDomain:OSSClientErrorDomain
                                              code:OSSClientErrorCodeTaskCancelled
                                          userInfo:@{OSSErrorMessageTOKEN: @"This task is cancelled!"}];
        });
        
        __block int64_t uploadedLength = 0;
        __block OSSTask * errorTask;
        __block NSString *uploadId;
        
        NSFileManager * fm = [NSFileManager defaultManager];
        NSError * error = nil;;
        int64_t uploadFileSize = [[[fm attributesOfItemAtPath:[request.uploadingFileURL path] error:&error] objectForKey:NSFileSize] longLongValue];
        if (error) {
            return [OSSTask taskWithError:error];
        }
        int partCount = (int)(uploadFileSize / request.partSize) + (uploadFileSize % request.partSize != 0 ? 1:0);
        NSArray * uploadedPart = nil;
        NSString *recordFilePath = nil;
        

        if (request.recordDirectoryPath != nil){
            //read saved uploadId
            NSString *recordPathMd5 = [OSSUtil fileMD5String:[request.uploadingFileURL path]];
            NSData *data = [[NSString stringWithFormat:@"%@%@%@%lld",recordPathMd5,request.bucketName,request.objectKey,request.partSize] dataUsingEncoding:NSUTF8StringEncoding];
            NSString *recordFileName = [OSSUtil dataMD5String:data];
            recordFilePath = [NSString stringWithFormat:@"%@/%@",request.recordDirectoryPath,recordFileName];
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if([fileManager fileExistsAtPath:recordFilePath]){
                NSFileHandle * read = [NSFileHandle fileHandleForReadingAtPath:recordFilePath];
                uploadId = [[NSString alloc] initWithData:[read readDataToEndOfFile] encoding:NSUTF8StringEncoding];
                [read closeFile];
            }else{
                [fileManager createFileAtPath:recordFilePath contents:nil attributes:nil];
            }
            if(uploadId != nil){
                OSSListPartsRequest * listParts = [OSSListPartsRequest new];
                listParts.bucketName = request.bucketName;
                listParts.objectKey = request.objectKey;
                listParts.uploadId = uploadId;
                OSSTask * listPartsTask = [self listParts:listParts];
                [listPartsTask waitUntilFinished];
                if (listPartsTask.error) {
                    if ([listPartsTask.error.domain isEqualToString: OSSServerErrorDomain] && listPartsTask.error.code == -1 * 404) {
                        OSSLogVerbose(@"local record existes but the remote record is deleted");
                        uploadId = nil;
                    } else {
                        return listPartsTask;
                    }
                } else {
                    OSSListPartsResult * result = listPartsTask.result;
                    uploadedPart = result.parts;
                    __block int64_t firstPartSize = -1;
                    [uploadedPart enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        NSDictionary * part = obj;
                        uploadedLength += [[part objectForKey:OSSSizeXMLTOKEN] longLongValue];
                        if (idx == 0) {
                            firstPartSize = [[part objectForKey:OSSSizeXMLTOKEN] longLongValue];
                        }
                    }];
                    if (uploadFileSize < uploadedLength) {
                        return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                                          code:OSSClientErrorCodeCannotResumeUpload
                                                                      userInfo:@{OSSErrorMessageTOKEN: @"The uploading file is inconsistent with before"}]];
                    } else if (firstPartSize != -1 && firstPartSize != request.partSize) {
                        return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                                          code:OSSClientErrorCodeCannotResumeUpload
                                                                      userInfo:@{OSSErrorMessageTOKEN: @"The part size setting is inconsistent with before"}]];
                    }
                }
            }
        }
        
        if(uploadId == nil){
            OSSInitMultipartUploadRequest * init = [OSSInitMultipartUploadRequest new];
            init.bucketName = request.bucketName;
            init.objectKey = request.objectKey;
            init.contentType = request.contentType;
            init.objectMeta = request.completeMetaHeader;
            OSSTask * initTask = [self multipartUploadInit:init];
            [[initTask continueWithBlock:^id(OSSTask *task) {
                if(task.error){
                    return task;
                }
                OSSInitMultipartUploadResult * result = task.result;
                uploadId = result.uploadId;
                
                //saved uploadId
                if(recordFilePath.oss_notEmpty)
                {
                    NSFileManager *defaultFileManager = [NSFileManager defaultManager];
                    if (![defaultFileManager fileExistsAtPath:recordFilePath]) {
                        BOOL succeed = [defaultFileManager createFileAtPath:recordFilePath contents:nil attributes:nil];
                        if (succeed) {
                            OSSLogDebug(@"file create succeed!");
                        }else
                        {
                            OSSLogDebug(@"file create failed!");
                            return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain code:OSSClientErrorCodeNotKnown userInfo:@{OSSErrorMessageTOKEN: @"local uploadId file create failed!"}]];
                        }
                    }
                    NSFileHandle * write = [NSFileHandle fileHandleForWritingAtPath:recordFilePath];
                    [write writeData:[result.uploadId dataUsingEncoding:NSUTF8StringEncoding]];
                    [write closeFile];
                }
                return nil;
            }] waitUntilFinished];
        }
        
        request.uploadId = uploadId;
        
        if (request.isCancelled) {
            if(request.deleteUploadIdOnCancelling){
                [self abortResumableMultipartUpload:request];
            }
            return [OSSTask taskWithError:cancelError];
        }

        NSMutableArray * alreadyUploadPart = [NSMutableArray new];
        NSMutableArray * alreadyUploadIndex = [NSMutableArray new];
        
    
        
        [uploadedPart enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary * part = obj;
            OSSPartInfo * partInfo = [OSSPartInfo partInfoWithPartNum:[[part objectForKey:OSSPartNumberXMLTOKEN] intValue]
                                                                 eTag:[part objectForKey:OSSETagXMLTOKEN]
                                                                 size:[[part objectForKey:OSSSizeXMLTOKEN] longLongValue]];
            [alreadyUploadPart addObject:partInfo];
            [alreadyUploadIndex addObject:@(partInfo.partNum)];
        }];

        if ([alreadyUploadIndex count] > 0 && request.uploadProgress && uploadFileSize) {
            request.uploadProgress(0, uploadedLength, uploadFileSize);
        }
        
        errorTask = [self upload:request
                     uploadIndex:alreadyUploadIndex
                      uploadPart:alreadyUploadPart
                           count:partCount
                  uploadedLength:&uploadedLength
                        fileSize:uploadFileSize
                     cancelError:cancelError];
        
        if(errorTask != nil && errorTask.error){
            if(request.deleteUploadIdOnCancelling){
                [self abortResumableMultipartUpload:request];
            }
            return errorTask;
        }
        
        [alreadyUploadPart sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            OSSPartInfo *partInfo1 = obj1;
            OSSPartInfo *partInfo2 = obj2;
            if(partInfo1.partNum < partInfo2.partNum){
                return NSOrderedAscending;
            }else if(partInfo1.partNum > partInfo2.partNum){
                return NSOrderedDescending;
            }else{
                return NSOrderedSame;
            }
        }];
        
        OSSCompleteMultipartUploadRequest * complete = [OSSCompleteMultipartUploadRequest new];
        complete.bucketName = request.bucketName;
        complete.objectKey = request.objectKey;
        complete.uploadId = request.uploadId;
        complete.partInfos = alreadyUploadPart;
        if (request.callbackParam != nil) {
            complete.callbackParam = request.callbackParam;
        }
        if (request.callbackVar != nil) {
            complete.callbackVar = request.callbackVar;
        }
        if (request.completeMetaHeader != nil) {
            complete.completeMetaHeader = request.completeMetaHeader;
        }
        OSSTask * completeTask = [self completeMultipartUpload:complete];
        [completeTask waitUntilFinished];

        if (completeTask.error) {
            return completeTask;
        } else {
            OSSCompleteMultipartUploadResult * completeResult = completeTask.result;
            OSSResumableUploadResult * result = [OSSResumableUploadResult new];
            result.requestId = completeResult.requestId;
            result.httpResponseCode = completeResult.httpResponseCode;
            result.httpResponseHeaderFields = completeResult.httpResponseHeaderFields;
            result.serverReturnJsonString = completeResult.serverReturnJsonString;
            if(recordFilePath){
                [[NSFileManager defaultManager] removeItemAtPath:recordFilePath error:nil];
            }
            return [OSSTask taskWithResult:result];
        }
    }];
}

- (OSSTask *)upload:(OSSMultipartUploadRequest *)request
   uploadIndex:(NSMutableArray *) alreadyUploadIndex
   uploadPart:(NSMutableArray *) alreadyUploadPart
         count:(int)partCout
uploadedLength:(int64_t *)uploadedLength
      fileSize:(int64_t) uploadFileSize
   cancelError:(NSError *) cancelError{
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount: 5];
    
    __block BOOL isCancel = NO;
    __block OSSTask *errorTask;
    for (int i = 1; i <= partCout; i++) {
    
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
                            errorTask = [OSSTask taskWithError:cancelError];
                            [queue cancelAllOperations];
                        }
                    }
                }else{
                    NSFileHandle * handle = [NSFileHandle fileHandleForReadingAtPath:[request.uploadingFileURL path]];
                    [handle seekToFileOffset:(i-1) * request.partSize];
                    int64_t readLength = MIN(request.partSize, uploadFileSize - (request.partSize * (i-1)));
                    
                    OSSUploadPartRequest * uploadPart = [OSSUploadPartRequest new];
                    
                    NSData * uploadPartData = [handle readDataOfLength:(NSUInteger)readLength];
                    [handle closeFile];
                    uploadPart.bucketName = request.bucketName;
                    uploadPart.objectkey = request.objectKey;
                    uploadPart.partNumber = i;
                    uploadPart.uploadId = request.uploadId;
                    uploadPart.uploadPartData = uploadPartData;
                    uploadPart.contentMd5 = [OSSUtil base64Md5ForData:uploadPartData];
                    OSSTask * uploadPartTask = [self uploadPart:uploadPart];
                    [uploadPartTask waitUntilFinished];
                    if (uploadPartTask.error) {
                        errorTask = uploadPartTask;
                    } else {
                        OSSUploadPartResult * result = uploadPartTask.result;
                        OSSPartInfo * partInfo = [OSSPartInfo new];
                        partInfo.partNum = i;
                        partInfo.eTag = result.eTag;
                        @synchronized(lock){
                            [alreadyUploadPart addObject:partInfo];
                            *uploadedLength += readLength;
                            request.uploadProgress(readLength, *uploadedLength, uploadFileSize);
                        }
                    }
                }
            }
        }];
        [queue addOperation:operation];
    }
    
    [queue waitUntilAllOperationsAreFinished];
    
    return errorTask;
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
@end
