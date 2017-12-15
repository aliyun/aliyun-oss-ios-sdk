//
//  OSSCompat.h
//  oss_ios_sdk_new
//
//  Created by zhouzhuo on 9/10/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSService.h"

@class OSSCancellationTokenSource;

typedef OSSCancellationTokenSource OSSTaskHandler;

NS_ASSUME_NONNULL_BEGIN

@interface OSSClient (Compat)

/**
 The old version's upload API.
 Please use putObject instead.
 */
- (OSSTaskHandler *)uploadData:(NSData *)data
               withContentType:(NSString *)contentType
                withObjectMeta:(NSDictionary *)meta
                  toBucketName:(NSString *)bucketName
                   toObjectKey:(NSString *)objectKey
                   onCompleted:(void(^)(BOOL, NSError *))onCompleted
                    onProgress:(void(^)(float progress))onProgress;

/**
 The old version's download API.
 Please use getObject instead.
 */
- (OSSTaskHandler *)downloadToDataFromBucket:(NSString *)bucketName
                   objectKey:(NSString *)objectKey
                 onCompleted:(void(^)(NSData *, NSError *))onCompleted
                  onProgress:(void(^)(float progress))onProgress;

/**
 The old version's upload API.
 Please use putObject instead.
 */
- (OSSTaskHandler *)uploadFile:(NSString *)filePath
                withContentType:(NSString *)contentType
                 withObjectMeta:(NSDictionary *)meta
                   toBucketName:(NSString *)bucketName
                    toObjectKey:(NSString *)objectKey
                    onCompleted:(void(^)(BOOL, NSError *))onCompleted
                     onProgress:(void(^)(float progress))onProgress;

/**
 The old version's download API.
 Please use getObject instead.
 */
- (OSSTaskHandler *)downloadToFileFromBucket:(NSString *)bucketName
                  objectKey:(NSString *)objectKey
                     toFile:(NSString *)filePath
                onCompleted:(void(^)(BOOL, NSError *))onCompleted
                 onProgress:(void(^)(float progress))onProgress;


/**
 The old version's upload API with resumable upload support.
 Please use resumableUpload instead.
 */
- (OSSTaskHandler *)resumableUploadFile:(NSString *)filePath
          withContentType:(NSString *)contentType
           withObjectMeta:(NSDictionary *)meta
             toBucketName:(NSString *)bucketName
              toObjectKey:(NSString *)objectKey
              onCompleted:(void(^)(BOOL, NSError *))onCompleted
               onProgress:(void(^)(float progress))onProgress;

/**
 The old version's delete API.
 Please use deleteObject instead.
 */
- (void)deleteObjectInBucket:(NSString *)bucketName
                   objectKey:(NSString *)objectKey
                 onCompleted:(void(^)(BOOL, NSError *))onCompleted;
@end

NS_ASSUME_NONNULL_END
