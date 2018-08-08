//
//  OSSAllRequestNeededMessage.m
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/22.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "OSSAllRequestNeededMessage.h"

#import "OSSDefine.h"
#import "OSSUtil.h"

@implementation OSSAllRequestNeededMessage

- (instancetype)init
{
    self = [super init];
    if (self) {
        _date = [[NSDate oss_clockSkewFixedDate] oss_asStringValue];
        _headerParams = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)setHeaderParams:(NSMutableDictionary *)headerParams {
    if (!headerParams || [headerParams isEqualToDictionary:_headerParams]) {
        return;
    }
    _headerParams = [headerParams mutableCopy];
}

- (OSSTask *)validateRequestParamsInOperationType:(OSSOperationType)operType {
    NSString * errorMessage = nil;
    
    if (!self.endpoint) {
        errorMessage = @"Endpoint should not be nil";
    }
    
    if (!self.bucketName && operType != OSSOperationTypeGetService) {
        errorMessage = @"Bucket name should not be nil";
    }
    
    if (self.bucketName && ![OSSUtil validateBucketName:self.bucketName]) {
        errorMessage = @"Bucket name invalid";
    }
    
    if (!self.objectKey &&
        (operType != OSSOperationTypeGetBucket && operType != OSSOperationTypeCreateBucket
         && operType != OSSOperationTypeDeleteBucket && operType != OSSOperationTypeGetService
         && operType != OSSOperationTypeGetBucketACL&& operType != OSSOperationTypeDeleteMultipleObjects
         && operType != OSSOperationTypeListMultipartUploads
         && operType != OSSOperationTypeGetBucketInfo)) {
            errorMessage = @"Object key should not be nil";
        }
    
    
    
    if (self.objectKey && ![OSSUtil validateObjectKey:self.objectKey]) {
        errorMessage = @"Object key invalid";
    }
    
    if (errorMessage) {
        return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                          code:OSSClientErrorCodeInvalidArgument
                                                      userInfo:@{OSSErrorMessageTOKEN: errorMessage}]];
    } else {
        return [OSSTask taskWithResult:nil];
    }
}

@end
