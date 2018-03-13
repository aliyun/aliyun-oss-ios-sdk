//
//  OSSGetObjectACLResult.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/26.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "OSSResult.h"

@interface OSSGetObjectACLResult : OSSResult

/**
 the ACL of object,valid values: @"private",@"public-read",@"public-read-write".
 if object's ACL inherit from bucket,it will return @"default".
 */
@property (nonatomic, copy) NSString *grant;

@end
