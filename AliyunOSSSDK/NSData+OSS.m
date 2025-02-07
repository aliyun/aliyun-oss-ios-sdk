//
//  NSData+OSS.m
//  AliyunOSSSDK
//
//  Created by ws on 2023/12/28.
//  Copyright © 2023 aliyun. All rights reserved.
//

#import "NSData+OSS.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSData (OSS)

- (NSString *)oss_hexString {
    NSMutableString *hexString = [NSMutableString string];
    Byte *byte = (Byte *)[self bytes];
    for (int i = 0; i<[self length]; i++) {
        [hexString appendFormat:@"%x", (*(byte + i) >> 4) & 0xf];
        [hexString appendFormat:@"%x", *(byte + i) & 0xf];
    }
    return hexString;
}

- (NSData *)oss_calculateSha256 {
    unsigned char *digest = NULL;
    
    digest = malloc(CC_SHA256_DIGEST_LENGTH * sizeof(unsigned char));
    memset(digest, 0x0, CC_SHA256_DIGEST_LENGTH);
    CC_SHA256(self.bytes, (CC_LONG)self.length, digest);
    
    if (digest) {
        NSData *data = [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
        free(digest);
        return data;
    }
    free(digest);
    
    return nil;
}

@end
