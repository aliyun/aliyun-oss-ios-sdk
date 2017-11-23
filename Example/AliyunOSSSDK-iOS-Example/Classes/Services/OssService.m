//
//  OssService.m
//  OssIOSDemo
//
//  Created by 凌琨 on 15/12/15.
//  Copyright © 2015年 Ali. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AliyunOSSiOS/OSSService.h>
#import "OssService.h"

@implementation OssService
{
    OSSClient * client;
    NSString * endPoint;
    NSString * callbackAddress;
    NSMutableDictionary * uploadStatusRecorder;
    NSString * currentUploadRecordKey;
    OSSPutObjectRequest * putRequest;
    OSSGetObjectRequest * getRequest;
    
    // 简单起见，全局只维护一个断点上传任务
    OSSResumableUploadRequest * resumableRequest;
    ViewController * viewController;
    BOOL isCancelled;
    BOOL isResumeUpload;
}

- (id)initWithViewController:(ViewController *)view
                withEndPoint:(NSString *)enpoint {
    if (self = [super init]) {
        viewController = view;
        endPoint = enpoint;
        isResumeUpload = NO;
        isCancelled = NO;
        currentUploadRecordKey = @"";
        uploadStatusRecorder = [NSMutableDictionary new];
        [self ossInit];
    }
    return self;
}

/**
 *    @brief    初始化获取OSSClient
 */
- (void)ossInit {
    id<OSSCredentialProvider> credential = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:STS_AUTH_URL];
    client = [[OSSClient alloc] initWithEndpoint:endPoint credentialProvider:credential];
}


/**
 *    @brief    设置server callback地址
 */
- (void)setCallbackAddress:(NSString *)address {
    callbackAddress = address;
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
    
    putRequest = [OSSPutObjectRequest new];
    putRequest.bucketName = BUCKET_NAME;
    putRequest.objectKey = objectKey;
    putRequest.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    putRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    if (callbackAddress != nil) {
        putRequest.callbackParam = @{
                                     @"callbackUrl": callbackAddress,
                                     // callbackBody可自定义传入的信息
                                     @"callbackBody": @"filename=${object}"
                                     };
    }
    OSSTask * task = [client putObject:putRequest];
    [task continueWithBlock:^id(OSSTask *task) {
        OSSPutObjectResult * result = task.result;
        // 查看server callback是否成功
        if (!task.error) {
            NSLog(@"Put image success!");
            NSLog(@"server callback : %@", result.serverReturnJsonString);
            dispatch_async(dispatch_get_main_queue(), ^{
                [viewController showMessage:@"普通上传" inputMessage:@"Success!"];
            });
        } else {
            NSLog(@"Put image failed, %@", task.error);
            if (task.error.code == OSSClientErrorCodeTaskCancelled) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [viewController showMessage:@"普通上传" inputMessage:@"任务取消!"];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [viewController showMessage:@"普通上传" inputMessage:@"Failed!"];
                });
            }
        }
        putRequest = nil;
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
    getRequest = [OSSGetObjectRequest new];
    getRequest.bucketName = BUCKET_NAME;
    getRequest.objectKey = objectKey;
    OSSTask * task = [client getObject:getRequest];
    [task continueWithBlock:^id(OSSTask *task) {
        OSSGetObjectResult * result = task.result;
        if (!task.error) {
            NSLog(@"Get image success!");
            dispatch_async(dispatch_get_main_queue(), ^{
                [viewController saveAndDisplayImage:result.downloadedData downloadObjectKey:objectKey];
                [viewController showMessage:@"普通下载" inputMessage:@"Success!"];
            });
        } else {
            NSLog(@"Get image failed, %@", task.error);
            if (task.error.code == OSSClientErrorCodeTaskCancelled) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [viewController showMessage:@"普通下载" inputMessage:@"任务取消!"];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [viewController showMessage:@"普通下载" inputMessage:@"Failed!"];
                });
            }
        }
        getRequest = nil;
        return nil;
    }];
}


/**
 *    @brief    普通上传/下载取消
 */
- (void)normalRequestCancel {
    if (putRequest) {
        [putRequest cancel];
    }
    if (getRequest) {
        [getRequest cancel];
    }
}


@end

