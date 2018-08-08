//
//  OSSGetSymlinkRequest.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/8/1.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "OSSRequest.h"

@interface OSSGetSymlinkRequest : OSSRequest

@property (nonatomic, copy) NSString *bucketName;

@property (nonatomic, copy) NSString *objectKey;

@end
