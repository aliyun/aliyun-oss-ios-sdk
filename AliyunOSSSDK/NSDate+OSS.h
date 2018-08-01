//
//  NSDate+OSS.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/7/31.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Categories NSDate
 */
@interface NSDate (OSS)
+ (void)oss_setClockSkew:(NSTimeInterval)clockSkew;
+ (NSDate *)oss_dateFromString:(NSString *)string;
+ (NSDate *)oss_clockSkewFixedDate;
- (NSString *)oss_asStringValue;
@end
