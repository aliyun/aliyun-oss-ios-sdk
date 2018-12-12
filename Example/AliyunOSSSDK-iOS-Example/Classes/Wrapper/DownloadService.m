//
//  DownloadService.m
//  AliyunOSSSDK-iOS-Example
//
//  Created by huaixu on 2018/8/9.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "DownloadService.h"
#import "OSSTestMacros.h"

@implementation DownloadRequest

@end

@implementation Checkpoint

- (instancetype)copyWithZone:(NSZone *)zone {
    Checkpoint *other = [[[self class] allocWithZone:zone] init];
    
    other.etag = self.etag;
    other.totalExpectedLength = self.totalExpectedLength;
    
    return other;
}

@end


@interface DownloadService()<NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURLSession *session;         //网络会话
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;   //数据请求任务
@property (nonatomic, copy) DownloadFailureBlock failure;    //请求出错
@property (nonatomic, copy) DownloadSuccessBlock success;    //请求成功
@property (nonatomic, copy) DownloadProgressBlock progress;  //下载进度
@property (nonatomic, copy) Checkpoint *checkpoint;        //检查节点
@property (nonatomic, copy) NSString *requestURLString;    //文件资源地址,用于下载请求
@property (nonatomic, copy) NSString *headURLString;       //文件资源地址,用于head请求
@property (nonatomic, copy) NSString *targetPath;     //文件存储路径
@property (nonatomic, assign) unsigned long long totalReceivedContentLength; //已下载大小
@property (nonatomic, strong) dispatch_semaphore_t semaphore;

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
        _semaphore = dispatch_semaphore_create(0);
        _checkpoint = [[Checkpoint alloc] init];
    }
    return self;
}

+ (instancetype)downloadServiceWithRequest:(DownloadRequest *)request {
    DownloadService *service = [[DownloadService alloc] init];
    if (service) {
        service.failure = request.failure;
        service.success = request.success;
        service.requestURLString = request.sourceURLString;
        service.headURLString = request.headURLString;
        service.targetPath = request.downloadFilePath;
        service.progress = request.downloadProgress;
        if (request.checkpoint) {
            service.checkpoint = request.checkpoint;
        }
    }
    return service;
}

/**
 * head文件信息，取出来文件的etag和本地checkpoint中保存的etag进行对比,并且将结果返回
 */
- (BOOL)getFileInfo {
    __block BOOL resumable = NO;
    NSURL *url = [NSURL URLWithString:self.headURLString];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc]initWithURL:url];
    [request setHTTPMethod:@"HEAD"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"获取文件meta信息失败,error : %@", error);
        } else {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSString *etag = [httpResponse.allHeaderFields objectForKey:@"Etag"];
            if ([self.checkpoint.etag isEqualToString:etag]) {
                resumable = YES;
            } else {
                resumable = NO;
            }
        }
        dispatch_semaphore_signal(self.semaphore);
    }];
    [task resume];
    
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    return resumable;
}

/**
 * 用于获取本地文件的大小
 */
- (unsigned long long)fileSizeAtPath:(NSString *)filePath {
    unsigned long long fileSize = 0;
    NSFileManager *dfm = [NSFileManager defaultManager];
    if ([dfm fileExistsAtPath:filePath]) {
        NSError *error = nil;
        NSDictionary *attributes = [dfm attributesOfItemAtPath:filePath error:&error];
        if (!error && attributes) {
            fileSize = attributes.fileSize;
        } else if (error) {
            NSLog(@"error: %@", error);
        }
    }
    return fileSize;
}

- (void)resume {
    NSURL *url = [NSURL URLWithString:self.requestURLString];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc]initWithURL:url];
    [request setHTTPMethod:@"GET"];
    
    BOOL resumable = [self getFileInfo];    // 如果resumable为NO,则证明不能断点续传,否则走续传逻辑。
    if (resumable) {
        self.totalReceivedContentLength = [self fileSizeAtPath:self.targetPath];
        NSString *requestRange = [NSString stringWithFormat:@"bytes=%llu-", self.totalReceivedContentLength];
        [request setValue:requestRange forHTTPHeaderField:@"Range"];
    } else {
        self.totalReceivedContentLength = 0;
        [[NSFileManager defaultManager] createFileAtPath:self.targetPath contents:nil attributes:nil];
    }
    
    self.dataTask = [self.session dataTaskWithRequest:request];
    [self.dataTask resume];
}

- (void)pause {
    [self.dataTask cancel];
    self.dataTask = nil;
}

- (void)cancel {
    [self.dataTask cancel];
    self.dataTask = nil;
    [self removeFileAtPath: self.targetPath];
}

- (void)removeFileAtPath:(NSString *)filePath {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:self.targetPath error:&error];
    if (error) {
        NSLog(@"remove file with error : %@", error);
    }
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
    if ([httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
        if (httpResponse.statusCode == 200) {
            self.checkpoint.etag = [[httpResponse allHeaderFields] objectForKey:@"Etag"];
            self.checkpoint.totalExpectedLength = httpResponse.expectedContentLength;
        } else if (httpResponse.statusCode == 206) {
            self.checkpoint.etag = [[httpResponse allHeaderFields] objectForKey:@"Etag"];
            self.checkpoint.totalExpectedLength = self.totalReceivedContentLength + httpResponse.expectedContentLength;
        }
    }
    
    if (error) {
        if (self.failure) {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:error.userInfo];
            [userInfo oss_setObject:self.checkpoint forKey:@"checkpoint"];
            
            NSError *tError = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
            self.failure(tError);
        }
    } else if (self.success) {
        self.success(@{@"status": @"success"});
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)dataTask.response;
    if ([httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
        if (httpResponse.statusCode == 200) {
            self.checkpoint.totalExpectedLength = httpResponse.expectedContentLength;
        } else if (httpResponse.statusCode == 206) {
            self.checkpoint.totalExpectedLength = self.totalReceivedContentLength +  httpResponse.expectedContentLength;
        }
    }
    
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.targetPath];
    [fileHandle seekToEndOfFile];
    [fileHandle writeData:data];
    [fileHandle closeFile];
    
    self.totalReceivedContentLength += data.length;
    if (self.progress) {
        self.progress(data.length, self.totalReceivedContentLength, self.checkpoint.totalExpectedLength);
    }
}

@end
