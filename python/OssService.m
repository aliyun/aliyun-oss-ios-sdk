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

NSString * const bucketName = @"sdk-demo";
NSString * const STSServer = @"http://oss-demo.aliyuncs.com/app-server/sts.php";

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
 *	@brief	获取FederationToken
 *
 *	@return
 */
- (OSSFederationToken *) getFederationToken {
    NSURL * url = [NSURL URLWithString:STSServer];
    NSURLRequest * request = [NSURLRequest requestWithURL:url];
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    NSURLSession * session = [NSURLSession sharedSession];
    NSURLSessionTask * sessionTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        [tcs setError:error];
                                                        return;
                                                    }
                                                    [tcs setResult:data];
                                                }];
    [sessionTask resume];

    // 实现这个回调需要同步返回Token，所以要waitUntilFinished
    [tcs.task waitUntilFinished];
    if (tcs.task.error) {
        return nil;
    } else {
        NSDictionary * object = [NSJSONSerialization JSONObjectWithData:tcs.task.result
                                                                options:kNilOptions
                                                                  error:nil];
        OSSFederationToken * token = [OSSFederationToken new];
        token.tAccessKey = [object objectForKey:@"AccessKeyId"];
        token.tSecretKey = [object objectForKey:@"AccessKeySecret"];
        token.tToken = [object objectForKey:@"SecurityToken"];
        token.expirationTimeInGMTFormat = [object objectForKey:@"Expiration"];
        NSLog(@"AccessKey: %@ \n SecretKey: %@ \n Token:%@ expirationTime: %@ \n",
              token.tAccessKey, token.tSecretKey, token.tToken, token.expirationTimeInGMTFormat);
        
        return token;
    }
    
}

/**
 *	@brief	初始化获取OSSClient
 */
- (void)ossInit {
    id<OSSCredentialProvider> credential = [[OSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^OSSFederationToken * {
        return [self getFederationToken];
    }];
    client = [[OSSClient alloc] initWithEndpoint:endPoint credentialProvider:credential];
}


/**
 *	@brief	设置server callback地址
 *
 *	@param 	address
 */
- (void)setCallbackAddress:(NSString *)address {
    callbackAddress = address;
}


/**
 *	@brief	上传图片
 *
 *	@param 	objectKey 	objectKey
 *	@param 	filePath 	路径
 */
- (void)asyncPutImage:(NSString *)objectKey
        localFilePath:(NSString *)filePath {

    if (objectKey == nil || [objectKey length] == 0) {
        return;
    }
    
    putRequest = [OSSPutObjectRequest new];
    putRequest.bucketName = bucketName;
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
 *	@brief	下载图片
 *
 *	@param 	objectKey
 */
- (void)asyncGetImage:(NSString *)objectKey {
    if (objectKey == nil || [objectKey length] == 0) {
        return;
    }
    getRequest = [OSSGetObjectRequest new];
    getRequest.bucketName = bucketName;
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

- (void)doResumableUpload {
    resumableRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    OSSTask * resumeTask = [client resumableUpload:resumableRequest];
    [resumeTask continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            NSLog(@"Resumable put success!");
            // 清空该项纪录
            [uploadStatusRecorder removeObjectForKey:currentUploadRecordKey];
            if (isResumeUpload) {
                currentUploadRecordKey = @"";
                isResumeUpload = NO;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [viewController showMessage:@"恢复暂停任务上传" inputMessage:@"Success!"];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [viewController showMessage:@"断点上传" inputMessage:@"Success!"];
                });
            }
            
        } else {
            NSLog(@"Resumable put failed, %@", task.error);
            // 无法继续上传错误，删除该项记录，重新获取uploadId上传
            if ([task.error.domain isEqualToString:OSSClientErrorDomain] && task.error.code == OSSClientErrorCodeCannotResumeUpload) {
                [uploadStatusRecorder removeObjectForKey:currentUploadRecordKey];
            } else if ([[NSString stringWithFormat:@"%@", task.error] containsString:@"cancel"]) {
                NSLog(@"Resumable put cancel!");
                // 用户主动取消上传任务
                if (isCancelled) {
                    OSSAbortMultipartUploadRequest * abortRequest = [OSSAbortMultipartUploadRequest new];
                    abortRequest.bucketName = resumableRequest.bucketName;
                    abortRequest.objectKey = resumableRequest.objectKey;
                    abortRequest.uploadId = resumableRequest.uploadId;
                    OSSTask * task = [client abortMultipartUpload:abortRequest];
                    [task continueWithBlock:^id(OSSTask *task) {
                        if (!task.error) {
                            NSLog(@"断点上传删除服务端uploadId");
                        }
                        return nil;
                    }];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [viewController showMessage:@"断点上传" inputMessage:@"任务取消!"];
                        isCancelled = NO;
                        [uploadStatusRecorder removeObjectForKey:currentUploadRecordKey];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [viewController showMessage:@"断点上传" inputMessage:@"Paused!"];
                    });
                }
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [viewController showMessage:@"断点上传" inputMessage:@"Failed!"];
                });
            }
        }
        return nil;
    }];
}

