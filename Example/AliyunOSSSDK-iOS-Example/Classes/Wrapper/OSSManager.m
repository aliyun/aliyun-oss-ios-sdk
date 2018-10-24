//
//  OSSManager.m
//  AliyunOSSSDK-iOS-Example
//
//  Created by huaixu on 2018/10/23.
//  Copyright © 2018 aliyun. All rights reserved.
//

#import "OSSManager.h"

@implementation OSSManager

+ (instancetype)sharedManager {
    static OSSManager *_manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manager = [[OSSManager alloc] init];
    });
    
    return _manager;
}

@end
