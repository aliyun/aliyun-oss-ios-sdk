//
//  OssService.h
//  OssIOSDemo
//  Created by jingdan on 17/11/23.
//  Copyright © 2015年 Ali. All rights reserved.
//

#ifndef OssService_h
#define OssService_h
#import <AliyunOSSiOS/OSSService.h>
#import "ViewController.h"
@class DataCallback;

@interface OssService : NSObject
@property (nonatomic, strong) DataCallback * callback;

- (id)initWithEndPoint:(NSString *)enpoint;

- (void)setCallbackAddress:(NSString *)address;

- (void)asyncPutImage:(NSString *)objectKey
        localFilePath:(NSString *)filePath;

- (void)asyncGetImage:(NSString *)objectKey;

- (void)normalRequestCancel;

- (void)resumableUpload:(NSString *)objectKey localFilePath:(NSString *)filePath;

- (void)appendUpload:(NSString *)objectKey localFilePath:(NSString *)filePath;

- (void)createBucket;

- (void)deleteBucket;

- (void)listObject;

@end

#endif /* OssService_h */

