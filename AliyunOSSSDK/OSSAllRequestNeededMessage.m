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

static NSString * const kOSSInvalidBucketNameMessage = @"The bucket name is invalid. \nA bucket name must: \n1) be comprised of lower-case characters, numbers or dash(-); \n2) start with lower case or numbers; \n3) be between 3-63 characters long.";

static NSString * const kOSSInvalidObjectNameMessage = @"The object key is invalid. \nAn object name should be: \n1) between 1 - 1023 bytes long when encoded as UTF-8 \n2) cannot contain LF or CR or unsupported chars in XML1.0, \n3) cannot begin with \'/\' or \'\\\'.";

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
    
    // 1.check for endpoint
    if (!self.endpoint) {
        errorMessage = @"Endpoint should not be nil";
    }
    
    // 2.check for bucket and object
    if (operType != OSSOperationTypeGetService) {
        if (![_bucketName oss_isNotEmpty]
            || ![OSSUtil validateBucketName:_bucketName]) {
            errorMessage = kOSSInvalidBucketNameMessage;
        }
        if (![self operationBelongsToBucket:operType]) {
            if (![_objectKey oss_isNotEmpty]
                || ![OSSUtil validateObjectKey:_objectKey]) {
                errorMessage = kOSSInvalidObjectNameMessage;
            }
        }
    }
    
    if (errorMessage) {
        return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                          code:OSSClientErrorCodeInvalidArgument
                                                      userInfo:@{OSSErrorMessageTOKEN: errorMessage}]];
    } else {
        return [OSSTask taskWithResult:nil];
    }
}

- (BOOL)operationBelongsToBucket:(OSSOperationType)type {
    BOOL belongsToBucket = NO;
    switch (type) {
        case OSSOperationTypeGetService:
        case OSSOperationTypeCreateBucket:
        case OSSOperationTypeDeleteBucket:
        case OSSOperationTypeGetBucket:
        case OSSOperationTypeGetBucketInfo:
        case OSSOperationTypeGetBucketACL:
        case OSSOperationTypePutBucketACL:
        case OSSOperationTypePutBucketLogging:
        case OSSOperationTypeGetBucketLogging:
        case OSSOperationTypeDeleteBucketLogging:
            belongsToBucket = YES;
            break;
        default:
            break;
    }
    
    return belongsToBucket;
}

@end
