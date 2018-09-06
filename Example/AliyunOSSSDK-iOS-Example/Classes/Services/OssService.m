//
//  OssService.m
//  OssIOSDemo
//
//  Created by jingdan on 17/11/23.
//  Copyright © 2015年 Ali. All rights reserved.
//

#import <AliyunOSSiOS/OSSService.h>
#import "OssService.h"
#import "OSSTestMacros.h"

@interface OssService()

/** 待下载文件的etag值 */
@property (nonatomic, copy) NSString *etag;

/** OSS客户端 */
@property (nonatomic, strong) OSSClient *client;

/** OSS图片服务客户端 */
@property (nonatomic, strong) OSSClient *imgClient;

@property (nonatomic, strong) OSSPutObjectRequest *putRequest;

@property (nonatomic, strong) OSSGetObjectRequest *getRequest;

@end

@implementation OssService

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setupClient];
    }
    return self;
}

/**
 *    @brief    初始化获取OSSClient
 */
- (void)setupClient {
    /*
     移动终端是一个不受信任的环境，使用主账号AK，SK直接保存在终端用来加签请求，存在极高的风险。建议只在测试时使用明文设置模式，业务应用推荐使用STS鉴权模式。
     STS鉴权模式可通过https://help.aliyun.com/document_detail/31920.html文档了解更多
     主账号方式
     id<OSSCredentialProvider> credential = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithAccessKeyId:@"Aliyun_AK" secretKeyId:@"Aliyun_SK"];
     如果用STS鉴权模式，推荐使用OSSAuthCredentialProvider方式直接访问鉴权应用服务器，token过期后可以自动更新。
     详见：https://help.aliyun.com/document_detail/31920.html
     OSSClient的生命周期和应用程序的生命周期保持一致即可。在应用程序启动时创建一个OSSClient的实例，在应用程序结束时销毁即可。
     */
     
    id<OSSCredentialProvider> credential = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    _client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:credential];
    _imgClient = [[OSSClient alloc] initWithEndpoint:OSS_IMG_ENDPOINT credentialProvider:credential];
}

/**
 *    @brief    上传图片
 *
 *    @param     objectKey     objectKey
 *    @param     filePath     路径
 */
- (void)asyncPutImage:(NSString *)objectKey
        localFilePath:(NSString *)filePath
              success:(void (^_Nullable)(id))success
              failure:(void (^_Nullable)(NSError*))failure
{
    if (![objectKey oss_isNotEmpty]) {
        NSError *error = [NSError errorWithDomain:NSInvalidArgumentException code:0 userInfo:@{NSLocalizedDescriptionKey: @"objectKey should not be nil"}];
        failure(error);
        return;
    }
    
    _putRequest = [OSSPutObjectRequest new];
    _putRequest.bucketName = OSS_BUCKET_PRIVATE;
    _putRequest.objectKey = objectKey;
    _putRequest.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    _putRequest.isAuthenticationRequired = YES;
    _putRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        CGFloat progress = 1.f * totalByteSent / totalBytesExpectedToSend;
        OSSLogDebug(@"上传文件进度: %f", progress);
    };
    _putRequest.callbackParam = @{
                                  @"callbackUrl": OSS_CALLBACK_URL,
                                  // callbackBody可自定义传入的信息
                                  @"callbackBody": @"filename=${object}"
                                  };
    
    OSSTask * task = [_client putObject:_putRequest];
    [task continueWithBlock:^id(OSSTask *task) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (task.error) {
                failure(task.error);
            } else {
                success(nil);
            }
        });
        
        return nil;
    }];
}

/**
 *    @brief    下载图片
 */
- (void)asyncGetImage:(NSString *)objectKey success:(void (^_Nullable)(id))success failure:(void (^_Nullable)(NSError*))failure {
    if (![objectKey oss_isNotEmpty]) {
        NSError *error = [NSError errorWithDomain:NSInvalidArgumentException code:0 userInfo:@{NSLocalizedDescriptionKey: @"objectKey should not be nil"}];
        failure(error);
        return;
    }
    
    NSString *downloadFilePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:objectKey];
    
    _getRequest = [OSSGetObjectRequest new];
    _getRequest.bucketName = OSS_BUCKET_PRIVATE;
    _getRequest.objectKey = objectKey;
    _getRequest.downloadToFileURL = [NSURL URLWithString:downloadFilePath];
    _getRequest.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        CGFloat progress = 1.f * totalBytesWritten / totalBytesExpectedToWrite;
        OSSLogDebug(@"下载文件进度: %f", progress);
    };
    
    OSSTask * task = [_imgClient getObject:_getRequest];
    [task continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (task.error) {
                failure(task.error);
            } else {
                success(downloadFilePath);
            }
        });
        return nil;
    }];
}


/**
 *    @brief    普通上传/下载取消
 */
- (void)normalRequestCancel {
    if (_putRequest) {
        [_putRequest cancel];
    }
    if (_getRequest) {
        [_getRequest cancel];
    }
}

- (void)triggerCallbackWithObjectKey:(NSString *)objectKey success:(void (^_Nullable)(id))success failure:(void (^_Nullable)(NSError*))failure
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSSCallBackRequest *request = [OSSCallBackRequest new];
        request.bucketName = OSS_BUCKET_PRIVATE;
        request.objectName = objectKey;
        request.callbackParam = @{@"callbackUrl": OSS_CALLBACK_URL,
                                  @"callbackBody": @"test"};
        request.callbackVar = @{@"var1": @"value1",
                                @"var2": @"value2"};
        
        OSSTask *triggerCBTask = [_client triggerCallBack:request];
        [triggerCBTask waitUntilFinished];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (triggerCBTask.result) {
                success(triggerCBTask.result);
            } else {
                failure(triggerCBTask.error);
            }
        });
    });
}

- (void)multipartUploadWithSuccess:(void (^_Nullable)(id))success failure:(void (^_Nullable)(NSError*))failure {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 获取沙盒的cache路径
        NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        
        // 获取本地大文件url
        NSURL *fileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
        
        OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
        resumableUpload.bucketName = OSS_BUCKET_PRIVATE;            // 设置bucket名称
        resumableUpload.objectKey = @"oss-ios-demo-big-file";       // 设置object key
        resumableUpload.uploadingFileURL = fileURL;                 // 设置要上传的文件url
        resumableUpload.contentType = @"application/octet-stream";  // 设置content-type
        resumableUpload.partSize = 102400;                          // 设置分片大小
        resumableUpload.recordDirectoryPath = cachesDir;            // 设置分片信息的本地存储路径
        
        // 设置metadata
        resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
        
        // 设置上传进度回调
        resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
            NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        };
        
        //
        OSSTask * resumeTask = [_client resumableUpload:resumableUpload];
        [resumeTask waitUntilFinished];                             // 阻塞当前线程知道上传任务完成
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (resumeTask.result) {
                success(resumeTask.result);
            } else {
                failure(resumeTask.error);
            }
        });
    });
}

@end

