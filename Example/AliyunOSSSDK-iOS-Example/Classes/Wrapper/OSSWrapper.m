//
//  OSSWrapper.m
//  AliyunOSSSDK-iOS-Example
//
//  Created by huaixu on 2018/10/23.
//  Copyright © 2018 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSWrapper.h"
#import "OSSManager.h"
#import "OSSTestMacros.h"

@interface OSSWrapper ()

@property (nonatomic, strong) OSSPutObjectRequest *normalUploadRequest;

@property (nonatomic, strong) OSSGetObjectRequest *normalDloadRequest;

@end

// 字体，默认文泉驿正黑
NSString * const font = @"d3F5LXplbmhlaQ==";

@implementation OSSWrapper

- (void)asyncGetImage:(NSString *)objectKey success:(void (^)(id _Nullable))success failure:(void (^)(NSError * _Nonnull))failure {
    if (![objectKey oss_isNotEmpty]) {
        NSError *error = [NSError errorWithDomain:NSInvalidArgumentException code:0 userInfo:@{NSLocalizedDescriptionKey: @"objectKey should not be nil"}];
        failure(error);
        return;
    }
    
    NSString *downloadFilePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:objectKey];
    
    _normalDloadRequest = [OSSGetObjectRequest new];
    _normalDloadRequest.bucketName = OSS_BUCKET_PRIVATE;
    _normalDloadRequest.objectKey = objectKey;
    _normalDloadRequest.downloadToFileURL = [NSURL URLWithString:downloadFilePath];
    _normalDloadRequest.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        float progress = 1.f * totalBytesWritten / totalBytesExpectedToWrite;
        OSSLogDebug(@"下载文件进度: %f", progress);
    };
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSSTask * task = [[OSSManager sharedManager].imageClient getObject:_normalDloadRequest];
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
    });
}

- (void)asyncPutImage:(NSString *)objectKey localFilePath:(NSString *)filePath success:(void (^)(id _Nullable))success failure:(void (^)(NSError * _Nonnull))failure {
    if (![objectKey oss_isNotEmpty]) {
        NSError *error = [NSError errorWithDomain:NSInvalidArgumentException code:0 userInfo:@{NSLocalizedDescriptionKey: @"objectKey should not be nil"}];
        failure(error);
        return;
    }
    
    _normalUploadRequest = [OSSPutObjectRequest new];
    _normalUploadRequest.bucketName = OSS_BUCKET_PRIVATE;
    _normalUploadRequest.objectKey = objectKey;
    _normalUploadRequest.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    _normalUploadRequest.isAuthenticationRequired = YES;
    _normalUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        float progress = 1.f * totalByteSent / totalBytesExpectedToSend;
        OSSLogDebug(@"上传文件进度: %f", progress);
    };
    _normalUploadRequest.callbackParam = @{
                                           @"callbackUrl": OSS_CALLBACK_URL,
                                           // callbackBody可自定义传入的信息
                                           @"callbackBody": @"filename=${object}"
                                           };
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSSTask * task = [[OSSManager sharedManager].defaultClient putObject:_normalUploadRequest];
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
    });
}

- (void)normalRequestCancel
{
    if (_normalDloadRequest) {
        [_normalDloadRequest cancel];
    }
    
    if (_normalUploadRequest) {
        [_normalUploadRequest cancel];
    }
}

- (void)triggerCallbackWithObjectKey:(NSString *)objectKey success:(void (^)(id _Nonnull))success failure:(void (^)(NSError * _Nonnull))failure {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSSCallBackRequest *request = [OSSCallBackRequest new];
        request.bucketName = OSS_BUCKET_PRIVATE;
        request.objectName = objectKey;
        request.callbackParam = @{@"callbackUrl": OSS_CALLBACK_URL,
                                  @"callbackBody": @"test"};
        request.callbackVar = @{@"var1": @"value1",
                                @"var2": @"value2"};
        
        OSSTask *triggerCBTask = [[OSSManager sharedManager].defaultClient triggerCallBack:request];
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

- (void)multipartUploadWithSuccess:(void (^)(id _Nonnull))success failure:(void (^)(NSError * _Nonnull))failure {
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
        OSSTask * resumeTask = [[OSSManager sharedManager].defaultClient resumableUpload:resumableUpload];
        [resumeTask waitUntilFinished];                             // 阻塞当前线程直到上传任务完成
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (resumeTask.result) {
                success(resumeTask.result);
            } else {
                failure(resumeTask.error);
            }
        });
    });
}

- (void)textWaterMark:(NSString *)object waterText:(NSString *)text objectSize:(int)size success:(void (^)(id _Nonnull))success failure:(void (^)(NSError * _Nonnull))failure {
    NSString * base64Text = [OSSUtil calBase64WithData:(UTF8Char*)[text cStringUsingEncoding:NSASCIIStringEncoding]];
    NSString * queryString = [NSString stringWithFormat:@"@watermark=2&type=%@&text=%@&size=%d",
                              font, base64Text, size];
    NSLog(@"TextWatermark: %@", object);
    NSLog(@"Text: %@", text);
    NSLog(@"QueryString: %@", queryString);
    NSLog(@"%@%@", object, queryString);
    [self asyncGetImage:[NSString stringWithFormat:@"%@%@", object, queryString] success:success failure:failure];
}

- (void)reSize:(NSString *)object picWidth:(int)width picHeight:(int)height success:(void (^)(id _Nonnull))success failure:(void (^)(NSError * _Nonnull))failure {
    NSString * queryString = [NSString stringWithFormat:@"@%dw_%dh_1e_1c", width, height];
    NSLog(@"ResizeImage: %@", object);
    NSLog(@"Width: %d", width);
    NSLog(@"Height: %d", height);
    NSLog(@"QueryString: %@", queryString);
    [self asyncGetImage:[NSString stringWithFormat:@"%@%@", object, queryString] success:success failure:failure];
}

@end
