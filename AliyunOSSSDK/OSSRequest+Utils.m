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


@implementation OSSPutBucketLifecycleRequest (Lifecycle)

- (NSData *)xmlBody
{
    NSMutableString *sRetBody = [NSMutableString string];
    [sRetBody appendFormat:@"<?xml version='1.0' encoding='UTF-8'?>\n<LifecycleConfiguration>"];
    
    if (self.rules.count > 0) {
        for (OSSBucketLifecycleRule *rule in self.rules) {
            NSString *s_status = rule.status ? @"Enabled" : @"Disabled";
            NSString *s_expiration = rule.days ? [NSString stringWithFormat:@"<Days>%@</Days>", rule.days] : [NSString stringWithFormat:@"<Date>%@</Date>", rule.expireDate];
            
            [sRetBody appendFormat:@"\n<Rule>\n<ID>%@</ID>\n<Prefix>%@</Prefix>\n<Status>%@</Status>\n<Expiration>\n%@\n</Expiration>", rule.identifier, rule.prefix, s_status, s_expiration];
            
            if (rule.multipartDays || rule.multipartExpireDate) {
                NSString *s_expirationForMultipart = rule.multipartDays ? [NSString stringWithFormat:@"\n<AbortMultipartUpload><Days>%@</Days>\n</AbortMultipartUpload>", rule.multipartDays] : [NSString stringWithFormat:@"\n<AbortMultipartUpload><Date>%@</Date>\n</AbortMultipartUpload>", rule.multipartExpireDate];
                [sRetBody appendString:s_expirationForMultipart];
            }
            
            if (rule.iaDays || rule.iaExpireDate) {
                NSString *s_expirationForMultipart = rule.iaDays ? [NSString stringWithFormat:@"\n<Transition>\n<Days>%@</Days>\n<StorageClass>IA</StorageClass>\n</Transition>", rule.iaDays] : [NSString stringWithFormat:@"\n<Transition><Date>%@</Date>\n<StorageClass>IA</<StorageClass>\n</Transition>", rule.iaExpireDate];
                [sRetBody appendString:s_expirationForMultipart];
            } else if (rule.archiveDays || rule.archiveExpireDate) {
                NSString *s_expirationForMultipart = rule.archiveDays ? [NSString stringWithFormat:@"\n<Transition><Days>%@</Days>\n<StorageClass>Archive</<StorageClass>\n</Transition>", rule.archiveDays] : [NSString stringWithFormat:@"\n<Transition><Date>%@</Date>\n<StorageClass>Archive</<StorageClass>\n</Transition>", rule.archiveExpireDate];
                [sRetBody appendString:s_expirationForMultipart];
            }
            
            [sRetBody appendString:@"\n</Rule>"];
        }
        
    }
    [sRetBody appendFormat:@"\n</LifecycleConfiguration>"];
    
    return [sRetBody dataUsingEncoding:NSUTF8StringEncoding];
}

@end
