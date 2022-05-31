//
//  OSSListObjectsV2Result.h
//  AliyunOSSSDK
//
//  Created by ws on 2022/5/26.
//  Copyright © 2022 aliyun. All rights reserved.
//

#import "OSSResult.h"

NS_ASSUME_NONNULL_BEGIN

@interface OSSGetBucketV2Result : OSSResult

/// A list of summary information describing the objects stored in the bucket
@property (nonatomic, copy, nullable) NSArray *contents;

/// A list of the common prefixes included in this object listing - common prefixes will only be populated for requests that specified a delimiter
@property (nonatomic, copy) NSArray<NSString *> *commonPrefixes;

/// The name of the bucket
@property (nonatomic, copy) NSString *bucketName;

/// KeyCount is the number of keys returned with this response
@property (nonatomic) NSInteger keyCount;

/// Optional parameter which allows list to be continued from a specific point. ContinuationToken is provided in truncated list results.
@property (nonatomic, copy) NSString *continuationToken;

/// NextContinuationToken is sent when isTruncated is true meaning there are more keys in the bucket that can be listed.
@property (nonatomic, copy) NSString *nextContinuationToken;

/// Optional parameter indicating where you want OSS to start the object listing from.  This can be any key in the bucket.
@property (nonatomic, copy) NSString *startAfter;

/// Indicates if this is a complete listing, or if the caller needs to make additional requests to OSS to see the full object listing.
@property (nonatomic) BOOL isTruncated;

/// The prefix parameter originally specified by the caller when this object listing was returned
@property (nonatomic, copy) NSString *prefix;

/// The maxKeys parameter originally specified by the caller when this object listing was returned
@property (nonatomic) NSInteger maxKeys;

/// The delimiter parameter originally specified by the caller when this object listing was returned
@property (nonatomic, copy) NSString *delimiter;

/// The encodingType parameter originally specified by the caller when this object listing was returned.
@property (nonatomic, copy) NSString *encodingType;

@end

NS_ASSUME_NONNULL_END
