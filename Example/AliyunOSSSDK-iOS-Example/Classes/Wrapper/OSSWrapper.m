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

- (void)normalRequestCancel {
    if (_normalUploadRequest) {
        [_normalUploadRequest cancel];
    }
}

@end
