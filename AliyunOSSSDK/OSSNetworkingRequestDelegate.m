//
//  OSSNetworkingRequestDelegate.m
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/22.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "OSSNetworkingRequestDelegate.h"

#import "OSSAllRequestNeededMessage.h"
#import "OSSURLRequestRetryHandler.h"
#import "OSSHttpResponseParser.h"
#import "OSSDefine.h"
#import "OSSUtil.h"
#import "OSSLog.h"
#import "OSSIPv6Adapter.h"

@implementation OSSNetworkingRequestDelegate

- (instancetype)init {
    if (self = [super init]) {
        self.retryHandler = [OSSURLRequestRetryHandler defaultRetryHandler];
        self.interceptors = [[NSMutableArray alloc] init];
        self.isHttpdnsEnable = YES;
    }
    return self;
}

- (void)reset {
    self.isHttpRequestNotSuccessResponse = NO;
    self.error = nil;
    self.payloadTotalBytesWritten = 0;
    self.isRequestCancelled = NO;
    [self.responseParser reset];
}

- (void)cancel {
    self.isRequestCancelled = YES;
    if (self.currentSessionTask) {
        OSSLogDebug(@"this task is cancelled now!");
        [self.currentSessionTask cancel];
    }
}

- (OSSTask *)validateRequestParams {
    NSString * errorMessage = nil;
    
    if ((self.operType == OSSOperationTypeAppendObject || self.operType == OSSOperationTypePutObject || self.operType == OSSOperationTypeUploadPart)
        && !self.uploadingData && !self.uploadingFileURL) {
        errorMessage = @"This operation need data or file to upload but none is set";
    }
    
    if (self.uploadingFileURL && ![[NSFileManager defaultManager] fileExistsAtPath:[self.uploadingFileURL path]]) {
        errorMessage = @"File doesn't exist";
    }
    
    if (errorMessage) {
        return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                          code:OSSClientErrorCodeInvalidArgument
                                                      userInfo:@{OSSErrorMessageTOKEN: errorMessage}]];
    } else {
        return [self.allNeededMessage validateRequestParamsInOperationType:self.operType];
    }
}

- (OSSTask *)buildInternalHttpRequest {
    
    OSSTask * validateParam = [self validateRequestParams];
    if (validateParam.error) {
        return validateParam;
    }
    
#define URLENCODE(a) [OSSUtil encodeURL:(a)]
    OSSLogDebug(@"start to build request")
    // build base url string
    NSString *bucketName = self.allNeededMessage.bucketName;
    NSString *objectKey = self.allNeededMessage.objectKey;
    NSString *urlString = self.allNeededMessage.endpoint;
    NSURLComponents *temComs = [[NSURLComponents alloc] initWithString:urlString];
    
    NSString *host = [self buildCanonicalHost:temComs.host
                                   bucketName:bucketName];
    NSString *path = [self buildCanonicalPathWithUrlPath:temComs.path
                                              bucketName:bucketName
                                               objectKey:objectKey];
    NSString *queryString = [self buildQueryStringWithParams:self.allNeededMessage.params];
    
    NSURLComponents *urlComponents = [NSURLComponents new];
    urlComponents.scheme = temComs.scheme;
    urlComponents.host = host;
    urlComponents.port = temComs.port;
    urlComponents.path = path;
    urlComponents.query = queryString;
    
    urlString = urlComponents.string;
    OSSLogDebug(@"built full url: %@", urlString)
    
    // generate internal request For NSURLSession
    self.internalRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    
    // set http method of request
    if (self.allNeededMessage.httpMethod) {
        [self.internalRequest setHTTPMethod:self.allNeededMessage.httpMethod];
    }
    
    // set host of header fields
    if ([urlComponents.host oss_isNotEmpty]) {
        [self.internalRequest setValue:urlComponents.host forHTTPHeaderField:@"Host"];
    }
    
    if (self.allNeededMessage.contentType) {
        [self.internalRequest setValue:self.allNeededMessage.contentType forHTTPHeaderField:@"Content-Type"];
    }
    if (self.allNeededMessage.contentMd5) {
        [self.internalRequest setValue:self.allNeededMessage.contentMd5 forHTTPHeaderField:@"Content-MD5"];
    }
    if (self.allNeededMessage.date) {
        [self.internalRequest setValue:self.allNeededMessage.date forHTTPHeaderField:@"Date"];
    }
    if (self.allNeededMessage.range) {
        [self.internalRequest setValue:self.allNeededMessage.range forHTTPHeaderField:@"Range"];
    }
    if (self.allNeededMessage.contentSHA1) {
        [self.internalRequest setValue:_allNeededMessage.contentSHA1 forHTTPHeaderField:@"x-oss-hash-sha1"];
    }
    if (self.allNeededMessage.headerParams) {
        for (NSString * key in [self.allNeededMessage.headerParams allKeys]) {
            [self.internalRequest setValue:[self.allNeededMessage.headerParams objectForKey:key] forHTTPHeaderField:key];
        }
    }
    
    
    OSSLogVerbose(@"buidlInternalHttpRequest -\nmethod: %@\nurl: %@\nheader: %@", self.internalRequest.HTTPMethod,
                  self.internalRequest.URL, self.internalRequest.allHTTPHeaderFields)
    
#undef URLENCODE//(a)
    return [OSSTask taskWithResult:nil];
}

- (NSString *)buildCanonicalHost:(NSString *)originHost bucketName:(NSString *)bucketName {
    NSMutableString *host = [NSMutableString string];
    
    BOOL isCname = (self.isSupportCnameEnable && [self cnameExcludeFilter:originHost]);
    if (bucketName != nil && !isCname && !self.isPathStyleAccessEnable) {
        [host appendString:bucketName];
        [host appendString:@"."];
    }
    [host appendString:originHost];
    return host;
}

- (BOOL)cnameExcludeFilter:(NSString *)originHost {
    for (NSString *host in self.cnameExcludeList) {
        if ([host hasSuffix:originHost]) {
            return false;
        }
    }
    return true;
}

- (NSString *)buildCanonicalPathWithUrlPath:(NSString *)urlPath bucketName:(NSString *)bucketName objectKey:(NSString *)objectKey {
    NSString *basePath = (self.isCustomPathPrefixEnable && [urlPath oss_isNotEmpty]) ? urlPath : @"";
    NSMutableString *path = [NSMutableString stringWithString:basePath];
    if (self.isPathStyleAccessEnable && bucketName.oss_isNotEmpty) {
        [path appendFormat:@"/%@", bucketName];
    }
    if (objectKey.oss_isNotEmpty) {
        [path appendFormat:@"/%@", [OSSUtil encodeURL:objectKey]];
    }
    return path;
}

- (NSString *)buildQueryStringWithParams:(NSDictionary *)params {
    if (params) {
        NSMutableArray * querys = [[NSMutableArray alloc] init];
        for (NSString * key in [params allKeys]) {
            NSString * value = [params objectForKey:key];
            if (value) {
                if ([value isEqualToString:@""]) {
                    [querys addObject:[OSSUtil encodeURL:key]];
                } else {
                    [querys addObject:[NSString stringWithFormat:@"%@=%@", [OSSUtil encodeURL:key], [OSSUtil encodeURL:value]]];
                }
            }
        }
        if (querys && [querys count]) {
            NSString * queryString = [querys componentsJoinedByString:@"&"];
            return queryString;
        }
    }
    return nil;
}

@end
