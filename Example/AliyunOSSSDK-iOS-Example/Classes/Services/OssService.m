//
//  OssService.m
//  OssIOSDemo
//
//  Created by jingdan on 17/11/23.
//  Copyright © 2015年 Ali. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AliyunOSSiOS/OSSService.h>
#import "OssService.h"
#import "DataCallback.h"

@implementation OssService
{
    OSSClient * _client;
    NSString * _endPoint;
    NSString * _callbackAddress;
    OSSPutObjectRequest * _putRequest;
    OSSGetObjectRequest * _getRequest;
    OSSResumableUploadRequest * _resumableRequest;
    BOOL _isCancelled;
    BOOL _isResumeUpload;
}

- (id)initWithEndPoint:(NSString *)enpoint {
    if (self = [super init]) {
        _endPoint = enpoint;
        _isResumeUpload = NO;
        _isCancelled = NO;
        [self ossInit];
    }
    return self;
}

/**
 *    @brief    初始化获取OSSClient
 */
- (void)ossInit {
//     移动终端是一个不受信任的环境，使用主账号AK，SK直接保存在终端用来加签请求，存在极高的风险。建议只在测试时使用明文设置模式，业务应用推荐使用STS鉴权模式。
//     STS鉴权模式可通过https://help.aliyun.com/document_detail/31920.html文档了解更多
//     主账号方式
//    id<OSSCredentialProvider> credential = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithAccessKeyId:@"Aliyun_AK" secretKeyId:@"Aliyun_SK"];
//     STS鉴权模式
//     2.直接访问鉴权服务器（推荐，token过期后可以自动更新）
    id<OSSCredentialProvider> credential = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:STS_AUTH_URL];
    _client = [[OSSClient alloc] initWithEndpoint:_endPoint credentialProvider:credential];
}


/**
 *    @brief    设置server callback地址
 */
- (void)setCallbackAddress:(NSString *)address {
    _callbackAddress = address;
}


/**
 *    @brief    上传图片
 *
 *    @param     objectKey     objectKey
 *    @param     filePath     路径
 */
- (void)asyncPutImage:(NSString *)objectKey
        localFilePath:(NSString *)filePath {
    
    if (objectKey == nil || [objectKey length] == 0) {
        return;
    }
    
    _putRequest = [OSSPutObjectRequest new];
    _putRequest.bucketName = BUCKET_NAME;
    _putRequest.objectKey = objectKey;
    _putRequest.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    _putRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    if (_callbackAddress != nil) {
        _putRequest.callbackParam = @{
                                     @"callbackUrl": _callbackAddress,
                                     // callbackBody可自定义传入的信息
                                     @"callbackBody": @"filename=${object}"
                                     };
    }
    OSSTask * task = [_client putObject:_putRequest];
    [task continueWithBlock:^id(OSSTask *task) {
        OSSPutObjectResult * result = task.result;
        // 查看server callback是否成功
        if (!task.error) {
            NSLog(@"Put image success!");
            NSLog(@"server callback : %@", result.serverReturnJsonString);
            dispatch_async(dispatch_get_main_queue(), ^{
                DataCallback * data = [DataCallback new];
                [data setCode:1];
                [data setObjectKey:objectKey];
                [data setShowMessage:@"上传"];
                [data setInputMessage:@"Success!"];
                [self setCallback:data];
            });
        } else {
            NSLog(@"Put image failed, %@", task.error);
            if (task.error.code == OSSClientErrorCodeTaskCancelled) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    DataCallback * data = [DataCallback new];
                    [data setCode:0];
                    [data setObjectKey:objectKey];
                    [data setShowMessage:@"上传"];
                    [data setInputMessage:@"任务取消!"];
                    [self setCallback:data];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    DataCallback * data = [DataCallback new];
                    [data setCode:-1];
                    [data setObjectKey:objectKey];
                    [data setShowMessage:@"上传"];
                    [data setInputMessage:@"Failed!"];
                    [self setCallback:data];
                });
            }
        }
        _putRequest = nil;
        return nil;
    }];
}

