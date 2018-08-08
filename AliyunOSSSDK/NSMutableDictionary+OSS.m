//
//  NSMutableDictionary+OSS.m
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/8/1.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "NSMutableDictionary+OSS.h"

@implementation NSMutableDictionary (OSS)

- (void)oss_setObject:(id)anObject forKey:(id <NSCopying>)aKey {
    if (anObject && aKey) {
        [self setObject:anObject forKey:aKey];
    }
}

@end
