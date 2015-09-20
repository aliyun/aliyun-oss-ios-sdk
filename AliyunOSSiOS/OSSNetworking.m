//
//  OSSNetworking.m
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import "OSSNetworking.h"
#import <Bolts/Bolts.h>
#import "OSSModel.h"
#import "OSSUtil.h"
#import "OSSLog.h"
#import "OSSXMLDictionary.h"


@implementation OSSURLRequestRetryHandler

- (OSSNetworkingRetryType)shouldRetry:(uint32_t)currentRetryCount
                             response:(NSHTTPURLResponse *)response
                                error:(NSError *)error {

    if (currentRetryCount > self.maxRetryCount) {
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

    // TODO  federation token access denied
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
    retryHandler.maxRetryCount = 3;
    return retryHandler;
}

@end

@implementation OSSNetworkingConfiguration

+ (instancetype)defaultConfiguration {
    OSSNetworkingConfiguration * conf = [OSSNetworkingConfiguration new];

    conf.timeoutIntervalForRequest = 15;
    conf.timeoutIntervalForResource = 36 * 60 * 60;
    return conf;
}

@end

@implementation OSSNetworkingRequestDelegate

- (instancetype)init {
    if (self = [super init]) {
        self.retryHandler = [OSSURLRequestRetryHandler defaultRetryHandler];
        self.interceptors = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)reset {
    self.isHttpRequestNotSuccessResponse = NO;
    self.error = nil;
    self.payloadTotalBytesWritten = 0;
    [self.responseParser reset];
}

- (void)cancel {
    if (self.holdDataTask) {
        OSSLogDebug(@"this task is cancelled now!");
        [self.holdDataTask cancel];
    }
}

- (BFTask *)validateRequestParams {
    NSString * errorMessage = nil;

    if ((self.operType == OSSOperationTypeAppendObject || self.operType == OSSOperationTypePutObject || self.operType == OSSOperationTypeUploadPart)
        && !self.uploadingData && !self.uploadingFileURL) {
        errorMessage = @"This operation need data or file to upload but none is set";
    }

    if (errorMessage) {
        return [BFTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                         code:OSSClientErrorCodeInvalidArgument
                                                     userInfo:@{OSSErrorMessageTOKEN: errorMessage}]];
    } else {
        return [self.allNeededMessage validateRequestParamsInOperationType:self.operType];
    }
}

- (BFTask *)buildInternalHttpRequest {

    BFTask * validateParam = [self validateRequestParams];
    if (validateParam.error) {
        return validateParam;
    }

#define URLENCODE(a) [OSSUtil encodeURL:(a)]
    OSSLogDebug(@"start to build request");
    // build base url string
    NSString * urlString = nil; // self.allNeededMessage.endpoint;

    NSURL * endPointURL = [NSURL URLWithString:self.allNeededMessage.endpoint];
    if ([OSSUtil isOssOriginBucketHost:endPointURL.host]) {
        if (self.allNeededMessage.bucketName) {
            urlString = [NSString stringWithFormat:@"%@://%@.%@", endPointURL.scheme, self.allNeededMessage.bucketName, endPointURL.host];
        }
    }

    NSURL * tempURL = [NSURL URLWithString:urlString];
    NSString * originHost = tempURL.host;
    if (!self.isAccessViaProxy) {
        NSString * httpdnsResolvedResult = [OSSUtil getIpByHost:originHost];
        urlString = [NSString stringWithFormat:@"%@://%@", tempURL.scheme, httpdnsResolvedResult];
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

    // set header fields
    self.internalRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];

    // override default host
    [self.internalRequest setValue:originHost forHTTPHeaderField:@"Host"];

    if (self.allNeededMessage.httpMethod) {
        [self.internalRequest setHTTPMethod:self.allNeededMessage.httpMethod];
    }
    if (self.allNeededMessage.contentType) {
        [self.internalRequest setValue:self.allNeededMessage.contentType forHTTPHeaderField:@"Content-Type"];
    } else if ([self.allNeededMessage.httpMethod isEqualToString:@"POST"] || [self.allNeededMessage.httpMethod isEqualToString:@"PUT"]) {
        // set empty content-type to override the automatic-setup content-type
        [self.internalRequest setValue:@"" forHTTPHeaderField:@"Content-Type"];
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
    return [BFTask taskWithResult:nil];
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

- (BFTask *)validateRequestParamsInOperationType:(OSSOperationType)operType {
    NSString * errorMessage = nil;

    if (!self.endpoint) {
        errorMessage = @"Endpoint should not be nil";
    }

    if (!self.bucketName) {
        errorMessage = @"Bucket name should not be nil";
    }

    if (!self.objectKey &&
        (operType != OSSOperationTypeGetBucket && operType != OSSOperationTypeCreateBucket && operType != OSSOperationTypeDeleteBucket)) {
        errorMessage = @"Object key should not be nil";
    }

    if (errorMessage) {
        return [BFTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                         code:OSSClientErrorCodeInvalidArgument
                                                     userInfo:@{OSSErrorMessageTOKEN: errorMessage}]];
    } else {
        return [BFTask taskWithResult:nil];
    }
}

@end

NSString * const BACKGROUND_SESSION_IDENTIFIER = @"com.aliyun.oss.backgroundsession";

@implementation OSSNetworking

- (instancetype)initWithConfiguration:(OSSNetworkingConfiguration *)configuration {
    if (self = [super init]) {
        self.configuration = configuration;

        NSOperationQueue * operationQueue = [NSOperationQueue new];
        operationQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;

        NSURLSessionConfiguration * sessionConfig = nil;
        if (configuration.enableBackgroundTransmitService) {
            if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
                sessionConfig = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:BACKGROUND_SESSION_IDENTIFIER];
            } else {
                sessionConfig = [NSURLSessionConfiguration backgroundSessionConfiguration:BACKGROUND_SESSION_IDENTIFIER];
            }
        } else {
            sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];

            if (configuration.timeoutIntervalForRequest > 0) {
                sessionConfig.timeoutIntervalForRequest = configuration.timeoutIntervalForRequest;
            }
            if (configuration.timeoutIntervalForResource > 0) {
                sessionConfig.timeoutIntervalForResource = configuration.timeoutIntervalForResource;
            }
        }
        sessionConfig.URLCache = nil;
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
            sessionConfig.connectionProxyDictionary = proxyDict;
        }

        _session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                 delegate:self
                                            delegateQueue:operationQueue];
        self.isUsingBackgroundSession = configuration.enableBackgroundTransmitService;
        _sessionDelagateManager = [OSSSyncMutableDictionary new];

        NSOperationQueue * queue = [NSOperationQueue new];
        self.taskExecutor = [BFExecutor executorWithOperationQueue:queue];
    }
    return self;
}

