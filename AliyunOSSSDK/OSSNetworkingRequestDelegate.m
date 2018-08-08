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
    OSSLogDebug(@"start to build request");
    // build base url string
    NSString * urlString = self.allNeededMessage.endpoint;
    
    NSURL * endPointURL = [NSURL URLWithString:self.allNeededMessage.endpoint];
    if ([OSSUtil isOssOriginBucketHost:endPointURL.host] && self.allNeededMessage.bucketName) {
        urlString = [NSString stringWithFormat:@"%@://%@.%@", endPointURL.scheme, self.allNeededMessage.bucketName, endPointURL.host];
    }
    
    endPointURL = [NSURL URLWithString:urlString];
    NSString * urlHost = endPointURL.host;
    if (!self.isAccessViaProxy && [OSSUtil isOssOriginBucketHost:urlHost] && self.isHttpdnsEnable) {
        NSString * httpdnsResolvedResult = [OSSUtil getIpByHost:urlHost];
        urlString = [NSString stringWithFormat:@"%@://%@", endPointURL.scheme, httpdnsResolvedResult];
    }
    
    if (self.allNeededMessage.objectKey) {
        urlString = [urlString oss_stringByAppendingPathComponentForURL:URLENCODE(self.allNeededMessage.objectKey)];
    }
    
    // join query string
    if (self.allNeededMessage.params) {
        NSMutableArray * querys = [[NSMutableArray alloc] init];
        for (NSString * key in [self.allNeededMessage.params allKeys]) {
            NSString * value = [self.allNeededMessage.params objectForKey:key];
            if (value) {
                if ([value isEqualToString:@""]) {
                    [querys addObject:URLENCODE(key)];
                } else {
                    [querys addObject:[NSString stringWithFormat:@"%@=%@", URLENCODE(key), URLENCODE(value)]];
                }
            }
        }
        if (querys && [querys count]) {
            NSString * queryString = [querys componentsJoinedByString:@"&"];
            urlString = [NSString stringWithFormat:@"%@?%@", urlString, queryString];
        }
    }
    OSSLogDebug(@"built full url: %@", urlString);
    
    NSString * headerHost = urlHost;
    if (![OSSUtil isOssOriginBucketHost:urlHost] && self.allNeededMessage.isHostInCnameExcludeList && self.allNeededMessage.bucketName) {
        headerHost = [NSString stringWithFormat:@"%@.%@", self.allNeededMessage.bucketName, urlHost];
    }
    
    // set header fields
    self.internalRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    
    // override default host
    [self.internalRequest setValue:headerHost forHTTPHeaderField:@"Host"];
    
    if (self.allNeededMessage.httpMethod) {
        [self.internalRequest setHTTPMethod:self.allNeededMessage.httpMethod];
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
                  self.internalRequest.URL, self.internalRequest.allHTTPHeaderFields);
    
#undef URLENCODE//(a)
    return [OSSTask taskWithResult:nil];
}
@end
