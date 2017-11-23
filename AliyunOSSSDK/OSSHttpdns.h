//
//  OSSHttpdns.h
//  AliyunOSSiOS
//
//  Created by zhouzhuo on 5/1/16.
//  Copyright © 2016 zhouzhuo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OSSHttpdns : NSObject

+ (instancetype)sharedInstance;

- (NSString *)asynGetIpByHost:(NSString *)host;
@end