- (BFTask *)sendRequest:(OSSNetworkingRequestDelegate *)request {
    OSSLogVerbose(@"send request --------");
    if (self.configuration.proxyHost && self.configuration.proxyPort) {
        request.isAccessViaProxy = YES;
    }

    BFTaskCompletionSource * taskCompletionSource = [BFTaskCompletionSource taskCompletionSource];

    request.completionHandler = ^(id responseObject, NSError * error) {
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

    [[[[[BFTask taskWithResult:nil] continueWithExecutor:self.taskExecutor withSuccessBlock:^id(BFTask *task) {
        OSSLogVerbose(@"start to intercept request");
        for (id<OSSRequestInterceptor> interceptor in requestDelegate.interceptors) {
            task = [interceptor interceptRequestMessage:requestDelegate.allNeededMessage];
            if (task.error) {
                return task;
            }
        }
        return task;
    }] continueWithSuccessBlock:^id(BFTask *task) {
        return [requestDelegate buildInternalHttpRequest];
    }] continueWithSuccessBlock:^id(BFTask *task) {
        NSURLSessionDataTask * sessionTask = nil;

        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0 && self.configuration.timeoutIntervalForRequest > 0) {
            requestDelegate.internalRequest.timeoutInterval = self.configuration.timeoutIntervalForRequest;
        }

        if (requestDelegate.uploadingData) {
            if (self.isUsingBackgroundSession) {
                [requestDelegate.internalRequest setHTTPBody:requestDelegate.uploadingData];
                sessionTask = [_session dataTaskWithRequest:requestDelegate.internalRequest];
            } else {
                sessionTask = [_session uploadTaskWithRequest:requestDelegate.internalRequest fromData:requestDelegate.uploadingData];
            }
        } else if (requestDelegate.uploadingFileURL) {
            if (![requestDelegate.uploadingFileURL.absoluteString hasPrefix:@"file://"]) {
                /* in case of some user passing the incomplete filepath to fileURL */
                requestDelegate.uploadingFileURL = [NSURL fileURLWithPath:requestDelegate.uploadingFileURL.absoluteString];
            }

            sessionTask = [_session uploadTaskWithRequest:requestDelegate.internalRequest fromFile:requestDelegate.uploadingFileURL];
        } else {
            sessionTask = [_session dataTaskWithRequest:requestDelegate.internalRequest];
        }

        if (self.isUsingBackgroundSession && [sessionTask isKindOfClass:[NSURLSessionUploadTask class]]) {
            requestDelegate.isBackgroundUploadTask = YES;
        }

        requestDelegate.holdDataTask = sessionTask;
        requestDelegate.httpRequestNotSuccessResponseBody = [NSMutableData new];
        [self.sessionDelagateManager setObject:requestDelegate forKey:@(sessionTask.taskIdentifier)];
        [sessionTask resume];

        return task;
    }] continueWithBlock:^id(BFTask *task) {
        if (task.error) {
            requestDelegate.completionHandler(nil, task.error);
        }
        return nil;
    }];
}

