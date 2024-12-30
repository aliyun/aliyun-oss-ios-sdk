//
//  OSSServiceSignature.h
//  AliyunOSSSDK
//
//  Created by ws on 2023/12/26.
//  Copyright © 2023 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol OSSServiceSignature <NSObject>

@property (nonatomic, copy, readonly) NSString *algorithm;

@property (nonatomic, copy, readonly) NSString *version;

- (NSData *)computeHash:(NSData *)key
                   data:(NSData *)data;

- (NSString *)computeSignature:(NSString *)key
                          data:(NSString *)data;

@end

@interface HmacSHA1Signature : NSObject<OSSServiceSignature>

@end

@interface HmacSHA256Signature : NSObject<OSSServiceSignature>

@end

NS_ASSUME_NONNULL_END
