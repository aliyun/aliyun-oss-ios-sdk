//
//  OSSTestUtils.h
//  AliyunOSSiOSTests
//
//  Created by jingdan on 2018/2/24.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>

@interface OSSTestUtils : NSObject
+ (void)cleanBucket: (NSString *)bucket with: (OSSClient *)client;
@end
