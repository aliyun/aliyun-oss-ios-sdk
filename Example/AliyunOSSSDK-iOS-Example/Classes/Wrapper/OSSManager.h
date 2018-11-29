//
//  OSSManager.h
//  AliyunOSSSDK-iOS-Example
//
//  Created by huaixu on 2018/10/23.
//  Copyright © 2018 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>

NS_ASSUME_NONNULL_BEGIN

@interface OSSManager : NSObject

@property (nonatomic, strong) OSSClient *defaultClient;

@property (nonatomic, strong) OSSClient *imageClient;

+ (instancetype)sharedManager;

@end

NS_ASSUME_NONNULL_END
