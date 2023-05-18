//
//  OSSDeleteObjectTaggingRequest.h
//  AliyunOSSSDK
//
//  Created by ws on 2021/5/25.
//  Copyright © 2021 aliyun. All rights reserved.
//

#import "OSSRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface OSSDeleteObjectTaggingRequest : OSSRequest

/* bucket name */
@property (nonatomic, copy) NSString *bucketName;

/* object name */
@property (nonatomic, copy) NSString *objectKey;

@end

NS_ASSUME_NONNULL_END
