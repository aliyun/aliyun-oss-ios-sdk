//
//  OSSServiceSignature.m
//  AliyunOSSSDK
//
//  Created by ws on 2023/12/26.
//  Copyright © 2023 aliyun. All rights reserved.
//

#import "OSSServiceSignature.h"
#import <CommonCrypto/CommonHMAC.h>
#import "OSSUtil.h"

#define Version @"1"
#define AlgorithmSHA1 @"HmacSHA1"
#define AlgorithmSHA256 @"HmacSHA256"

@interface HmacSHA1Signature()

@end

@implementation HmacSHA1Signature

- (NSString *)algorithm {
    return AlgorithmSHA1;
}

- (NSString *)version {
    return Version;
}

- (NSData *)computeHash:(NSData *)key
                   data:(NSData *)data {
    return [self sign:key data:data];
}

- (NSString *)computeSignature:(NSString *)key
                          data:(NSString *)data {
    NSData *secretData = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSData *clearTextData = [data dataUsingEncoding:NSUTF8StringEncoding];
    NSData *signData = [self sign:secretData data:clearTextData];
    return [OSSUtil calBase64WithData:(UTF8Char*)signData.bytes];
}

- (NSData *)sign:(NSData *)key
            data:(NSData *)data {
    uint8_t input[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, [key bytes], [key length], [data bytes], [data length], input);
    return [NSData dataWithBytes:input length:CC_SHA1_DIGEST_LENGTH];
}

@end

@interface HmacSHA256Signature()

@end

@implementation HmacSHA256Signature

//static NSString *Algorithm = @"HmacSHA256";

- (NSString *)algorithm {
    return AlgorithmSHA256;
}

- (NSString *)version {
    return Version;
}

- (NSData *)computeHash:(NSData *)key
                   data:(NSData *)data {
    return [self sign:key data:data];
}

- (NSString *)computeSignature:(NSString *)key
                          data:(NSString *)data {
    NSData *secretData = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSData *clearTextData = [data dataUsingEncoding:NSUTF8StringEncoding];
    NSData *signData = [self sign:secretData data:clearTextData];
    return [OSSUtil calBase64WithData:(UTF8Char*)signData.bytes];
}

- (NSData *)sign:(NSData *)key
            data:(NSData *)data {
    uint8_t input[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, [key bytes], [key length], [data bytes], [data length], input);
    return [NSData dataWithBytes:input length:CC_SHA256_DIGEST_LENGTH];
}

@end
