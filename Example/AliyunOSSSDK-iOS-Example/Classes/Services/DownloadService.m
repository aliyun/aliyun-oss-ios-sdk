//
//  DownloadService.m
//  AliyunOSSSDK-iOS-Example
//
//  Created by huaixu on 2018/8/9.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "DownloadService.h"
#import "OSSTestMacros.h"

typedef void(^DownloadManagerCompleteBlock)(id result, NSError *error);

@interface RequestDelegate : NSObject

@property (nonatomic, strong) NSURLSessionTask *internalTask;
@property (nonatomic, copy) OnReceiveData onReceiveData;
@property (nonatomic, copy) NSString *downloadFilePath;
@property (nonatomic, strong) OSSTaskCompletionSource *taskCompletionSource;
@property (nonatomic, assign) BOOL isDownloadTask;
@property (nonatomic, copy) NSString *tmpFilePath;
@property (nonatomic, assign) unsigned long long totalByteReceived;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, copy) NSString *etag;
@property (nonatomic, copy) NSString *crc64String;
@property (nonatomic, copy) NSString *contentMD5;
@property (nonatomic, copy) DownloadManagerCompleteBlock completeHandler;
@property (nonatomic, assign) BOOL statusCodeCheckSuccess;
@property (nonatomic, strong) NSHTTPURLResponse *response;

@end

@implementation RequestDelegate

- (void)dealloc {
    OSSLogDebug(@"RequestDelegate dealloc!");
}

@end

@interface DownloadRequest()

@property (nonatomic, strong) RequestDelegate *delegate;

@end

@implementation DownloadRequest

- (void)cancel {
    [_delegate.internalTask cancel];
}

- (void)dealloc {
    OSSLogDebug(@"DownloadRequest dealloc!");
}

@end


@interface DownloadService()<NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (nonatomic, strong) OSSSyncMutableDictionary *requestDelegates;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) OSSClient *client;
@property (nonatomic, strong) OSSExecutor *executor;
@property (nonatomic, strong) OSSExecutor *callbackExecutor;
@property (nonatomic, strong) OSSSyncMutableDictionary *kvStorage;

@end

@implementation DownloadService

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
        conf.timeoutIntervalForRequest = 15;
        
        NSOperationQueue *processQueue = [NSOperationQueue new];
        
        _session = [NSURLSession sessionWithConfiguration:conf delegate:self delegateQueue:processQueue];
        
        OSSAuthCredentialProvider *provider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
        _client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:provider];
        
        NSOperationQueue *executorQueue = [NSOperationQueue new];
        _executor = [OSSExecutor executorWithOperationQueue:executorQueue];
        
        NSOperationQueue *callbackExecutorQueue = [NSOperationQueue new];
        _callbackExecutor = [OSSExecutor executorWithOperationQueue:callbackExecutorQueue];
        
        _requestDelegates = [[OSSSyncMutableDictionary alloc] init];
        _kvStorage = [[OSSSyncMutableDictionary alloc] init];
    }
    return self;
}

