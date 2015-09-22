//
//  OSSClient.m
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import "OSSClient.h"
#import "OSSModel.h"
#import "OSSUtil.h"
#import "OSSLog.h"
#import "OSSNetworking.h"
#import "OSSXMLDictionary.h"

/**
 * extend OSSRequest to include the ref to networking request object
 */
@interface OSSRequest ()
@property (nonatomic, strong) OSSNetworkingRequestDelegate * requestDelegate;
@end



@implementation OSSClient

- (instancetype)initWithEndpoint:(NSString *)endpoint credentialProvider:(id<OSSCredentialProvider>)credentialProvider {
    return [self initWithEndpoint:endpoint credentialProvider:credentialProvider clientConfiguration:nil];
}

- (instancetype)initWithEndpoint:(NSString *)endpoint
              credentialProvider:(id<OSSCredentialProvider>)credentialProvider
             clientConfiguration:(OSSClientConfiguration *)conf {
    if (self = [super init]) {
        self.endpoint = endpoint;
        self.credentialProvider = credentialProvider;

        OSSNetworkingConfiguration * netConf = [OSSNetworkingConfiguration defaultConfiguration];
        if (conf) {
            netConf.timeoutIntervalForRequest = conf.timeoutIntervalForRequest;
            netConf.timeoutIntervalForResource = conf.timeoutIntervalForResource;
            netConf.enableBackgroundTransmitService = conf.enableBackgroundTransmitService;
            netConf.proxyHost = conf.proxyHost;
            netConf.proxyPort = conf.proxyPort;
        }
        self.networking = [[OSSNetworking alloc] initWithConfiguration:netConf];
    }
    return self;
}

- (OSSTask *)invokeRequest:(OSSNetworkingRequestDelegate *)request requireAuthentication:(BOOL)requireAuthentication {
    request.retryHandler.maxRetryCount = self.clientConfiguration.maxRetryCount;

    id<OSSRequestInterceptor> uaSetting = [OSSUASettingInterceptor new];
    [request.interceptors addObject:uaSetting];

    /* check if the authentication is required */
    if (requireAuthentication) {
        id<OSSRequestInterceptor> signer = [[OSSSignerInterceptor alloc] initWithCredentialProvider:self.credentialProvider];
        [request.interceptors addObject:signer];
    }

    return [_networking sendRequest:request];
}

#pragma implement restful apis

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
                                                    querys:nil];
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
        request.uploadPartProgress = request.uploadPartProgress;
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

    if (request.partInfos) {
        requestDelegate.uploadingData = [OSSUtil constructHttpBodyFromPartInfos:request.partInfos];
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
                                              headerParams:nil
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

- (OSSTask *)presignConstrainURLWithBucketName:(NSString *)bucketName
                                 withObjectKey:(NSString *)objectKey
                        withExpirationInterval:(NSTimeInterval)interval {

    return [[OSSTask taskWithResult:nil] continueWithBlock:^id(OSSTask *task) {
        NSString * resource = [NSString stringWithFormat:@"/%@/%@", bucketName, objectKey];
        NSString * expires = [@((int64_t)[[NSDate oss_clockSkewFixedDate] timeIntervalSince1970] + interval) stringValue];
        OSSFederationToken * token = nil;
        NSError * error = nil;
        if ([self.credentialProvider isKindOfClass:[OSSFederationCredentialProvider class]]) {
            token = [(OSSFederationCredentialProvider *)self.credentialProvider getToken:&error];
            if (error) {
                return [OSSTask taskWithError:error];
            }
            resource = [NSString stringWithFormat:@"%@?security-token=%@", resource, token.tToken];
        }
        NSString * string2sign = [NSString stringWithFormat:@"GET\n\n\n%@\n%@", expires, resource];
        NSString * wholeSign = [self.credentialProvider sign:string2sign error:&error];
        if (error) {
            return [OSSTask taskWithError:error];
        }
        OSSLogDebug(@"string: %@, signature: %@", string2sign, wholeSign);
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
        NSString * stringURL = [NSString stringWithFormat:@"%@://%@.%@/%@?OSSAccessKeyId=%@&Expires=%@&Signature=%@",
                                endpointURL.scheme,
                                bucketName,
                                endpointURL.host,
                                [OSSUtil encodeURL:objectKey],
                                [OSSUtil encodeURL:accessKey],
                                expires,
                                [OSSUtil encodeURL:signature]];
        if ([self.credentialProvider isKindOfClass:[OSSFederationCredentialProvider class]]) {
            if (error) {
                return [OSSTask taskWithError:error];
            }
            stringURL = [NSString stringWithFormat:@"%@&security-token=%@", stringURL, [OSSUtil encodeURL:token.tToken]];
        }
        return [OSSTask taskWithResult:stringURL];
    }];
}

- (OSSTask *)presignPublicURLWithBucketName:(NSString *)bucketName
                             withiObjectKey:(NSString *)objectKey {

    return [[OSSTask taskWithResult:nil] continueWithBlock:^id(OSSTask *task) {
        NSURL * endpointURL = [NSURL URLWithString:self.endpoint];
        NSString * stringURL = [NSString stringWithFormat:@"%@://%@.%@/%@",
                                endpointURL.scheme,
                                bucketName,
                                endpointURL.host,
                                [OSSUtil encodeURL:objectKey]];
        return [OSSTask taskWithResult:stringURL];
    }];
}

@end