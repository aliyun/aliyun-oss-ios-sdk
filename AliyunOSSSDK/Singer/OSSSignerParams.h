//
//  OSSSignerParams.h
//  AliyunOSSSDK iOS
//
//  Created by ws on 2023/12/26.
//  Copyright © 2023 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface OSSSignerParams : NSObject

@property (nonatomic, copy) NSString *resourcePath;

@property (nonatomic, strong) id<OSSCredentialProvider> credentialProvider;

@property (nonatomic, copy) NSString *product;

@property (nonatomic, copy) NSString *region;

@property (nonatomic, copy) NSString *cloudBoxId;

@property (nonatomic, assign) NSInteger expiration;

@property (nonatomic, strong) NSSet *additionalHeaderNames;

@end

NS_ASSUME_NONNULL_END
