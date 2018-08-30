//
//  DownloadService.h
//  AliyunOSSSDK-iOS-Example
//
//  Created by huaixu on 2018/8/9.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>

typedef void(^DownloadProgressBlock)(int64_t bytesReceived, int64_t totalBytesReceived, int64_t totalBytesExpectToReceived);
typedef void(^DownloadFailureBlock)(NSError *error);
typedef void(^DownloadSuccessBlock)(NSDictionary *result);

@interface Checkpoint : NSObject<NSCopying>

@property (nonatomic, copy) NSString *etag;     // 资源的etag值
@property (nonatomic, assign) unsigned long long totalExpectedLength;    //文件总大小

@end

@interface DownloadRequest : NSObject

@property (nonatomic, copy) NSString *sourceURLString;      // 用于下载的url

@property (nonatomic, copy) NSString *headURLString;        // 用于获取文件原信息的url

@property (nonatomic, copy) NSString *downloadFilePath;     // 文件的本地存储地址

@property (nonatomic, copy) DownloadProgressBlock downloadProgress; // 下载进度

@property (nonatomic, copy) DownloadFailureBlock failure;   // 下载成功的回调

@property (nonatomic, copy) DownloadSuccessBlock success;   // 下载失败的回调

@property (nonatomic, copy) Checkpoint *checkpoint;         // checkpoint,用于存储文件的etag

@end


@interface DownloadService : NSObject

+ (instancetype)downloadServiceWithRequest:(DownloadRequest *)request;

/**
 * 启动下载
 */
- (void)resume;

/**
 * 暂停下载
 */
- (void)pause;

/**
 * 取消下载
 */
- (void)cancel;

@end
