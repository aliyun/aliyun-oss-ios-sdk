//
//  UIResult.h
//  AliyunOSSSDK-iOS-Example
//
//  Created by jingdan on 2017/12/6.
//  Copyright © 2017年 阿里云. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DataCallback : NSObject
@property (nonatomic, strong) NSData * download;
@property (nonatomic, copy) NSString * showMessage;
@property (nonatomic, copy) NSString * inputMessage;
@property (nonatomic, copy) NSString * objectKey;
@property (nonatomic, assign) int64_t code;
@property (nonatomic, assign) int64_t action;// 上传 0 下载 1
@end