/**
 *	@brief	断点上传，可暂停，然后恢复上传任务继续
 *          调用OSSResumableUpload，根据计算md5(fileMd5 + bucketName + objectKey + partSize),作为上传纪录key
 *	@param 	objectKey 	设置上传文件的objectKey
 *	@param 	filePath 	文件路径
 *	@param 	size        分片大小
 */
- (void)resumableUpload:(NSString *)objectKey
          localFilePath:(NSString *)filePath
               partSize:(int)size {
    resumableRequest = [OSSResumableUploadRequest new];

    NSString * fileMd5 = [OSSUtil fileMD5String:filePath];

    // 从文件内容MD5、上传的目标地址、分片大小获取一个唯一标识
    NSString * recordIdentifier = [OSSUtil dataMD5String:
                            [[NSString stringWithFormat:@"%@%@%@%d", fileMd5, bucketName, objectKey, size] dataUsingEncoding:NSUTF8StringEncoding]];
    NSLog(@"upload record identifier: %@", recordIdentifier);
    currentUploadRecordKey = recordIdentifier;

    resumableRequest = [OSSResumableUploadRequest new];
    resumableRequest.bucketName = bucketName;
    resumableRequest.objectKey = objectKey;
    resumableRequest.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    resumableRequest.partSize = size;

    __block NSString * uploadId = [uploadStatusRecorder objectForKey:currentUploadRecordKey];
    if (uploadId == nil) {
        // get uploadId
        OSSInitMultipartUploadRequest * init = [OSSInitMultipartUploadRequest new];
        init.bucketName = bucketName;
        init.objectKey = objectKey;
        OSSTask * task = [client multipartUploadInit:init];
        [task continueWithBlock:^id(OSSTask *task) {
            if (!task.error) {
                OSSInitMultipartUploadResult * result = task.result;
                resumableRequest.uploadId = result.uploadId;
                [uploadStatusRecorder setObject:result.uploadId forKey:currentUploadRecordKey];
                [self doResumableUpload];
            } else {
                NSLog(@"Get uploadId failed, %@", task.error);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [viewController showMessage:@"断点上传" inputMessage:@"Get uploadId failed!"];
                });
            }
            return nil;
        }];
    } else {
        isResumeUpload = YES;
        resumableRequest.uploadId = uploadId;
        [self doResumableUpload];
    }
}


/**
 *	@brief	断点续传暂停
 */
- (void)resumableUploadPause {
    if (!resumableRequest.isCancelled) {
        isCancelled = NO;
        [resumableRequest cancel];
    }
}

/**
 *	@brief	普通上传/下载取消
 */
- (void)normalRequestCancel {
    if (putRequest) {
        [putRequest cancel];
    }
    if (getRequest) {
        [getRequest cancel];
    }
}

/**
 *	@brief	断点上传任务取消
 */
- (void)ResumableUploadCancel {
    if (!resumableRequest.isCancelled) {
        isCancelled = YES;
        [resumableRequest cancel];
    }
}

@end
