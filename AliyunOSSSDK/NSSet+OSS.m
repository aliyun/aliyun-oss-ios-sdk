//
//  NSSet+OSS.m
//  AliyunOSSSDK
//
//  Created by ws on 2023/12/28.
//  Copyright © 2023 aliyun. All rights reserved.
//

#import "NSSet+OSS.h"

@implementation NSSet (OSS)

- (NSString *)componentsJoinedByString:(NSString *)separator {
    NSMutableString *builder = [NSMutableString new];
    int i = 0;
    
    for (NSObject *part in self) {
        if ([part isKindOfClass:[NSString class]]) {
            [builder appendString:(NSString *)part];
            if (i < [self count] - 1) {
                [builder appendString:separator];
            }
        }
        i++;
    }
    
    return builder;
}

@end
