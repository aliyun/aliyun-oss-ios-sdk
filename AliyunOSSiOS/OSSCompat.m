//
//  OSSCompat.m
//  oss_ios_sdk_new
//
//  Created by zhouzhuo on 9/10/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import "OSSCompat.h"


int64_t const OSSMultipartUploadDefaultBlockSize = 256 * 1024;

BFExecutor * executor;

@implementation OSSClient (Compat)

+ (void)initialize {
    NSOperationQueue * queue = [NSOperationQueue new];
    queue.maxConcurrentOperationCount = 5;
    executor = [BFExecutor executorWithOperationQueue:queue];
}

- (BFCancellationTokenSource *)uploadData:(NSData *)data
                          withContentType:(NSString *)contentType
                           withObjectMeta:(NSDictionary *)meta
                             toBucketName:(NSString *)bucketName
                              toObjectKey:(NSString *)objectKey
                              onCompleted:(void(^)(BOOL, NSError *))onCompleted
                               onProgress:(void(^)(float progress))onProgress {

    BFCancellationTokenSource * bcts = [BFCancellationTokenSource cancellationTokenSource];

    [[[BFTask taskWithResult:nil] continueWithExecutor:executor withSuccessBlock:^id(BFTask *task) {
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

        BFTask * putTask = [self putObject:put];
        [putTask waitUntilFinished];
        onProgress(1.0f);
        return putTask;
    }] continueWithBlock:^id(BFTask *task) {
        if (task.error) {
            onCompleted(NO, task.error);
        } else {
            onCompleted(YES, nil);
        }
        return nil;
    }];
    return bcts;
}

