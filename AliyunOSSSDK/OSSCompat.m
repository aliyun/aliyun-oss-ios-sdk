//
//  OSSCompat.m
//  oss_ios_sdk_new
//
//  Created by zhouzhuo on 9/10/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import "OSSDefine.h"
#import "OSSCompat.h"
#import "OSSBolts.h"
#import "OSSModel.h"

@implementation OSSClient (Compat)

- (OSSTaskHandler *)uploadData:(NSData *)data
               withContentType:(NSString *)contentType
                withObjectMeta:(NSDictionary *)meta
                  toBucketName:(NSString *)bucketName
                   toObjectKey:(NSString *)objectKey
                   onCompleted:(void(^)(BOOL, NSError *))onCompleted
                    onProgress:(void(^)(float progress))onProgress {

    OSSTaskHandler * bcts = [OSSCancellationTokenSource cancellationTokenSource];

    [[[OSSTask taskWithResult:nil] continueWithExecutor:self.ossOperationExecutor withSuccessBlock:^id(OSSTask *task) {
        OSSPutObjectRequest * put = [OSSPutObjectRequest new];
        put.bucketName = bucketName;
        put.objectKey = objectKey;
        put.objectMeta = meta;
        put.uploadingData = data;
        put.contentType = contentType;

        put.uploadProgress = ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
            if (totalBytesExpectedToSend) {
                onProgress((float)totalBytesSent / totalBytesExpectedToSend);
            }
        };

        [bcts.token registerCancellationObserverWithBlock:^{
            [put cancel];
        }];

        OSSTask * putTask = [self putObject:put];
        [putTask waitUntilFinished];
        onProgress(1.0f);
        return putTask;
    }] continueWithBlock:^id(OSSTask *task) {
        if (task.error) {
            onCompleted(NO, task.error);
        } else {
            onCompleted(YES, nil);
        }
        return nil;
    }];
    return bcts;
}

- (OSSTaskHandler *)downloadToDataFromBucket:(NSString *)bucketName
                                 objectKey:(NSString *)objectKey
                               onCompleted:(void (^)(NSData *, NSError *))onCompleted
                                onProgress:(void (^)(float))onProgress {

    OSSTaskHandler * bcts = [OSSCancellationTokenSource cancellationTokenSource];

    [[[OSSTask taskWithResult:nil] continueWithExecutor:self.ossOperationExecutor withBlock:^id(OSSTask *task) {
        OSSGetObjectRequest * get = [OSSGetObjectRequest new];
        get.bucketName = bucketName;
        get.objectKey = objectKey;

        get.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
            if (totalBytesExpectedToWrite) {
                onProgress((float)totalBytesWritten / totalBytesExpectedToWrite);
            }
        };

        [bcts.token registerCancellationObserverWithBlock:^{
            [get cancel];
        }];

        OSSTask * getTask = [self getObject:get];
        [getTask waitUntilFinished];
        onProgress(1.0f);
        return getTask;
    }] continueWithBlock:^id(OSSTask *task) {
        if (task.error) {
            onCompleted(nil, task.error);
        } else {
            OSSGetObjectResult * result = task.result;
            onCompleted(result.downloadedData, nil);
        }
        return nil;
    }];

    return bcts;
}

- (OSSTaskHandler *)downloadToFileFromBucket:(NSString *)bucketName
                                 objectKey:(NSString *)objectKey
                                    toFile:(NSString *)filePath
                               onCompleted:(void (^)(BOOL, NSError *))onCompleted
                                onProgress:(void (^)(float))onProgress {

    OSSTaskHandler * bcts = [OSSCancellationTokenSource cancellationTokenSource];

    [[[OSSTask taskWithResult:nil] continueWithExecutor:self.ossOperationExecutor withBlock:^id(OSSTask *task) {
        OSSGetObjectRequest * get = [OSSGetObjectRequest new];
        get.bucketName = bucketName;
        get.objectKey = objectKey;
        get.downloadToFileURL = [NSURL fileURLWithPath:filePath];

        get.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
            if (totalBytesExpectedToWrite) {
                onProgress((float)totalBytesWritten / totalBytesExpectedToWrite);
            }
        };

        [bcts.token registerCancellationObserverWithBlock:^{
            [get cancel];
        }];

        OSSTask * getTask = [self getObject:get];
        [getTask waitUntilFinished];
        onProgress(1.0f);
        return getTask;
    }] continueWithBlock:^id(OSSTask *task) {
        if (task.error) {
            onCompleted(NO, task.error);
        } else {
            onCompleted(YES, nil);
        }
        return nil;
    }];
    
    return bcts;
}

