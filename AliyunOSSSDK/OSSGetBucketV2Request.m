//
//  OSSListObjectsV2Request.m
//  AliyunOSSSDK
//
//  Created by ws on 2022/5/26.
//  Copyright © 2022 aliyun. All rights reserved.
//

#import "OSSGetBucketV2Request.h"
#import "NSMutableDictionary+OSS.h"
#import "OSSDefine.h"

@implementation OSSGetBucketV2Request

- (instancetype)init {
    self = [super init];
    if (self) {
        self.maxKeys = 100;
        self.fetchOwner = NO;
    }
    return self;
}

- (NSDictionary *)requestParams {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"2" forKey:OSSSubResourceListType];
    [params oss_setObject:self.delimiter forKey:OSSSubResourceDelimiter];
    [params oss_setObject:self.startAfter forKey:OSSSubResourceStartAfter];
    [params oss_setObject:self.continuationToken forKey:OSSSubResourceContinuationToken];
    [params oss_setObject:[@(self.maxKeys) stringValue] forKey:OSSSubResourceMaxKeys];
    [params oss_setObject:self.prefix forKey:OSSSubResourcePrefix];
    [params oss_setObject:self.encodingType forKey:OSSSubResourceEncodingType];
    NSString *fetchOwner = self.fetchOwner ? @"true": @"false";
    [params oss_setObject:fetchOwner forKey:OSSSubResourceFetchOwner];
    return [params copy];
}

@end
