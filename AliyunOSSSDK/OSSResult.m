//
//  OSSResult.m
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/26.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "OSSResult.h"

@implementation OSSResult

- (NSString *)description
{
    return [NSString stringWithFormat:@"OSSResult<%p> : {httpResponseCode: %ld, requestId: %@, httpResponseHeaderFields: %@, local_crc64ecma: %@}",self,(long)self.httpResponseCode,self.requestId,self.httpResponseHeaderFields,self.localCRC64ecma];
}

@end
