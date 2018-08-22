//
//  DownloadService.h
//  AliyunOSSSDK-iOS-Example
//
//  Created by huaixu on 2018/8/9.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>

typedef void(^OnReceiveData)(NSData *data);
typedef void(^DownloadProgressBlock)(int64_t bytesReceived, int64_t totalBytesReceived, int64_t totalBytesExpectToReceived);

@interface DownloadRequest : NSObject

@property (nonatomic, copy) NSString *bucketName;

@property (nonatomic, copy) NSString *objectName;

@property (nonatomic, copy) NSDictionary *headers;

@property (nonatomic, copy) NSString *downloadFilePath;

@property (nonatomic, copy) OnReceiveData onReceiveData;

@property (nonatomic, copy) DownloadProgressBlock downloadProgress;

- (void)cancel;

@end


@interface DownloadService : NSObject

- (OSSTask *)downloadObject:(DownloadRequest *)request;

@end
