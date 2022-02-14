//
//  OSSTestModel.h
//  AliyunOSSiOSTests
//
//  Created by ws on 2022/2/11.
//  Copyright © 2022 aliyun. All rights reserved.
//

#import <AliyunOSSiOS/AliyunOSSiOS.h>

NS_ASSUME_NONNULL_BEGIN

@interface OSSGetObjectResult : OSSResult

/**
 The in-memory content of the downloaded object, if the local file path is not specified.
 */
@property (nonatomic, strong) NSData * downloadedData;

/**
 The object metadata dictionary
 */
@property (nonatomic, copy) NSDictionary * objectMeta;
@end

@interface OSSHeadObjectResult : OSSResult

/**
 Object metadata
 */
@property (nonatomic, copy) NSDictionary * objectMeta;
@end


NS_ASSUME_NONNULL_END
