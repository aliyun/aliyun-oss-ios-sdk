//
//  OSSPutBucketACLRequest.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/11/16.
//  Copyright © 2018 aliyun. All rights reserved.
//

#import <AliyunOSSiOS/AliyunOSSiOS.h>

typedef NS_ENUM(NSUInteger, OSSBucketACLType){
    OSSBucketACLPrivate,                // private
    OSSBucketACLPublicRead,             // public-read
    OSSBucketACLPublicReadAndWrite      // public-read-write
};

NS_ASSUME_NONNULL_BEGIN

@interface OSSPutBucketACLRequest : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 acl type of bucket,default value is OSSBucketACLPrivate
 */
@property (nonatomic, assign) OSSBucketACLType aclType;

@end

NS_ASSUME_NONNULL_END
