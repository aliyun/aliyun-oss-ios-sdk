//
//  OSSSignerBase.h
//  AliyunOSSSDK iOS
//
//  Created by ws on 2023/12/26.
//  Copyright © 2023 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSConstants.h"

@class OSSAllRequestNeededMessage;
@class OSSSignerParams;
@class OSSConstants;
@class OSSFederationToken;
@class OSSTask;

NS_ASSUME_NONNULL_BEGIN

@protocol OSSRequestSigner <NSObject>

- (OSSTask *)sign:(OSSAllRequestNeededMessage *)requestMessage;

@end

@protocol OSSRequestPresigner <NSObject>

- (OSSTask *)presign:(OSSAllRequestNeededMessage *)requestMessage;

@end

@interface OSSSignerBase : NSObject<OSSRequestSigner, OSSRequestPresigner>

@property (nonatomic, strong) OSSSignerParams *signerParams;

- (instancetype)initWithSignerParams:(OSSSignerParams *)signerParams;

- (void)addAuthorizationHeader:(OSSAllRequestNeededMessage *)request
               federationToken:(OSSFederationToken *)federationToken;

- (void)addDateHeaderIfNeeded:(OSSAllRequestNeededMessage *)request;

- (void)addSecurityTokenHeaderIfNeeded:(OSSAllRequestNeededMessage *)request
                       federationToken:(OSSFederationToken *)federationToken;

+ (id<OSSRequestSigner>)createRequestSignerWithSignerVersion:(OSSSignVersion)signerVersion
                                                signerParams:(OSSSignerParams *)signerParams;

+ (id<OSSRequestPresigner>)createRequestPresignerWithSignerVersion:(OSSSignVersion)signerVersion
                                                      signerParams:(OSSSignerParams *)signerParams;

@end

NS_ASSUME_NONNULL_END
