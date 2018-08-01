//
//  NSMutableDictionary+OSS.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/8/1.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableDictionary (OSS)

- (void)oss_setObject:(id)anObject forKey:(id <NSCopying>)aKey;

@end
