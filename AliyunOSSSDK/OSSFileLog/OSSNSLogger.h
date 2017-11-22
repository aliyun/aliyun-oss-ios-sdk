//
//  OSSNSLogger.h
//  AliyunOSSiOS
//
//  Created by jingdan on 2017/10/24.
//  Copyright © 2017年 zhouzhuo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSDDLog.h"

@interface OSSNSLogger : OSSDDAbstractLogger <OSSDDLogger>
@property (class, readonly, strong) OSSNSLogger *sharedInstance;
@end
