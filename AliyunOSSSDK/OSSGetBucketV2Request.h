//
//  OSSListObjectsV2Request.h
//  AliyunOSSSDK
//
//  Created by ws on 2022/5/26.
//  Copyright © 2022 aliyun. All rights reserved.
//

#import "OSSRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface OSSGetBucketV2Request : OSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString *bucketName;

/// Optional parameter indicating the encoding method to be applied on the
/// response. An object key can contain any Unicode character; however, XML
/// 1.0 parser cannot parse some characters, such as characters with an ASCII
/// value from 0 to 10. you can add this parameter to request that OSS encode the keys in the
/// response.
@property (nonatomic, copy) NSString *delimiter;

/// Optional parameter indicating the maximum number of keys to include in the response.
@property (nonatomic, copy) NSString *encodingType;

/// Optional parameter restricting the response to keys which begin with the specified prefix.
@property (nonatomic) NSInteger maxKeys;

/// Optional parameter restricting the response to keys which begin with the specified prefix.
@property (nonatomic, copy) NSString *prefix;

/// Optional parameter which allows list to be continued from a specific point.
/// ContinuationToken is provided in truncated list results.
@property (nonatomic, copy) NSString *continuationToken;

/// The owner field is not present in ListObjectsV2 results by default. If this flag is set to true the owner field will be returned.
@property (nonatomic) BOOL fetchOwner;

/// Optional parameter indicating where you want OSS to start the object listing from.
@property (nonatomic, copy) NSString *startAfter;

@end

NS_ASSUME_NONNULL_END
