//
//  OSSAllRequestNeededMessage.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/22.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSConstants.h"
#import "OSSTask.h"

/**
 All necessary information in one OSS request.
 */
@interface OSSAllRequestNeededMessage : NSObject
@property (nonatomic, strong) NSString *endpoint;
@property (nonatomic, strong) NSString *httpMethod;
@property (nonatomic, strong) NSString *bucketName;
@property (nonatomic, strong) NSString *objectKey;
@property (nonatomic, strong) NSString *contentType;
@property (nonatomic, strong) NSString *contentMd5;
@property (nonatomic, strong) NSString *range;
@property (nonatomic, strong) NSString *date;
@property (nonatomic, strong) NSMutableDictionary *headerParams;
@property (nonatomic, copy) NSDictionary *params;
@property (nonatomic, copy) NSString *contentSHA1;
@property (nonatomic, assign) BOOL isHostInCnameExcludeList;


- (OSSTask *)validateRequestParamsInOperationType:(OSSOperationType)operType;

@end
