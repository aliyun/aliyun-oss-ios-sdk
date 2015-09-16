//
//  OSSCompat.h
//  oss_ios_sdk_new
//
//  Created by zhouzhuo on 9/10/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSService.h"

typedef BFCancellationTokenSource OSSTaskHandler;

@interface OSSClient (Compat)

- (OSSTaskHandler *)uploadData:(NSData *)data
               withContentType:(NSString *)contentType
                withObjectMeta:(NSDictionary *)meta
                  toBucketName:(NSString *)bucketName
                   toObjectKey:(NSString *)objectKey
                   onCompleted:(void(^)(BOOL, NSError *))onCompleted
                    onProgress:(void(^)(float progress))onProgress;

- (OSSTaskHandler *)downloadToDataFromBucket:(NSString *)bucketName
                   objectKey:(NSString *)objectKey
                 onCompleted:(void(^)(NSData *, NSError *))onCompleted
                  onProgress:(void(^)(float progress))onProgress;

- (OSSTaskHandler *)uploadFile:(NSString *)filePath
                withContentType:(NSString *)contentType
                 withObjectMeta:(NSDictionary *)meta
                   toBucketName:(NSString *)bucketName
                    toObjectKey:(NSString *)objectKey
                    onCompleted:(void(^)(BOOL, NSError *))onCompleted
                     onProgress:(void(^)(float progress))onProgress;

- (OSSTaskHandler *)downloadToFileFromBucket:(NSString *)bucketName
                  objectKey:(NSString *)objectKey
                     toFile:(NSString *)filePath
                onCompleted:(void(^)(BOOL, NSError *))onCompleted
                 onProgress:(void(^)(float progress))onProgress;


- (OSSTaskHandler *)resumableUploadFile:(NSString *)filePath
          withContentType:(NSString *)contentType
           withObjectMeta:(NSDictionary *)meta
             toBucketName:(NSString *)bucketName
              toObjectKey:(NSString *)objectKey
              onCompleted:(void(^)(BOOL, NSError *))onCompleted
               onProgress:(void(^)(float progress))onProgress;

- (void)deleteObjectInBucket:(NSString *)bucketName
                   objectKey:(NSString *)objectKey
                 onCompleted:(void(^)(BOOL, NSError *))onCompleted;
@end