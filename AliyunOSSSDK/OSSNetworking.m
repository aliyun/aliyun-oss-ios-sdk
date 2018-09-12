//
//  OSSNetworking.m
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import "OSSDefine.h"
#import "OSSNetworking.h"
#import "OSSBolts.h"
#import "OSSModel.h"
#import "OSSUtil.h"
#import "OSSLog.h"
#import "OSSXMLDictionary.h"
#import "OSSInputStreamHelper.h"
#import "OSSNetworkingRequestDelegate.h"
#import "OSSURLRequestRetryHandler.h"
#import "OSSHttpResponseParser.h"

@implementation OSSNetworkingConfiguration
@end


@implementation OSSNetworking

- (instancetype)initWithConfiguration:(OSSNetworkingConfiguration *)configuration {
    if (self = [super init]) {
        self.configuration = configuration;
        NSURLSessionConfiguration * conf = nil;
        NSOperationQueue *delegateQueue = [NSOperationQueue new];

        if (configuration.enableBackgroundTransmitService) {
            conf = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:self.configuration.backgroundSessionIdentifier];
        } else {
            conf = [NSURLSessionConfiguration defaultSessionConfiguration];
        }
        conf.URLCache = nil;

        if (configuration.timeoutIntervalForRequest > 0) {
            conf.timeoutIntervalForRequest = configuration.timeoutIntervalForRequest;
        }
        if (configuration.timeoutIntervalForResource > 0) {
            conf.timeoutIntervalForResource = configuration.timeoutIntervalForResource;
        }
        
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
            conf.connectionProxyDictionary = proxyDict;
        }

        _session = [NSURLSession sessionWithConfiguration:conf
                                                 delegate:self
                                            delegateQueue:delegateQueue];

        self.isUsingBackgroundSession = configuration.enableBackgroundTransmitService;
        _sessionDelagateManager = [OSSSyncMutableDictionary new];

        NSOperationQueue * operationQueue = [NSOperationQueue new];
        if (configuration.maxConcurrentRequestCount > 0) {
            operationQueue.maxConcurrentOperationCount = configuration.maxConcurrentRequestCount;
        }
        self.taskExecutor = [OSSExecutor executorWithOperationQueue: operationQueue];
    }
    return self;
}

- (OSSTask *)sendRequest:(OSSNetworkingRequestDelegate *)request {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        OSSLogVerbose(@"NetWorkConnectedMsg : %@",[OSSUtil buildNetWorkConnectedMsg]);
        NSString *operator = [OSSUtil buildOperatorMsg];
        if(operator) OSSLogVerbose(@"Operator : %@",[OSSUtil buildOperatorMsg]);
    });
    OSSLogVerbose(@"send request --------");
    if (self.configuration.proxyHost && self.configuration.proxyPort) {
        request.isAccessViaProxy = YES;
    }

    /* set maximum retry */
    request.retryHandler.maxRetryCount = self.configuration.maxRetryCount;

    OSSTaskCompletionSource * taskCompletionSource = [OSSTaskCompletionSource taskCompletionSource];

    __weak OSSNetworkingRequestDelegate *weakRequest= request;
    request.completionHandler = ^(id responseObject, NSError * error) {
        [weakRequest reset];
        
        // 1.判断是否出错，如果出错的话，直接设置错误信息
        if (error)
        {
            [taskCompletionSource setError:error];
        }else
        {
            [self checkForCrc64WithResult:responseObject
                          requestDelegate:weakRequest
                     taskCompletionSource:taskCompletionSource];
        }
    };
    [self dataTaskWithDelegate:request];
    return taskCompletionSource.task;
}