- (BFCancellationTokenSource *)downloadToDataFromBucket:(NSString *)bucketName
                                 objectKey:(NSString *)objectKey
                               onCompleted:(void (^)(NSData *, NSError *))onCompleted
                                onProgress:(void (^)(float))onProgress {

    BFCancellationTokenSource * bcts = [BFCancellationTokenSource cancellationTokenSource];

    [[[BFTask taskWithResult:nil] continueWithExecutor:executor withBlock:^id(BFTask *task) {
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

        BFTask * getTask = [self getObject:get];
        [getTask waitUntilFinished];
        onProgress(1.0f);
        return getTask;
    }] continueWithBlock:^id(BFTask *task) {
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

- (BFCancellationTokenSource *)downloadToFileFromBucket:(NSString *)bucketName
                                 objectKey:(NSString *)objectKey
                                    toFile:(NSString *)filePath
                               onCompleted:(void (^)(BOOL, NSError *))onCompleted
                                onProgress:(void (^)(float))onProgress {

    BFCancellationTokenSource * bcts = [BFCancellationTokenSource cancellationTokenSource];

    [[[BFTask taskWithResult:nil] continueWithExecutor:executor withBlock:^id(BFTask *task) {
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

        BFTask * getTask = [self getObject:get];
        [getTask waitUntilFinished];
        onProgress(1.0f);
        return getTask;
    }] continueWithBlock:^id(BFTask *task) {
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

    [[[BFTask taskWithResult:nil] continueWithExecutor:executor withBlock:^id(BFTask *task) {
        OSSDeleteObjectRequest * delete = [OSSDeleteObjectRequest new];
        delete.bucketName = bucketName;
        delete.objectKey = objectKey;

        BFTask * deleteTask = [self deleteObject:delete];
        [deleteTask waitUntilFinished];
        return deleteTask;
    }] continueWithBlock:^id(BFTask *task) {
        if (task.error) {
            onCompleted(NO, task.error);
        } else {
            onCompleted(YES, nil);
        }
        return nil;
    }];
}

- (BFCancellationTokenSource *)uploadFile:(NSString *)filePath
                          withContentType:(NSString *)contentType
                           withObjectMeta:(NSDictionary *)meta
                             toBucketName:(NSString *)bucketName
                              toObjectKey:(NSString *)objectKey
                              onCompleted:(void (^)(BOOL, NSError *))onCompleted
                               onProgress:(void (^)(float))onProgress {

    BFCancellationTokenSource * bcts = [BFCancellationTokenSource cancellationTokenSource];

    [[[BFTask taskWithResult:nil] continueWithExecutor:executor withSuccessBlock:^id(BFTask *task) {
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

        BFTask * putTask = [self putObject:put];
        [putTask waitUntilFinished];
        onProgress(1.0f);
        return putTask;
    }] continueWithBlock:^id(BFTask *task) {
        if (task.error) {
            onCompleted(NO, task.error);
        } else {
            onCompleted(YES, nil);
        }
        return nil;
    }];
    return bcts;
}

- (BFCancellationTokenSource *)resumableUploadFile:(NSString *)filePath
                            withContentType:(NSString *)contentType
                             withObjectMeta:(NSDictionary *)meta
                               toBucketName:(NSString *)bucketName
                                toObjectKey:(NSString *)objectKey
                                onCompleted:(void(^)(BOOL, NSError *))onComplete
                                 onProgress:(void(^)(float progress))onProgress {

    __block NSString * recordKey;
    __block int64_t uploadedLength = 0;
    __block int64_t expectedUploadLength = 0;
    BFCancellationTokenSource * bcts = [BFCancellationTokenSource cancellationTokenSource];

    [[[[[BFTask taskWithResult:nil] continueWithExecutor:executor withSuccessBlock:^id(BFTask *task) {
        NSURL * fileURL = [NSURL fileURLWithPath:filePath];
        NSDate * lastModified;
        NSError * error;
        [fileURL getResourceValue:&lastModified forKey:NSURLContentModificationDateKey error:&error];
        if (error) {
            return [BFTask taskWithError:error];
        }
        recordKey = [NSString stringWithFormat:@"%@-%@-%@-%@", bucketName, objectKey, filePath, lastModified];
        NSUserDefaults * userDefault = [NSUserDefaults standardUserDefaults];
        NSString * uploadId;
        NSMutableDictionary * initResult = [NSMutableDictionary new];

        if ((uploadId = [userDefault objectForKey:recordKey])) {
            OSSLogVerbose(@"old record found, try to recover the task");
            OSSListPartsRequest * listParts = [OSSListPartsRequest new];
            listParts.bucketName = bucketName;
            listParts.objectKey = objectKey;
            listParts.uploadId = uploadId;
            BFTask * listTask = [self listParts:listParts];
            [listTask waitUntilFinished];
            if (listTask.error) {
                if(listTask.error.domain == OSSServerErrorDomain && listTask.error.code == -1 * 404) {
                    OSSLogVerbose(@"local record existes but the remote record is deleted");
                    [userDefault removeObjectForKey:recordKey];
                    uploadId = nil;
                } else {
                    return listTask;
                }
            } else {
                OSSListPartsResult * result = listTask.result;
                [initResult setObject:uploadId forKey:@"uploadId"];
                [initResult setObject:result.parts forKey:@"parts"];
                [result.parts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    NSDictionary * dict = obj;
                    uploadedLength += [[dict objectForKey:OSSSizeXMLTOKEN] longLongValue];
                }];
                return [BFTask taskWithResult:initResult];
            }
        }

        // uploadId is nil
        OSSInitMultipartUploadRequest * initMultipart = [OSSInitMultipartUploadRequest new];
        initMultipart.bucketName = bucketName;
        initMultipart.objectKey = objectKey;
        initMultipart.contentType = contentType;
        initMultipart.objectMeta = meta;
        BFTask * initTask = [self multipartUploadInit:initMultipart];
        [initTask waitUntilFinished];
        if (initTask.error) {
            return initTask;
        }

        uploadId = ((OSSInitMultipartUploadResult *)initTask.result).uploadId;
        if (!uploadId) {
            return [BFTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                             code:OSSClientErrorCodeNilUploadid
                                                         userInfo:@{OSSErrorMessageTOKEN: @"Can't get an upload id"}]];
        }
        [initResult setObject:uploadId forKey:@"uploadId"];
        [userDefault setObject:uploadId forKey:recordKey];
        [userDefault synchronize];
        return [BFTask taskWithResult:initResult];
    }] continueWithSuccessBlock:^id(BFTask *task) {
        NSDictionary * initResult = task.result;
        NSString * uploadId = [initResult objectForKey:@"uploadId"];
        NSMutableArray * uploadedParts = [NSMutableArray arrayWithArray:[initResult objectForKey:@"parts"]];
        NSFileManager * fm = [NSFileManager defaultManager];
        NSError * error;

        int64_t uploadFileSize = [[[fm attributesOfItemAtPath:filePath error:&error] objectForKey:NSFileSize] longLongValue];
        expectedUploadLength = uploadFileSize;
        if (error) {
            return [BFTask taskWithError:error];
        }
        int blockNum = (int)(uploadFileSize / OSSMultipartUploadDefaultBlockSize) + (uploadFileSize % OSSMultipartUploadDefaultBlockSize != 0);

        NSMutableArray * alreadyUpload = [NSMutableArray new];
        NSMutableArray * alreadyUploadPartIndex = [NSMutableArray new];
        [uploadedParts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSDictionary * dict = obj;
            OSSPartInfo * part = [OSSPartInfo partInfoWithPartNum:[[dict objectForKey:OSSPartNumberXMLTOKEN] intValue]
                                                             eTag:[dict objectForKey:OSSETagXMLTOKEN]
                                                             size:[[dict objectForKey:OSSSizeXMLTOKEN] longLongValue]];
            [alreadyUploadPartIndex addObject:@(part.partNum)];
            [alreadyUpload addObject:part];
        }];

        NSFileHandle * handle = [NSFileHandle fileHandleForReadingAtPath:filePath];

        if (expectedUploadLength) {
            onProgress((float)uploadedLength/expectedUploadLength);
        }

        for (int i = 1; i <= blockNum; i++) {
            if ([alreadyUploadPartIndex containsObject:@(i)]) {
                continue; // this block is already uploaded
            }

            if (bcts.isCancellationRequested) {
                return [BFTask cancelledTask];
            }
            OSSLogDebug(@"Upload Thread: %@", [NSThread currentThread]);

            [handle seekToFileOffset:OSSMultipartUploadDefaultBlockSize * (i-1)];
            int64_t readLength = MIN(OSSMultipartUploadDefaultBlockSize, uploadFileSize - (OSSMultipartUploadDefaultBlockSize * (i-1)));

            OSSUploadPartRequest * uploadPart = [OSSUploadPartRequest new];
            uploadPart.bucketName = bucketName;
            uploadPart.objectkey = objectKey;
            uploadPart.partNumber = i;
            uploadPart.uploadId = uploadId;
            uploadPart.uploadPartData = [handle readDataOfLength:(NSUInteger)readLength];
            BFTask * uploadPartTask = [self uploadPart:uploadPart];
            [uploadPartTask waitUntilFinished];
            if (uploadPartTask.error) {
                return uploadPartTask;
            }
            OSSUploadPartResult * result = uploadPartTask.result;
            OSSPartInfo * partInfo = [OSSPartInfo new];
            partInfo.partNum = i;
            partInfo.eTag = result.eTag;
            [alreadyUpload addObject:partInfo];

            uploadedLength += readLength;
            if (expectedUploadLength) {
                onProgress((float)uploadedLength/expectedUploadLength);
            }
        }
        [handle closeFile];
        NSDictionary * uploadPartsResult = [NSDictionary dictionaryWithObjectsAndKeys:uploadId, @"uploadId",
                                            alreadyUpload, @"parts", nil];
        return [BFTask taskWithResult:uploadPartsResult];
    }] continueWithSuccessBlock:^id(BFTask *task) {
        NSDictionary * uploadPartsResult = task.result;
        NSString * uploadId = [uploadPartsResult objectForKey:@"uploadId"];
        NSArray * alreadyUploadParts = [uploadPartsResult objectForKey:@"parts"];

        if (bcts.token.isCancellationRequested) {
            return [BFTask cancelledTask];
        }

        OSSCompleteMultipartUploadRequest * complete = [OSSCompleteMultipartUploadRequest new];
        complete.bucketName = bucketName;
        complete.objectKey = objectKey;
        complete.uploadId = uploadId;
        complete.partInfos = alreadyUploadParts;
        BFTask * completeTask = [self completeMultipartUpload:complete];
        [completeTask waitUntilFinished];
        if (completeTask.error) {
            return completeTask;
        }
        onProgress(1.0f);
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:recordKey];
        return [BFTask taskWithResult:nil];
    }] continueWithBlock:^id(BFTask *task) {
        if (task.error) {
            onComplete(NO, task.error);
        } else {
            onComplete(YES, nil);
        }
        return nil;
    }];
    return bcts;
}

@end