/**
 *    @brief    下载图片
 */
- (void)asyncGetImage:(NSString *)objectKey {
    if (objectKey == nil || [objectKey length] == 0) {
        return;
    }
    _getRequest = [OSSGetObjectRequest new];
    _getRequest.bucketName = BUCKET_NAME;
    _getRequest.objectKey = objectKey;
    OSSTask * task = [_client getObject:_getRequest];
    [task continueWithBlock:^id(OSSTask *task) {
        OSSGetObjectResult * result = task.result;
        if (!task.error) {
            NSLog(@"Get image success!");
            dispatch_async(dispatch_get_main_queue(), ^{
                DataCallback * data = [DataCallback new];
                [data setAction:1];
                [data setDownload:result.downloadedData];
                [data setObjectKey:objectKey];
                [data setCode:1];
                [data setShowMessage:@"下载"];
                [data setInputMessage:@"Success!"];
                [self setCallback:data];
            });
        } else {
            NSLog(@"Get image failed, %@", task.error);
            if (task.error.code == OSSClientErrorCodeTaskCancelled) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    DataCallback * data = [DataCallback new];
                    [data setAction:1];
                    [data setCode:0];
                    [data setShowMessage:@"下载"];
                    [data setInputMessage:@"任务取消!"];
                    [self setCallback:data];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    DataCallback * data = [DataCallback new];
                    [data setAction:1];
                    [data setCode:-1];
                    [data setShowMessage:@"下载"];
                    [data setInputMessage:@"Failed!"];
                    [self setCallback:data];
                });
            }
        }
        _getRequest = nil;
        return nil;
    }];
}

- (void)normalRequestCancel {
    [self requestCancel:_putRequest];
    [self requestCancel:_getRequest];
}

- (void)requestCancel:(OSSRequest *)request {
    if (request) {
        [request cancel];
        request = nil;
    }
}

/**
 断点续传
 */
- (void)resumableUpload:(NSString *)objectKey localFilePath:(NSString *)filePath {
    if (objectKey == nil || [objectKey length] == 0) {
        return;
    }
    
    _resumableRequest = [OSSResumableUploadRequest new];
    _resumableRequest.bucketName = BUCKET_NAME;
    _resumableRequest.objectKey = objectKey;
    _resumableRequest.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    _resumableRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    OSSTask * task = [_client resumableUpload:_resumableRequest];
    [task continueWithBlock:^id(OSSTask *task)  {
        OSSResumableUploadResult * result = task.result;
        if (!task.error) {
            NSLog(@"resumable success!");
            NSLog(@"server callback : %@", result.serverReturnJsonString);
            dispatch_async(dispatch_get_main_queue(), ^{
                DataCallback * data = [DataCallback new];
                [data setCode:1];
                [data setObjectKey:objectKey];
                [data setShowMessage:@"断点续传"];
                [data setInputMessage:@"Success!"];
                [self setCallback:data];
            });
            _resumableRequest = nil;
        } else {
            NSLog(@"resumable failed, %@", task.error);
            if (task.error.code == OSSClientErrorCodeTaskCancelled) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    DataCallback * data = [DataCallback new];
                    [data setCode:0];
                    [data setObjectKey:objectKey];
                    [data setShowMessage:@"断点续传"];
                    [data setInputMessage:@"任务取消!"];
                    [self setCallback:data];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    DataCallback * data = [DataCallback new];
                    [data setCode:-1];
                    [data setObjectKey:objectKey];
                    [data setShowMessage:@"断点续传"];
                    [data setInputMessage:@"Failed!"];
                    [self setCallback:data];
                });
            }
        }
        return nil;
    }];
}
/**
 追加上传
 */
- (void)appendUpload:(NSString *)objectKey localFilePath:(NSString *)filePath {
    
}
/**
 创建bucket
 */
- (void)createBucket {
    
}
/**
 删除bucket
 */
- (void)deleteBucket {
    
}
/**
 列举object
 */
- (void)listObject {
    
}


@end

