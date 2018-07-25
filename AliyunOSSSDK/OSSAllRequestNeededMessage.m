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

- (instancetype)initWithEndpoint:(NSString *)endpoint
                      httpMethod:(NSString *)httpMethod
                      bucketName:(NSString *)bucketName
                       objectKey:(NSString *)objectKey
                            type:(NSString *)contentType
                             md5:(NSString *)contentMd5
                           range:(NSString *)range
                            date:(NSString *)date
                    headerParams:(NSMutableDictionary *)headerParams
                          querys:(NSMutableDictionary *)querys {
    
    if (self = [super init]) {
        _endpoint = endpoint;
        _httpMethod = httpMethod;
        _bucketName = bucketName;
        _objectKey = objectKey;
        _contentType = contentType;
        _contentMd5 = contentMd5;
        _range = range;
        _date = date;
        _headerParams = headerParams;
        if (!_headerParams) {
            _headerParams = [NSMutableDictionary new];
        }
        _querys = querys;
        if (!_querys) {
            _querys = [NSMutableDictionary new];
        }
    }
    return self;
}

- (instancetype)initWithEndpoint:(NSString *)endpoint
                      httpMethod:(NSString *)httpMethod
                      bucketName:(NSString *)bucketName
                       objectKey:(NSString *)objectKey
                            type:(NSString *)contentType
                             md5:(NSString *)contentMd5
                           range:(NSString *)range
                            date:(NSString *)date
                    headerParams:(NSMutableDictionary *)headerParams
                          querys:(NSMutableDictionary *)querys
                            sha1:(NSString *)contentSHA1
{
    if (self = [super init])
    {
        _endpoint = endpoint;
        _httpMethod = httpMethod;
        _bucketName = bucketName;
        _objectKey = objectKey;
        _contentType = contentType;
        _contentMd5 = contentMd5;
        _range = range;
        _date = date;
        _contentSHA1 = contentSHA1;
        _headerParams = headerParams;
        if (!_headerParams) {
            _headerParams = [NSMutableDictionary new];
        }
        _querys = querys;
        if (!_querys) {
            _querys = [NSMutableDictionary new];
        }
    }
    return self;
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

- (NSString *)description
{
    return [NSString stringWithFormat:@"<OSSAllRequestNeededMessage: %p>{endpoint: %@\nhttpMethod: %@\nbucketName: %@\nobjectKey: %@\ncontentType: %@\ncontentMd5: %@\nrange: %@\ndate: %@\nheaderParams: %@\nquerys: %@\ncontentSHA1: %@\nisHostInCnameExcludeList: %d\n}",self, _endpoint, _httpMethod, _bucketName, _objectKey, _contentType, _contentMd5, _range, _date, _headerParams, _querys, _contentSHA1, _isHostInCnameExcludeList];
}

@end
