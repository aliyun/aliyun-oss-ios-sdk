//
//  OSSNetworking.m
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OSSDefine.h"
#import "OSSNetworking.h"
#import "OSSBolts.h"
#import "OSSModel.h"
#import "OSSUtil.h"
#import "OSSLog.h"
#import "OSSXMLDictionary.h"


@implementation OSSURLRequestRetryHandler

- (OSSNetworkingRetryType)shouldRetry:(uint32_t)currentRetryCount
                      requestDelegate:(OSSNetworkingRequestDelegate *)delegate
                             response:(NSHTTPURLResponse *)response
                                error:(NSError *)error {

    if (currentRetryCount >= self.maxRetryCount) {
        return OSSNetworkingRetryTypeShouldNotRetry;
    }
    
    /**
     设置onRecieveData回调时，在回调处理数据时无法获知重试事件
     出错时，禁止重试
     */
    if (delegate.onRecieveData != nil) {
        return OSSNetworkingRetryTypeShouldNotRetry;
    }
    
    if ([error.domain isEqualToString:OSSClientErrorDomain]) {
        if (error.code == OSSClientErrorCodeTaskCancelled) {
            return OSSNetworkingRetryTypeShouldNotRetry;
        } else {
            return OSSNetworkingRetryTypeShouldRetry;
        }
    }

    switch (response.statusCode) {
        case 403:
            if ([[[error userInfo] objectForKey:@"Code"] isEqualToString:@"RequestTimeTooSkewed"]) {
                return OSSNetworkingRetryTypeShouldCorrectClockSkewAndRetry;
            }
            break;

        default:
            break;
    }

    return OSSNetworkingRetryTypeShouldNotRetry;
}

- (NSTimeInterval)timeIntervalForRetry:(uint32_t)currentRetryCount retryType:(OSSNetworkingRetryType)retryType {
    switch (retryType) {
        case OSSNetworkingRetryTypeShouldCorrectClockSkewAndRetry:
        case OSSNetworkingRetryTypeShouldRefreshCredentialsAndRetry:
            return 0;

        default:
            return pow(2, currentRetryCount) * 200 / 1000;
    }
}

+ (instancetype)defaultRetryHandler {
    OSSURLRequestRetryHandler * retryHandler = [OSSURLRequestRetryHandler new];
    retryHandler.maxRetryCount = OSSDefaultRetryCount;
    return retryHandler;
}

@end

@implementation OSSNetworkingConfiguration
@end

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
    if (self.allNeededMessage.querys) {
        NSMutableArray * querys = [[NSMutableArray alloc] init];
        for (NSString * key in [self.allNeededMessage.querys allKeys]) {
            NSString * value = [self.allNeededMessage.querys objectForKey:key];
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

@implementation OSSAllRequestNeededMessage

- (instancetype)initWithEndpoint:(NSString *)endpoint
                      httpMethod:(NSString *)httpMethod
                      bucketName:(NSString *)bucketName
                       objectKey:(NSString *)objectKey
                            type:(NSString *)contentType
                             md5:(NSString *)contentMd5
                           range:(NSString *)range
                            date:(NSString *)date
                    headerParams:(NSMutableDictionary *)headerParams
                          querys:(NSMutableDictionary *)querys {

    if (self = [super init]) {
        _endpoint = endpoint;
        _httpMethod = httpMethod;
        _bucketName = bucketName;
        _objectKey = objectKey;
        _contentType = contentType;
        _contentMd5 = contentMd5;
        _range = range;
        _date = date;
        _headerParams = headerParams;
        if (!_headerParams) {
            _headerParams = [NSMutableDictionary new];
        }
        _querys = querys;
        if (!_querys) {
            _querys = [NSMutableDictionary new];
        }
    }
    return self;
}

- (OSSTask *)validateRequestParamsInOperationType:(OSSOperationType)operType {
    NSString * errorMessage = nil;

    if (!self.endpoint) {
        errorMessage = @"Endpoint should not be nil";
    }

    if (!self.bucketName && operType != OSSOperationTypeGetService) {
        errorMessage = @"Bucket name should not be nil";
    }

    if (self.bucketName && ![OSSUtil validateBucketName:self.bucketName]) {
        errorMessage = @"Bucket name invalid";
    }

    if (!self.objectKey &&
        (operType != OSSOperationTypeGetBucket && operType != OSSOperationTypeCreateBucket
         && operType != OSSOperationTypeDeleteBucket && operType != OSSOperationTypeGetService
         && operType != OSSOperationTypeGetBucketACL)) {
        errorMessage = @"Object key should not be nil";
    }

    if (self.objectKey && ![OSSUtil validateObjectKey:self.objectKey]) {
        errorMessage = @"Object key invalid";
    }

    if (errorMessage) {
        return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                         code:OSSClientErrorCodeInvalidArgument
                                                     userInfo:@{OSSErrorMessageTOKEN: errorMessage}]];
    } else {
        return [OSSTask taskWithResult:nil];
    }
}

