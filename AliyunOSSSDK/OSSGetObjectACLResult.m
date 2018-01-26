//
//  OSSGetObjectACLResult.m
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/26.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "OSSGetObjectACLResult.h"

@implementation OSSGetObjectACLResult

- (NSString *)description
{
  return [NSString stringWithFormat:@"<OSSGetObjectACLResult: %p>: {\n\tcode: %zd;\n\tgrant:%@ \n}", self, self.httpResponseCode, _grant];
}

@end
