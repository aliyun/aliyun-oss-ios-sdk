//
//  OSSRequest+Utils.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/11/19.
//  Copyright © 2018 aliyun. All rights reserved.
//

#import "OSSModel.h"
#import "OSSNetworkingRequestDelegate.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - OSSRequest and its subClasses's category

/**
 * extend OSSRequest to include the ref to networking request object
 */
@interface OSSRequest ()

@property (nonatomic, strong) OSSNetworkingRequestDelegate * requestDelegate;

@end


@interface OSSPutBucketACLRequest (ACL)

@property (nonatomic, copy, readonly) NSString *acl;

@end


@interface OSSPutBucketLoggingRequest (Logging)

@property (nonatomic, copy, readonly) NSData *xmlBody;

@end

@interface OSSPutBucketRefererRequest (Referer)

@property (nonatomic, copy, readonly) NSData *xmlBody;

@end

@interface OSSPutBucketLifecycleRequest (Lifecycle)

@property (nonatomic, copy, readonly) NSData *xmlBody;

@end


NS_ASSUME_NONNULL_END