@end

@implementation OSSNetworking

- (instancetype)initWithConfiguration:(OSSNetworkingConfiguration *)configuration {
    if (self = [super init]) {
        self.configuration = configuration;

        NSOperationQueue * operationQueue = [NSOperationQueue new];
        NSURLSessionConfiguration * dataSessionConfig = nil;
        NSURLSessionConfiguration * uploadSessionConfig = nil;

        if (configuration.enableBackgroundTransmitService) {
            if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
                uploadSessionConfig = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:self.configuration.backgroundSessionIdentifier];
            } else {
                uploadSessionConfig = [NSURLSessionConfiguration backgroundSessionConfiguration:self.configuration.backgroundSessionIdentifier];
            }
        } else {
            uploadSessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        }
        dataSessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];

        if (configuration.timeoutIntervalForRequest > 0) {
            uploadSessionConfig.timeoutIntervalForRequest = configuration.timeoutIntervalForRequest;
            dataSessionConfig.timeoutIntervalForRequest = configuration.timeoutIntervalForRequest;
        }
        if (configuration.timeoutIntervalForResource > 0) {
            uploadSessionConfig.timeoutIntervalForResource = configuration.timeoutIntervalForResource;
            dataSessionConfig.timeoutIntervalForResource = configuration.timeoutIntervalForResource;
        }
        dataSessionConfig.URLCache = nil;
        uploadSessionConfig.URLCache = nil;
        if (configuration.proxyHost && configuration.proxyPort) {
            // Create an NSURLSessionConfiguration that uses the proxy
            NSDictionary *proxyDict = @{
                                        @"HTTPEnable"  : [NSNumber numberWithInt:1],
                                        (NSString *)kCFStreamPropertyHTTPProxyHost  : configuration.proxyHost,
                                        (NSString *)kCFStreamPropertyHTTPProxyPort  : configuration.proxyPort,

                                        @"HTTPSEnable" : [NSNumber numberWithInt:1],
                                        (NSString *)kCFStreamPropertyHTTPSProxyHost : configuration.proxyHost,
                                        (NSString *)kCFStreamPropertyHTTPSProxyPort : configuration.proxyPort,
                                        };
            dataSessionConfig.connectionProxyDictionary = proxyDict;
            uploadSessionConfig.connectionProxyDictionary = proxyDict;
        }

        _dataSession = [NSURLSession sessionWithConfiguration:dataSessionConfig
                                                 delegate:self
                                            delegateQueue:operationQueue];
        _uploadFileSession = [NSURLSession sessionWithConfiguration:uploadSessionConfig
                                                       delegate:self
                                                  delegateQueue:operationQueue];

        self.isUsingBackgroundSession = configuration.enableBackgroundTransmitService;
        _sessionDelagateManager = [OSSSyncMutableDictionary new];

        NSOperationQueue * queue = [NSOperationQueue new];
        if (configuration.maxConcurrentRequestCount) {
            queue.maxConcurrentOperationCount = configuration.maxConcurrentRequestCount;
        }
        self.taskExecutor = [OSSExecutor executorWithOperationQueue:queue];
    }
    return self;
}