- (void)checkForCrc64WithResult:(nonnull id)response requestDelegate:(OSSNetworkingRequestDelegate *)delegate taskCompletionSource:(OSSTaskCompletionSource *)source
{
    OSSResult *result = (OSSResult *)response;
    BOOL hasRange = [delegate.internalRequest valueForHTTPHeaderField:@"Range"] != nil;
    NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:delegate.internalRequest.URL resolvingAgainstBaseURL:YES];
    BOOL hasXOSSProcess = [urlComponents.query containsString:@"x-oss-process"];
    BOOL enableCRC = delegate.crc64Verifiable;
    // 3.判断如果未开启crc校验,或者headerFields里面有Range字段或者参数表中存在
    //   x-oss-process字段,都将不进行crc校验
    if (!enableCRC || hasRange || hasXOSSProcess)
    {
        [source setResult:response];
    }
    else
    {
        OSSLogVerbose(@"--- checkForCrc64WithResult --- ");
        // 如果服务端未返回crc信息，默认是成功的
        OSSLogVerbose(@"result.remoteCRC64ecma : %@",result.remoteCRC64ecma);
        OSSLogVerbose(@"if result.localCRC64ecma : %@",result.localCRC64ecma);
        if (!result.remoteCRC64ecma.oss_isNotEmpty)
        {
            [source setResult:response];
            return;
        }
        // getObject 操作的crc数值会在delegate.responseParser consumeHttpResponseBody 进行计算。
        // upload & put 操作在上传成功后再计算。
        // 如果用户设置onReceiveData block。无法计算localCRC64ecma
        if (!result.localCRC64ecma.oss_isNotEmpty)
        {
            OSSLogVerbose(@"delegate.uploadingFileURL : %@",delegate.uploadingFileURL);
            if (delegate.uploadingFileURL)
            {
                OSSInputStreamHelper *helper = [[OSSInputStreamHelper alloc] initWithURL:delegate.uploadingFileURL];
                [helper syncReadBuffers];
                if (helper.crc64 != 0) {
                    result.localCRC64ecma = [NSString stringWithFormat:@"%llu",helper.crc64];
                }
            }
            else
            {
                result.localCRC64ecma = delegate.contentCRC;
            }
            OSSLogVerbose(@"finally result.localCRC64ecma : %@",result.localCRC64ecma);
        }

        
        // 针对append接口，需要多次计算crc值
        if ([delegate.lastCRC oss_isNotEmpty] && [result.localCRC64ecma oss_isNotEmpty])
        {
            uint64_t last_crc64,local_crc64;
            NSScanner *scanner = [NSScanner scannerWithString:delegate.lastCRC];
            [scanner scanUnsignedLongLong:&last_crc64];
            
            scanner = [NSScanner scannerWithString:result.localCRC64ecma];
            [scanner scanUnsignedLongLong:&local_crc64];
            
            NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:delegate.internalRequest.URL resolvingAgainstBaseURL:YES];
            NSArray<NSString *> *params = [urlComponents.query componentsSeparatedByString:@"&"];
            
            __block NSString *positionValue;
            [params enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj rangeOfString:@"position="].location == 0)
                {
                    *stop = YES;
                    positionValue = [obj substringFromIndex:9];
                }
            }];
            
            uint64_t position = [positionValue longLongValue];
            NSString *next_append_position = [result.httpResponseHeaderFields objectForKey:@"x-oss-next-append-position"];
            uint64_t length = [next_append_position longLongValue] - position;
            
            uint64_t crc_local = [OSSUtil crc64ForCombineCRC1:last_crc64 CRC2:local_crc64 length:(size_t)length];
            result.localCRC64ecma = [NSString stringWithFormat:@"%llu",crc_local];
            OSSLogVerbose(@"crc_local: %llu, crc_remote: %@,last_position: %llu,nextAppendPosition: %llu,length:  %llu",crc_local,result.remoteCRC64ecma,position,[next_append_position longLongValue],length);
        }
        //如果服务器和本机计算的crc值不一致,则报crc校验失败;否则,认为上传任务执行成功
        if (result.remoteCRC64ecma.oss_isNotEmpty && result.localCRC64ecma.oss_isNotEmpty)
        {
            if ([result.remoteCRC64ecma isEqualToString:result.localCRC64ecma])
            {
                [source setResult:response];
            }else
            {
                NSString *errorMessage = [NSString stringWithFormat:@"crc validation fails(local_crc64ecma: %@,remote_crc64ecma: %@)",result.localCRC64ecma,result.remoteCRC64ecma];
                
                NSError *crcError = [NSError errorWithDomain:OSSClientErrorDomain
                                                        code:OSSClientErrorCodeInvalidCRC
                                                    userInfo:@{OSSErrorMessageTOKEN:errorMessage}];
                [source setError:crcError];
            }
        }
        else
        {
            [source setResult:response];
        }
    }
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
        if (self.configuration.timeoutIntervalForRequest > 0) {
            requestDelegate.internalRequest.timeoutInterval = self.configuration.timeoutIntervalForRequest;
        }

        if (requestDelegate.uploadingData) {
            [requestDelegate.internalRequest setHTTPBody:requestDelegate.uploadingData];
            sessionTask = [_session dataTaskWithRequest:requestDelegate.internalRequest];
        } else if (requestDelegate.uploadingFileURL) {
            sessionTask = [_session uploadTaskWithRequest:requestDelegate.internalRequest fromFile:requestDelegate.uploadingFileURL];

                requestDelegate.isBackgroundUploadFileTask = self.isUsingBackgroundSession;
        } else { // not upload request
            sessionTask = [_session dataTaskWithRequest:requestDelegate.internalRequest];
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

#pragma mark - NSURLSessionTaskDelegate Methods

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)sessionTask didCompleteWithError:(NSError *)error
{
    if (error) {
        OSSLogError(@"%@,error: %@", NSStringFromSelector(_cmd), error);
    }
    
    OSSNetworkingRequestDelegate * delegate = [self.sessionDelagateManager objectForKey:@(sessionTask.taskIdentifier)];
    [self.sessionDelagateManager removeObjectForKey:@(sessionTask.taskIdentifier)];

    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)sessionTask.response;
    if (delegate == nil) {
        OSSLogVerbose(@"delegate: %@", delegate);
        /* if the background transfer service is enable, may recieve the previous task complete callback */
        /* for now, we ignore it */
        return ;
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
            NSDictionary * dict = [NSDictionary oss_dictionaryWithXMLString:notSuccessResponseBody];

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
                    NSString * dateStr = [[httpResponse allHeaderFields] objectForKey:@"Date"];
                    if ([dateStr length] > 0) {
                        NSDate * serverTime = [NSDate oss_dateFromString:dateStr];
                        NSDate * deviceTime = [NSDate date];
                        NSTimeInterval skewTime = [deviceTime timeIntervalSinceDate:serverTime];
                        [NSDate oss_setClockSkew:skewTime];
                    } else if (!error) {
                        // The response header does not have the 'Date' field.
                        // This should not happen.
                        OSSLogError(@"Date header does not exist, unable to fix the clock skew");
                    }
                    
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
            
            if(delegate.retryCallback){
                delegate.retryCallback();
            }
            

            /* retry recursively */
            [delegate reset];
            
            [self dataTaskWithDelegate:delegate];
        } else {
            delegate.completionHandler([delegate.responseParser constructResultObject], nil);
        }
        return nil;
    }];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    OSSNetworkingRequestDelegate * delegate = [self.sessionDelagateManager objectForKey:@(task.taskIdentifier)];
    if (delegate.uploadProgress)
    {
        delegate.uploadProgress(bytesSent, totalBytesSent, totalBytesExpectedToSend);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * __nullable credential))completionHandler
{
    if (!challenge) {
        return;
    }
    
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    NSURLCredential *credential = nil;
    
    /*
     * Gets the host name
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
    // Uses the default evaluation for other challenges.
    completionHandler(disposition,credential);
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    
}

#pragma mark - NSURLSessionDataDelegate Methods

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    /* background upload task will not call back didRecieveResponse */
    OSSLogVerbose(@"%@,response: %@", NSStringFromSelector(_cmd), response);
    
    OSSNetworkingRequestDelegate * delegate = [self.sessionDelagateManager objectForKey:@(dataTask.taskIdentifier)];
    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 && httpResponse.statusCode != 203) {
        [delegate.responseParser consumeHttpResponse:httpResponse];
    } else {
        delegate.isHttpRequestNotSuccessResponse = YES;
    }
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    OSSNetworkingRequestDelegate * delegate = [self.sessionDelagateManager objectForKey:@(dataTask.taskIdentifier)];

    /* background upload task will not call back didRecieveResponse.
       so if we recieve response data after background uploading file,
       we consider it as error response message since a successful uploading request will not response any data */
    if (delegate.isBackgroundUploadFileTask)
    {
        //判断当前的statuscode是否成功
        NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)dataTask.response;
        if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 && httpResponse.statusCode != 203) {
            [delegate.responseParser consumeHttpResponse:httpResponse];
            delegate.isHttpRequestNotSuccessResponse = NO;
        }else
        {
            delegate.isHttpRequestNotSuccessResponse = YES;
        }
    }
    
    if (delegate.isHttpRequestNotSuccessResponse) {
        [delegate.httpRequestNotSuccessResponseBody appendData:data];
    }
    else {
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

#pragma mark - Private Methods

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forDomain:(NSString *)domain {
    /*
     * Creates the policies for certificate verification.
     */
    NSMutableArray *policies = [NSMutableArray array];
    if (domain) {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateSSL(true, (__bridge CFStringRef)domain)];
    } else {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateBasicX509()];
    }
    
    /*
     * Sets the policies to server's certificate
     */
    SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);
    
    
    /*
     * Evaulates if the current serverTrust is trustable.
     * It's officially suggested that the serverTrust could be passed when result = kSecTrustResultUnspecified or kSecTrustResultProceed.
     * For more information checks out https://developer.apple.com/library/ios/technotes/tn2232/_index.html
     * For detail information about SecTrustResultType, checks out SecTrust.h
     */
    SecTrustResultType result;
    SecTrustEvaluate(serverTrust, &result);
    
    return (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed);
}

@end