- (OSSTask *)downloadObject:(DownloadRequest *)request {
    OSSTask *signTask = [self.client presignConstrainURLWithBucketName:request.bucketName withObjectKey:request.objectName withExpirationInterval:1800];
    if (signTask.error) {
        return signTask;
    }
    
    return [[OSSTask taskWithResult:nil] continueWithExecutor:self.executor withBlock:^id _Nullable(OSSTask * _Nonnull task) {
        RequestDelegate *requestDelegate = [[RequestDelegate alloc] init];
        requestDelegate.onReceiveData = request.onReceiveData;
        requestDelegate.downloadFilePath = request.downloadFilePath;
        requestDelegate.taskCompletionSource = [OSSTaskCompletionSource taskCompletionSource];
        requestDelegate.isDownloadTask = YES;
        
        NSString *tmpFilePath = [self.kvStorage objectForKey:request.downloadFilePath];
        if (!tmpFilePath) {
            NSString *tmpFileName = [NSString stringWithFormat:@"%@.tmp",[[NSUUID UUID] UUIDString]];
            tmpFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:tmpFileName];
            [self.kvStorage setObject:tmpFilePath forKey:requestDelegate.downloadFilePath];
        }
        requestDelegate.tmpFilePath = tmpFilePath;
        
        NSString *documentDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        if (![[NSFileManager defaultManager] fileExistsAtPath:tmpFilePath]) {
            BOOL isCreated = [[NSFileManager defaultManager] createFileAtPath:tmpFilePath contents:nil attributes:nil];
            if (!isCreated) {
                NSError *error = [NSError errorWithDomain:@"SystemErrorDomain" code:0 userInfo:@{NSLocalizedDescriptionKey: @"can not create tmp file!"}];
                return [OSSTask taskWithError:error];
            }
        }
        
        requestDelegate.tmpFilePath = tmpFilePath;
        requestDelegate.fileHandle = [NSFileHandle fileHandleForWritingAtPath:tmpFilePath];
        
        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:tmpFilePath error:nil];
        requestDelegate.totalByteReceived = fileAttributes.fileSize;
        
        NSMutableURLRequest *internalRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:signTask.result]];
        [internalRequest setHTTPMethod:@"GET"];
        [request.headers enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [internalRequest setValue:obj forHTTPHeaderField:key];
        }];
        
        if (requestDelegate.totalByteReceived > 0) {
            [internalRequest setValue:[NSString stringWithFormat:@"bytes=%lld-", requestDelegate.totalByteReceived] forHTTPHeaderField:@"Range"];
        }
        
        requestDelegate.internalTask = [self.session dataTaskWithRequest:internalRequest];
        
        __weak typeof(RequestDelegate *)wDelegate = requestDelegate;
        requestDelegate.completeHandler = ^(id result, NSError *error) {
            __strong typeof(RequestDelegate *)sDelegate = wDelegate;
            [sDelegate.fileHandle closeFile];
            if (error) {
                [sDelegate.taskCompletionSource setError:error];
            } else {
                [sDelegate.taskCompletionSource setResult:result];
            }
        };
        
        request.delegate = requestDelegate;
        
        [self.requestDelegates setObject:requestDelegate forKey:@(requestDelegate.internalTask.taskIdentifier)];
        [requestDelegate.internalTask resume];
        
        return requestDelegate.taskCompletionSource.task;
    }];
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    RequestDelegate *requestDelegate = [self.requestDelegates objectForKey:@(task.taskIdentifier)];
    [self.requestDelegates removeObjectForKey:@(task.taskIdentifier)];
    if (error) {
        if (requestDelegate.isDownloadTask) {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:error.userInfo];
            [userInfo oss_setObject:requestDelegate.etag forKey:@"etag"];
            
            NSError *downloadError = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
            requestDelegate.completeHandler(nil, downloadError);
        }
    } else {
        if (requestDelegate.isDownloadTask && requestDelegate.statusCodeCheckSuccess) {
            //TODO 1.校验md5,crc64等
            //2.将临时文件拷贝到目标位置
            NSError *moveError = nil;
            [[NSFileManager defaultManager] moveItemAtPath:requestDelegate.tmpFilePath toPath:requestDelegate.downloadFilePath error:&moveError];
            if (moveError) {
                requestDelegate.completeHandler(nil, moveError);
            } else {
                NSMutableDictionary *result = [NSMutableDictionary dictionary];
                [result oss_setObject:requestDelegate.downloadFilePath forKey:@"destFilePath"];
                [result oss_setObject:requestDelegate.etag forKey:@"Etag"];
                [result oss_setObject:requestDelegate.contentMD5 forKey:@"Content-MD5"];
                [result oss_setObject:requestDelegate.crc64String forKey:@""];
                
                requestDelegate.completeHandler(result, nil);
            }
        }else {
            NSError *error = [NSError errorWithDomain:@"DownloadServiceErrorDomain" code:requestDelegate.response.statusCode userInfo:@{NSLocalizedDescriptionKey: @"请求完成,但是有未处理的数据信息"}];
            requestDelegate.completeHandler(nil, error);
        }
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    RequestDelegate *requestDelegate = [self.requestDelegates objectForKey:@(dataTask.taskIdentifier)];
    requestDelegate.response = (NSHTTPURLResponse *)response;
    if (requestDelegate.isDownloadTask) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode == 200) {
            requestDelegate.etag = [[httpResponse allHeaderFields] objectForKey:@"Etag"];
            requestDelegate.contentMD5 = [[httpResponse allHeaderFields] objectForKey:@"Content-MD5"];
            requestDelegate.crc64String = [[httpResponse allHeaderFields] objectForKey:@"x-oss-hash-crc64ecma"];
            requestDelegate.statusCodeCheckSuccess = YES;
            OSSLogVerbose(@"正常下载文件内容%@",response);
        } else if (httpResponse.statusCode == 412) {
            OSSLogVerbose(@"服务器上面的文件已经发生了变化%@",response);
        } else {
            OSSLogVerbose(@"未处理的网络返回%@",response);
        }
    }
    
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    RequestDelegate *requestDelegate = [self.requestDelegates objectForKey:@(dataTask.taskIdentifier)];
    if (requestDelegate.isDownloadTask) {
        [requestDelegate.fileHandle writeData:data];
        requestDelegate.totalByteReceived += data.length;
    }
}

@end
