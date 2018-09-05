//
//  OSSRequest.m
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/22.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "OSSRequest.h"
#import "OSSNetworkingRequestDelegate.h"

@interface OSSRequest ()

@property (nonatomic, strong) OSSNetworkingRequestDelegate *requestDelegate;

@end


@implementation OSSRequest

- (instancetype)init {
    if (self = [super init]) {
        self.requestDelegate = [OSSNetworkingRequestDelegate new];
        self.isAuthenticationRequired = YES;
    }
    return self;
}

- (void)cancel {
    self.isCancelled = YES;
    
    if (self.requestDelegate) {
        [self.requestDelegate cancel];
    }
}

- (NSDictionary *)requestParams {
    return nil;
}

@end
