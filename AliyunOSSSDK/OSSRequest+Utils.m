//
//  OSSRequest+Utils.m
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/11/19.
//  Copyright © 2018 aliyun. All rights reserved.
//

#import "OSSRequest+Utils.h"

@implementation OSSPutBucketACLRequest (ACL)

- (NSString *)acl {
    NSString *rAcl = nil;
    switch (self.aclType) {
        case OSSACLPublicRead:
            rAcl = @"public-read";
            break;
        case OSSACLPublicReadAndWrite:
            rAcl = @"public-read-write";
            break;
            
        default:
            rAcl = @"private";
            break;
    }
    
    return rAcl;
}

@end

@implementation OSSPutBucketLoggingRequest (Logging)

- (NSData *)xmlBody
{
    NSMutableString *sRetBody = [NSMutableString string];
    [sRetBody appendFormat:@"<?xml version='1.0' encoding='UTF-8'?>\n<BucketLoggingStatus>\n<LoggingEnabled>\n<TargetBucket>%@</TargetBucket>\n<TargetPrefix>%@</TargetPrefix>\n</LoggingEnabled>\n</BucketLoggingStatus>", self.targetBucketName, self.targetPrefix];
    return [sRetBody dataUsingEncoding:NSUTF8StringEncoding];
}

@end


@implementation OSSPutBucketRefererRequest (Referer)

- (NSData *)xmlBody
{
    NSString *s_allowEmpty = self.allowEmpty ? @"true" : @"false";
    NSMutableString *sRetBody = [NSMutableString string];
    [sRetBody appendFormat:@"<?xml version='1.0' encoding='UTF-8'?>\n<RefererConfiguration>\n<AllowEmptyReferer>%@</AllowEmptyReferer>", s_allowEmpty];
    
    if (self.referers.count > 0) {
        [sRetBody appendFormat:@"\n<RefererList>"];
        for (NSString *referer in self.referers) {
            [sRetBody appendFormat:@"\n<Referer>%@</Referer>", referer];
        }
        [sRetBody appendFormat:@"\n</RefererList>"];
    }
    [sRetBody appendFormat:@"\n</RefererConfiguration>"];
    
    return [sRetBody dataUsingEncoding:NSUTF8StringEncoding];
}

@end
