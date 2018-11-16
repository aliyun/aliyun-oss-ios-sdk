//
//  OSSPutBucketACLRequest.m
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/11/16.
//  Copyright © 2018 aliyun. All rights reserved.
//

#import "OSSPutBucketACLRequest.h"

@implementation OSSPutBucketACLRequest

- (instancetype)init
{
    self = [super init];
    if (self) {
        _aclType = OSSBucketACLPrivate;
    }
    return self;
}

@end
