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
@interface OssService : NSObject

- (void)asyncPutImage:(NSString *)objectKey
        localFilePath:(NSString *)filePath
              success:(void (^_Nullable)(id))success
              failure:(void (^_Nullable)(NSError*))failure;

- (void)asyncGetImage:(NSString *)objectKey success:(void (^_Nullable)(id))success failure:(void (^_Nullable)(NSError*))failure;

- (void)normalRequestCancel;

- (void)triggerCallbackWithObjectKey:(NSString *)objectKey success:(void (^_Nullable)(id))success failure:(void (^_Nullable)(NSError*))failure;

- (void)multipartUploadWithSuccess:(void (^_Nullable)(id))success failure:(void (^_Nullable)(NSError*))failure;

@end

#endif /* OssService_h */