- (void)deleteObjectInBucket:(NSString *)bucketName
                   objectKey:(NSString *)objectKey
                 onCompleted:(void (^)(BOOL, NSError *))onCompleted {

    [[[OSSTask taskWithResult:nil] continueWithExecutor:self.ossOperationExecutor withBlock:^id(OSSTask *task) {
        OSSDeleteObjectRequest * delete = [OSSDeleteObjectRequest new];
        delete.bucketName = bucketName;
        delete.objectKey = objectKey;

        OSSTask * deleteTask = [self deleteObject:delete];
        [deleteTask waitUntilFinished];
        return deleteTask;
    }] continueWithBlock:^id(OSSTask *task) {
        if (task.error) {
            onCompleted(NO, task.error);
        } else {
            onCompleted(YES, nil);
        }
        return nil;
    }];
}

- (OSSTaskHandler *)uploadFile:(NSString *)filePath
               withContentType:(NSString *)contentType
                withObjectMeta:(NSDictionary *)meta
                  toBucketName:(NSString *)bucketName
                   toObjectKey:(NSString *)objectKey
                   onCompleted:(void (^)(BOOL, NSError *))onCompleted
                    onProgress:(void (^)(float))onProgress {

    OSSTaskHandler * bcts = [OSSCancellationTokenSource cancellationTokenSource];

    [[[OSSTask taskWithResult:nil] continueWithExecutor:self.ossOperationExecutor withSuccessBlock:^id(OSSTask *task) {
        OSSPutObjectRequest * put = [OSSPutObjectRequest new];
        put.bucketName = bucketName;
        put.objectKey = objectKey;
        put.objectMeta = meta;
        put.uploadingFileURL = [NSURL fileURLWithPath:filePath];
        put.contentType = contentType;

        put.uploadProgress = ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
            if (totalBytesExpectedToSend) {
                onProgress((float)totalBytesSent / totalBytesExpectedToSend);
            }
        };

        [bcts.token registerCancellationObserverWithBlock:^{
            [put cancel];
        }];

        OSSTask * putTask = [self putObject:put];
        [putTask waitUntilFinished];
        onProgress(1.0f);
        return putTask;
    }] continueWithBlock:^id(OSSTask *task) {
        if (task.error) {
            onCompleted(NO, task.error);
        } else {
            onCompleted(YES, nil);
        }
        return nil;
    }];
    return bcts;
}

- (OSSTaskHandler *)resumableUploadFile:(NSString *)filePath
                        withContentType:(NSString *)contentType
                         withObjectMeta:(NSDictionary *)meta
                           toBucketName:(NSString *)bucketName
                            toObjectKey:(NSString *)objectKey
                            onCompleted:(void(^)(BOOL, NSError *))onComplete
                             onProgress:(void(^)(float progress))onProgress {

    OSSTaskHandler * bcts = [OSSCancellationTokenSource cancellationTokenSource];

    [[[OSSTask taskWithResult:nil] continueWithBlock:^id(OSSTask *task) {
        NSURL * fileURL = [NSURL fileURLWithPath:filePath];
        NSDate * lastModified;
        NSError * error;
        [fileURL getResourceValue:&lastModified forKey:NSURLContentModificationDateKey error:&error];
        if (error) {
            return [OSSTask taskWithError:error];
        }
        OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
        resumableUpload.bucketName = bucketName;
        resumableUpload.deleteUploadIdOnCancelling = NO;//cancel not delete record file
        resumableUpload.contentType = contentType;
        resumableUpload.completeMetaHeader = meta;
        NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        resumableUpload.recordDirectoryPath = cachesDir; //default record file path
        resumableUpload.uploadingFileURL = fileURL;
        resumableUpload.objectKey = objectKey;
        resumableUpload.uploadId = task.result;
        resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:filePath];
        __weak OSSResumableUploadRequest * weakRef = resumableUpload;
        resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
            onProgress((float)totalBytesSent/totalBytesExpectedToSend);
            if (bcts.token.isCancellationRequested || bcts.isCancellationRequested) {
                [weakRef cancel];
            }
            OSSLogDebugNoFile(@"%lld %lld %lld", bytesSent, totalBytesSent, totalBytesExpectedToSend);
        };
        return [self resumableUpload:resumableUpload];
    }] continueWithBlock:^id(OSSTask *task) {
        if (task.cancelled) {
            onComplete(NO, [NSError errorWithDomain:OSSClientErrorDomain
                                               code:OSSClientErrorCodeTaskCancelled
                                           userInfo:@{OSSErrorMessageTOKEN: @"This task is cancelled"}]);
        } else if (task.error) {
            onComplete(NO, task.error);
        } else if (task.faulted) {
            onComplete(NO, [NSError errorWithDomain:OSSClientErrorDomain
                                               code:OSSClientErrorCodeExcpetionCatched
                                           userInfo:@{OSSErrorMessageTOKEN: [NSString stringWithFormat:@"Catch exception - %@", task.exception]}]);
        } else {
            onComplete(YES, nil);
        }
        return nil;
    }];
    return bcts;
}

@end
