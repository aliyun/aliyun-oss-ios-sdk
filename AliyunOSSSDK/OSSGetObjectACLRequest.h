//
//  OSSGetObjectACLRequest.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/26.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "OSSRequest.h"

NS_ASSUME_NONNULL_BEGIN
@interface OSSGetObjectACLRequest : OSSRequest

/**
 the bucket's name which object stored
 */
@property (nonatomic, copy) NSString *bucketName;

/**
 the name of object
 */
@property (nonatomic, copy) NSString *objectName;


@end
NS_ASSUME_NONNULL_END