#pragma mark - delegate method

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)sessionTask didCompleteWithError:(NSError *)error {
    OSSNetworkingRequestDelegate * delegate = [self.sessionDelagateManager objectForKey:@(sessionTask.taskIdentifier)];
    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)sessionTask.response;

    if (delegate == nil) {
        OSSLogVerbose(@"delegate: %@", delegate);
        /* if the background transfer service is enable, may recieve the previous task complete callback */
        /* for now, we ignore it */
        return ;
    }

    /* background upload task will not call back didRecieveResponse */
    if (delegate.isBackgroundUploadTask) {
        OSSLogVerbose(@"backgroud upload task did recieve response: %@", httpResponse);
        if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
            [delegate.responseParser consumeHttpResponse:httpResponse];
        } else {
            delegate.isHttpRequestNotSuccessResponse = YES;
        }
    }

    [[[[BFTask taskWithResult:nil] continueWithSuccessBlock:^id(BFTask * task) {
        if (!delegate.error) {
            delegate.error = error;
        }
        if (delegate.error) {
            OSSLogDebug(@"networking request completed with error: %@", error);
            if ([delegate.error.domain isEqualToString:NSURLErrorDomain] && delegate.error.code == NSURLErrorCancelled) {
                return [BFTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                                 code:OSSClientErrorCodeTaskCancelled
                                                             userInfo:[error userInfo]]];
            } else {
                NSMutableDictionary * userInfo = [NSMutableDictionary dictionaryWithDictionary:[error userInfo]];
                [userInfo setObject:[NSString stringWithFormat:@"%ld", (long)error.code] forKey:@"OriginErrorCode"];
                return [BFTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                                 code:OSSClientErrorCodeNetworkError
                                                             userInfo:userInfo]];
            }
        }
        return task;
    }] continueWithSuccessBlock:^id(BFTask *task) {
        if (delegate.isHttpRequestNotSuccessResponse) {
            if (httpResponse.statusCode == 0) {
                return [BFTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                                 code:OSSClientErrorCodeNetworkingFailWithResponseCode0
                                                             userInfo:@{OSSErrorMessageTOKEN: @"Request failed, response code 0"}]];
            }
            NSString * notSuccessResponseBody = [[NSString alloc] initWithData:delegate.httpRequestNotSuccessResponseBody encoding:NSUTF8StringEncoding];
            OSSLogError(@"http error response: %@", notSuccessResponseBody);
            NSDictionary * dict = [NSDictionary dictionaryWithXMLString:notSuccessResponseBody];

            return [BFTask taskWithError:[NSError errorWithDomain:OSSServerErrorDomain
                                                             code:(-1 * httpResponse.statusCode)
                                                         userInfo:dict]];
        }
        return task;
    }] continueWithBlock:^id(BFTask *task) {
        if (task.error) {
            OSSNetworkingRetryType retryType = [delegate.retryHandler shouldRetry:delegate.currentRetryCount
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
                    NSString * dateStr = [[httpResponse allHeaderFields] objectForKey:@"Date"];
                    if ([dateStr length]) {
                        NSDate * serverTime = [NSDate oss_dateFromString:dateStr];
                        NSDate * deviceTime = [NSDate date];
                        NSTimeInterval skewTime = [deviceTime timeIntervalSinceDate:serverTime];
                        [NSDate oss_setClockSkew:skewTime];
                        [delegate.interceptors insertObject:[OSSTimeSkewedFixingInterceptor new] atIndex:0];
                    } else {
                        OSSLogError(@"date header does not exist, unable to fix the time skew");
                        delegate.completionHandler(nil, task.error);
                        return nil;
                    }
                }

                default:
                    break;
            }

            /* now, should retry */
            NSTimeInterval suspendTime = [delegate.retryHandler timeIntervalForRetry:delegate.currentRetryCount retryType:retryType];
            [self.sessionDelagateManager removeObjectForKey:@(sessionTask.taskIdentifier)];
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
    if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        [delegate.responseParser consumeHttpResponse:httpResponse];
    } else {
        delegate.isHttpRequestNotSuccessResponse = YES;
    }
    completionHandler(NSURLSessionResponseAllow);
}

/* do not verify host domain */
- (BOOL)evaluateServerTrustAcceptAllDomain:(SecTrustRef)serverTrust {
    NSMutableArray *policies = [NSMutableArray array];
    [policies addObject:(__bridge_transfer id)SecPolicyCreateBasicX509()];

    SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);

    SecTrustResultType result;
    SecTrustEvaluate(serverTrust, &result);

    return (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed);
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if ([self evaluateServerTrustAcceptAllDomain:challenge.protectionSpace.serverTrust]) {
            NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
        } else {
            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        }
    } else {
        [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    OSSNetworkingRequestDelegate * delegate = [self.sessionDelagateManager objectForKey:@(dataTask.taskIdentifier)];

    OSSLogVerbose(@"recieve data: %ld", (long)[data length]);

    /* background upload task will not call back didRecieveResponse */
    if (delegate.isHttpRequestNotSuccessResponse || delegate.isBackgroundUploadTask) {
        [delegate.httpRequestNotSuccessResponseBody appendData:data];
    } else {
        if (delegate.onRecieveData) {
            delegate.onRecieveData(data);
        } else {
            BFTask * consumeTask = [delegate.responseParser consumeHttpResponseBody:data];
            if (consumeTask.error) {
                OSSLogError("consume data error: %@", consumeTask.error);
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
@end