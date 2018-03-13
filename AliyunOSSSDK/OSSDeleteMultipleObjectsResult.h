//
//  OSSDeleteMultipleObjectsResult.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/26.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "OSSResult.h"

@interface OSSDeleteMultipleObjectsResult : OSSResult

@property (nonatomic, copy) NSArray<NSString *> *deletedObjects;

@property (nonatomic, copy) NSString *encodingType;

@end
