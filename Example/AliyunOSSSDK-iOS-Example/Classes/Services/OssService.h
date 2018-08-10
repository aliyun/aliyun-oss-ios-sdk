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

- (id)initWithViewController:(ViewController *)view
                withEndPoint:(NSString *)enpoint;

- (void)setCallbackAddress:(NSString *)address;

- (void)asyncPutImage:(NSString *)objectKey
        localFilePath:(NSString *)filePath;

- (void)asyncGetImage:(NSString *)objectKey;

- (void)normalRequestCancel;

- (void)triggerCallback;

- (void)resumeDownloadSample:(BOOL)cancel;

@end

#endif /* OssService_h */

