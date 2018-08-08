//
//  OSSPutSymlinkRequest.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/8/1.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "OSSRequest.h"

@interface OSSPutSymlinkRequest : OSSRequest

/* bucket name */
@property (nonatomic, copy) NSString *bucketName;

/* object name */
@property (nonatomic, copy) NSString *objectKey;

/* target object name */
@property (nonatomic, copy) NSString *targetObjectName;

/* meta info in request header fields */
@property (nonatomic, copy) NSDictionary *objectMeta;

@end
