//
//  OSSDeleteMultipleObjectsRequest.m
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/26.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "OSSDeleteMultipleObjectsRequest.h"

@implementation OSSDeleteMultipleObjectsRequest

- (instancetype)init
{
    self = [super init];
    if (self) {
        _quiet = YES;
    }
    return self;
}

@end
