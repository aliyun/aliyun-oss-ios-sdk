//
//  OSSDeleteObjectTaggingRequest.m
//  AliyunOSSSDK
//
//  Created by ws on 2021/5/25.
//  Copyright © 2021 aliyun. All rights reserved.
//

#import "OSSDeleteObjectTaggingRequest.h"

@implementation OSSDeleteObjectTaggingRequest

- (NSDictionary *)requestParams {
    return @{@"tagging": @""};
}

@end
