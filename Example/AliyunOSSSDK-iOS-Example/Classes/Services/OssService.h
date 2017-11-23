//
//  OssService.h
//  OssIOSDemo
//
//  Created by 凌琨 on 15/12/15.
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

@end

#endif /* OssService_h */

