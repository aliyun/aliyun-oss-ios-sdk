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
+ (void) putTestDataWithKey: (NSString *)key withClient: (OSSClient *)client withBucket: (NSString *)bucket;
+ (OSSTask *) getObjectWithKey: (NSString *)key withClient: (OSSClient *)client withBucket: (NSString *)bucket fileUrl:(NSURL *)url;
+ (OSSTask *) headObjectWithKey: (NSString *)key withClient: (OSSClient *)client withBucket: (NSString *)bucket;
+ (OSSFederationToken *)getSts;

@end
