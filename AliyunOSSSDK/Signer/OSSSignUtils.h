//
//  SignUtils.h
//  AliyunOSSSDK
//
//  Created by ws on 2023/12/26.
//  Copyright © 2023 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>


@class OSSAllRequestNeededMessage;

NS_ASSUME_NONNULL_BEGIN

@interface OSSSignUtils : NSObject

+ (NSString *)composeRequestAuthorization:(NSString *)accessKeyId
                                signature:(NSString *)signature;

+ (NSString *)buildCanonicalString:(NSString *)method
                      resourcePath:(NSString *)resourcePath
                           request:(OSSAllRequestNeededMessage *)request
                           expires:(nullable NSString *)expires;

+ (NSString *)buildCanonicalizedResource:(NSString *)resourcePath
                              parameters:(NSDictionary *)parameters;

+ (NSString *)buildSignature:(NSString *)secretAccessKey
                  httpMethod:(NSString *)httpMethod
                resourcePath:(NSString *)resourcePath
                     request:(OSSAllRequestNeededMessage *)request;

@end

NS_ASSUME_NONNULL_END
