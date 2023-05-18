//
//  GetObjectTaggingResult.h
//  AliyunOSSSDK
//
//  Created by ws on 2021/5/25.
//  Copyright © 2021 aliyun. All rights reserved.
//

#import "OSSResult.h"

NS_ASSUME_NONNULL_BEGIN

@interface OSSGetObjectTaggingResult : OSSResult

@property (nonatomic, strong) NSDictionary *tags;

@end

NS_ASSUME_NONNULL_END