- (OSSTask *)sendRequest:(OSSNetworkingRequestDelegate *)request {
    OSSLogVerbose(@"send request --------");
    if (self.configuration.proxyHost && self.configuration.proxyPort) {
        request.isAccessViaProxy = YES;
    }

    /* set maximum retry */
    request.retryHandler.maxRetryCount = self.configuration.maxRetryCount;

    OSSTaskCompletionSource * taskCompletionSource = [OSSTaskCompletionSource taskCompletionSource];

    __weak OSSNetworkingRequestDelegate * ref = request;
    request.completionHandler = ^(id responseObject, NSError * error) {

        [ref reset];
        if (!error) {
            [taskCompletionSource setResult:responseObject];
        } else {
            [taskCompletionSource setError:error];
        }
    };
    [self dataTaskWithDelegate:request];
    return taskCompletionSource.task;
}

- (void)dataTaskWithDelegate:(OSSNetworkingRequestDelegate *)requestDelegate {

    [[[[[OSSTask taskWithResult:nil] continueWithExecutor:self.taskExecutor withSuccessBlock:^id(OSSTask *task) {
        OSSLogVerbose(@"start to intercept request");
        for (id<OSSRequestInterceptor> interceptor in requestDelegate.interceptors) {
            task = [interceptor interceptRequestMessage:requestDelegate.allNeededMessage];
            if (task.error) {
                return task;
            }
        }
        return task;
    }] continueWithSuccessBlock:^id(OSSTask *task) {
        return [requestDelegate buildInternalHttpRequest];
    }] continueWithSuccessBlock:^id(OSSTask *task) {
        NSURLSessionDataTask * sessionTask = nil;
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0 && self.configuration.timeoutIntervalForRequest > 0) {
            requestDelegate.internalRequest.timeoutInterval = self.configuration.timeoutIntervalForRequest;
        }

        if (requestDelegate.uploadingData) {
            [requestDelegate.internalRequest setHTTPBody:requestDelegate.uploadingData];
            sessionTask = [_dataSession dataTaskWithRequest:requestDelegate.internalRequest];
        } else if (requestDelegate.uploadingFileURL) {
            sessionTask = [_uploadFileSession uploadTaskWithRequest:requestDelegate.internalRequest fromFile:requestDelegate.uploadingFileURL];

            if (self.isUsingBackgroundSession) {
                requestDelegate.isBackgroundUploadFileTask = YES;
            }
        } else { // not upload request
            sessionTask = [_dataSession dataTaskWithRequest:requestDelegate.internalRequest];
        }

        requestDelegate.currentSessionTask = sessionTask;
        requestDelegate.httpRequestNotSuccessResponseBody = [NSMutableData new];
        [self.sessionDelagateManager setObject:requestDelegate forKey:@(sessionTask.taskIdentifier)];
        if (requestDelegate.isRequestCancelled) {
            return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                              code:OSSClientErrorCodeTaskCancelled
                                                          userInfo:nil]];
        }
        [sessionTask resume];

        return task;
    }] continueWithBlock:^id(OSSTask *task) {

        // if error occurs before created sessionTask
        if (task.error) {
            requestDelegate.completionHandler(nil, task.error);
        } else if (task.isFaulted) {
            requestDelegate.completionHandler(nil, [NSError errorWithDomain:OSSClientErrorDomain
                                                                       code:OSSClientErrorCodeExcpetionCatched
                                                                   userInfo:@{OSSErrorMessageTOKEN: [NSString stringWithFormat:@"Catch exception - %@", task.exception]}]);
        }
        return nil;
    }];
}

#pragma mark - delegate method

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)sessionTask didCompleteWithError:(NSError *)error {
    OSSNetworkingRequestDelegate * delegate = [self.sessionDelagateManager objectForKey:@(sessionTask.taskIdentifier)];
    [self.sessionDelagateManager removeObjectForKey:@(sessionTask.taskIdentifier)];

    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)sessionTask.response;
    if (delegate == nil) {
        OSSLogVerbose(@"delegate: %@", delegate);
        /* if the background transfer service is enable, may recieve the previous task complete callback */
        /* for now, we ignore it */
        return ;
    }

    NSString * dateStr = [[httpResponse allHeaderFields] objectForKey:@"Date"];
    if ([dateStr length]) {
        NSDate * serverTime = [NSDate oss_dateFromString:dateStr];
        NSDate * deviceTime = [NSDate date];
        NSTimeInterval skewTime = [deviceTime timeIntervalSinceDate:serverTime];
        [NSDate oss_setClockSkew:skewTime];
    } else {
        OSSLogError(@"date header does not exist, unable to adjust the time skew");
    }

    /* background upload task will not call back didRecieveResponse */
    if (delegate.isBackgroundUploadFileTask) {
        OSSLogVerbose(@"backgroud upload task did recieve response: %@", httpResponse);
        if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 && httpResponse.statusCode != 203) {
            [delegate.responseParser consumeHttpResponse:httpResponse];
        } else {
            delegate.isHttpRequestNotSuccessResponse = YES;
        }
    }

    [[[[OSSTask taskWithResult:nil] continueWithSuccessBlock:^id(OSSTask * task) {
        if (!delegate.error) {
            delegate.error = error;
        }
        if (delegate.error) {
            OSSLogDebug(@"networking request completed with error: %@", error);
            if ([delegate.error.domain isEqualToString:NSURLErrorDomain] && delegate.error.code == NSURLErrorCancelled) {
                return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                                 code:OSSClientErrorCodeTaskCancelled
                                                             userInfo:[error userInfo]]];
            } else {
                NSMutableDictionary * userInfo = [NSMutableDictionary dictionaryWithDictionary:[error userInfo]];
                [userInfo setObject:[NSString stringWithFormat:@"%ld", (long)error.code] forKey:@"OriginErrorCode"];
                return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                                 code:OSSClientErrorCodeNetworkError
                                                             userInfo:userInfo]];
            }
        }
        return task;
    }] continueWithSuccessBlock:^id(OSSTask *task) {
        if (delegate.isHttpRequestNotSuccessResponse) {
            if (httpResponse.statusCode == 0) {
                return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                                 code:OSSClientErrorCodeNetworkingFailWithResponseCode0
                                                             userInfo:@{OSSErrorMessageTOKEN: @"Request failed, response code 0"}]];
            }
            NSString * notSuccessResponseBody = [[NSString alloc] initWithData:delegate.httpRequestNotSuccessResponseBody encoding:NSUTF8StringEncoding];
            OSSLogError(@"http error response: %@", notSuccessResponseBody);
            NSDictionary * dict = [NSDictionary dictionaryWithXMLString:notSuccessResponseBody];

            return [OSSTask taskWithError:[NSError errorWithDomain:OSSServerErrorDomain
                                                             code:(-1 * httpResponse.statusCode)
                                                         userInfo:dict]];
        }
        return task;
    }] continueWithBlock:^id(OSSTask *task) {
        if (task.error) {
            OSSNetworkingRetryType retryType = [delegate.retryHandler shouldRetry:delegate.currentRetryCount
                                                                  requestDelegate:delegate
                                                                         response:httpResponse
                                                                            error:task.error];
            OSSLogVerbose(@"current retry count: %u, retry type: %d", delegate.currentRetryCount, (int)retryType);

            switch (retryType) {

                case OSSNetworkingRetryTypeShouldNotRetry: {
                    delegate.completionHandler(nil, task.error);
                    return nil;
                }

                case OSSNetworkingRetryTypeShouldCorrectClockSkewAndRetry: {
                    /* correct clock skew */
                    [delegate.interceptors insertObject:[OSSTimeSkewedFixingInterceptor new] atIndex:0];
                    break;
                }

                default:
                    break;
            }

            /* now, should retry */
            NSTimeInterval suspendTime = [delegate.retryHandler timeIntervalForRetry:delegate.currentRetryCount retryType:retryType];
            delegate.currentRetryCount++;
            [NSThread sleepForTimeInterval:suspendTime];

            /* retry recursively */
            [delegate reset];
            [self dataTaskWithDelegate:delegate];
        } else {
            delegate.completionHandler([delegate.responseParser constructResultObject], nil);
        }
        return nil;
    }];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    OSSNetworkingRequestDelegate * delegate = [self.sessionDelagateManager objectForKey:@(task.taskIdentifier)];
    if (delegate.uploadProgress) {
        delegate.uploadProgress(bytesSent, totalBytesSent, totalBytesExpectedToSend);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    OSSNetworkingRequestDelegate * delegate = [self.sessionDelagateManager objectForKey:@(dataTask.taskIdentifier)];

    /* background upload task will not call back didRecieveResponse */
    OSSLogVerbose(@"did receive response: %@", response);
    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 && httpResponse.statusCode != 203) {
        [delegate.responseParser consumeHttpResponse:httpResponse];
    } else {
        delegate.isHttpRequestNotSuccessResponse = YES;
    }
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    OSSNetworkingRequestDelegate * delegate = [self.sessionDelagateManager objectForKey:@(dataTask.taskIdentifier)];

    /* background upload task will not call back didRecieveResponse.
       so if we recieve response data after background uploading file,
       we consider it as error response message since a successful uploading request will not response any data */
    if (delegate.isHttpRequestNotSuccessResponse || delegate.isBackgroundUploadFileTask) {
        [delegate.httpRequestNotSuccessResponseBody appendData:data];
    } else {
        if (delegate.onRecieveData) {
            delegate.onRecieveData(data);
        } else {
            OSSTask * consumeTask = [delegate.responseParser consumeHttpResponseBody:data];
            if (consumeTask.error) {
                OSSLogError(@"consume data error: %@", consumeTask.error);
                delegate.error = consumeTask.error;
                [dataTask cancel];
            }
        }
    }

    if (!delegate.isHttpRequestNotSuccessResponse && delegate.downloadProgress) {
        int64_t bytesWritten = [data length];
        delegate.payloadTotalBytesWritten += bytesWritten;
        int64_t totalBytesExpectedToWrite = dataTask.response.expectedContentLength;
        delegate.downloadProgress(bytesWritten, delegate.payloadTotalBytesWritten, totalBytesExpectedToWrite);
    }
}

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forDomain:(NSString *)domain {
    /*
     * 创建证书校验策略
     */
    NSMutableArray *policies = [NSMutableArray array];
    if (domain) {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateSSL(true, (__bridge CFStringRef)domain)];
    } else {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateBasicX509()];
    }

    /*
     * 绑定校验策略到服务端的证书上
     */
    SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);


    /*
     * 评估当前serverTrust是否可信任，
     * 官方建议在result = kSecTrustResultUnspecified 或 kSecTrustResultProceed
     * 的情况下serverTrust可以被验证通过，https://developer.apple.com/library/ios/technotes/tn2232/_index.html
     * 关于SecTrustResultType的详细信息请参考SecTrust.h
     */
    SecTrustResultType result;
    SecTrustEvaluate(serverTrust, &result);

    return (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed);
}

/*
 * NSURLSession
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * __nullable credential))completionHandler {
    if (!challenge) {
        return;
    }

    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    NSURLCredential *credential = nil;

    /*
     * 获取原始域名信息。
     */

    NSString * host = [[task.currentRequest allHTTPHeaderFields] objectForKey:@"Host"];
    if (!host) {
        host = task.currentRequest.URL.host;
    }

    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if ([self evaluateServerTrust:challenge.protectionSpace.serverTrust forDomain:host]) {
            disposition = NSURLSessionAuthChallengeUseCredential;
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        }
    } else {
        disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    }
    // 对于其他的challenges直接使用默认的验证方案
    completionHandler(disposition,credential);
}
@end
