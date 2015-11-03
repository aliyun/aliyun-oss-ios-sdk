//
//  OSSUtil.m
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import "OSSUtil.h"
#import <mach/mach.h>
#import "CommonCrypto/CommonDigest.h"
#import "CommonCrypto/CommonHMAC.h"
#import "OSSModel.h"
#import "OSSLog.h"
#import "OSSHTTPDNSMini.h"

NSString * const ALIYUN_HOST_SUFFIX = @".aliyuncs.com";
NSString * const ALIYUN_OSS_TEST_ENDPOINT = @".aliyun-inc.com";
int32_t const CHUNK_SIZE = 8 * 1024;

@implementation OSSUtil

+ (NSString *)calBase64Sha1WithData:(NSString *)data withSecret:(NSString *)key {
    NSData *secretData = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSData *clearTextData = [data dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t input[20];
    CCHmac(kCCHmacAlgSHA1, [secretData bytes], [secretData length], [clearTextData bytes], [clearTextData length], input);
    
    return [self calBase64WithData:input];
}

+ (NSString*)calBase64WithData:(uint8_t *)data {
    static char b[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    NSInteger a = 20;
    NSMutableData* c = [NSMutableData dataWithLength:((a + 2) / 3) * 4];
    uint8_t* d = (uint8_t*)c.mutableBytes;
    NSInteger i;
    for (i=0; i < a; i += 3) {
        NSInteger e = 0;
        NSInteger j;
        for (j = i; j < (i + 3); j++) {
            e <<= 8;
            if (j < a) {
                e |= (0xFF & data[j]);
            }
        }
        NSInteger index = (i / 3) * 4;
        d[index + 0] = b[(e >> 18) & 0x3F];
        d[index + 1] = b[(e >> 12) & 0x3F];
        if ((i + 1) < a) {
            d[index + 2] = b[(e >> 6) & 0x3F];
        } else {
            d[index + 2] = '=';
        }
        if ((i + 2) < a) {
            d[index + 3] = b[(e >> 0) & 0x3F];
        } else {
            d[index + 3] = '=';
        }
    }
    NSString *result = [[NSString alloc] initWithData:c encoding:NSASCIIStringEncoding];
    return result;
}

+ (NSString *)encodeURL:(NSString *)url {
    NSMutableString *output = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[url UTF8String];
    NSUInteger sourceLen = strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' ') {
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
                   (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [output appendFormat:@"%c", thisChar];
        } else {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}

+ (NSData *)constructHttpBodyFromPartInfos:(NSArray *)partInfos {
    NSMutableString * body = [NSMutableString stringWithString:@"<CompleteMultipartUpload>\n"];
    [partInfos enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[OSSPartInfo class]]) {
            OSSPartInfo * thePart = obj;
            [body appendFormat:@"<Part>\n<PartNumber>%d</PartNumber>\n<ETag>%@</ETag>\n</Part>\n", thePart.partNum, thePart.eTag];
        }
    }];
    [body appendString:@"</CompleteMultipartUpload>\n"];
    OSSLogVerbose(@"constucted complete multipart upload body:\n%@", body);
    return [body dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSData *)constructHttpBodyForCreateBucketWithLocation:(NSString *)location {
    NSString * body = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                              @"<CreateBucketConfiguration>\n"
                              @"<LocationConstraint>%@</LocationConstraint>\n"
                              @"</CreateBucketConfiguration>\n",
                       location];
    OSSLogVerbose(@"constucted create bucket body:\n%@", body);
    return [body dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSString *)getIpByHost:(NSString *)host {
    if ([self isNetworkDelegateState]) {
        OSSLogDebug(@"current network is delegate state");
        return host;
    }
    NSString * ip = [[OSSHTTPDNSMini sharedInstanceManage] getIpByHostAsync:host];
    OSSLogDebug(@"resolved host %@ and get ip: %@", host, ip);

    return ip ? ip : host;
}

+ (BOOL)isNetworkDelegateState
{
    NSURL* URL = [[NSURL alloc] initWithString:@"http://www.taobao.com"];
    NSDictionary *proxySettings = CFBridgingRelease(CFNetworkCopySystemProxySettings());
    NSArray *proxies = nil;
    proxies = CFBridgingRelease(CFNetworkCopyProxiesForURL((__bridge CFURLRef)URL,
                                                           (__bridge CFDictionaryRef)proxySettings));
    if (proxies.count)
    {
        NSDictionary *settings = [proxies objectAtIndex:0];
        NSString* host = [settings objectForKey:(NSString *)kCFProxyHostNameKey];
        NSNumber* port = [settings objectForKey:(NSString *)kCFProxyPortNumberKey];
        if (host && port)
        {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)isOssOriginBucketHost:(NSString *)host {
    return [[host lowercaseString] hasSuffix:ALIYUN_HOST_SUFFIX] || [[host lowercaseString] hasSuffix:ALIYUN_OSS_TEST_ENDPOINT];
}

+ (NSString *)base64Md5ForData:(NSData *)data {
    return [self base64ForData:[self dataMD5:data] length:CC_MD5_DIGEST_LENGTH];
}

+ (NSString *)base64Md5ForFilePath:(NSString *)filePath {
    return [self base64ForData:[self fileMD5:filePath] length:CC_MD5_DIGEST_LENGTH];
}

+ (NSString *)base64Md5ForFileURL:(NSURL *)fileURL {
    return [self base64Md5ForFilePath:[fileURL path]];
}

+ (unsigned char *)dataMD5:(NSData *)data {
    if(data == nil) {
        return nil;
    }
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    for (int i = 0; i < data.length; i += CHUNK_SIZE) {
        NSData *subdata = nil;
        if (i <= ((long)data.length - CHUNK_SIZE)) {
            subdata = [data subdataWithRange:NSMakeRange(i, CHUNK_SIZE)];
            CC_MD5_Update(&md5, [subdata bytes], (CC_LONG)[subdata length]);
        } else {
            subdata = [data subdataWithRange:NSMakeRange(i, data.length - i)];
            CC_MD5_Update(&md5, [subdata bytes], (CC_LONG)[subdata length]);
        }
    }
    unsigned char * digestResult = (unsigned char *)malloc(CC_MD5_DIGEST_LENGTH * sizeof(unsigned char));
    CC_MD5_Final(digestResult, &md5);
    return digestResult;
}

+ (unsigned char *)fileMD5:(NSString*)path {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if(handle == nil) {
        return nil;
    }
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    BOOL done = NO;
    while(!done) {
        NSData* fileData = [handle readDataOfLength: CHUNK_SIZE];
        CC_MD5_Update(&md5, [fileData bytes], (CC_LONG)[fileData length]);
        if([fileData length] == 0) {
            done = YES;
        }
    }
    unsigned char * digestResult = (unsigned char *)malloc(CC_MD5_DIGEST_LENGTH * sizeof(unsigned char));
    CC_MD5_Final(digestResult, &md5);
    return digestResult;
}

+ (NSString *)convertMd5Bytes2String:(unsigned char *)md5Bytes {
    return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            md5Bytes[0], md5Bytes[1], md5Bytes[2], md5Bytes[3],
            md5Bytes[4], md5Bytes[5], md5Bytes[6], md5Bytes[7],
            md5Bytes[8], md5Bytes[9], md5Bytes[10], md5Bytes[11],
            md5Bytes[12], md5Bytes[13], md5Bytes[14], md5Bytes[15]
            ];
}

+ (NSString *)dataMD5String:(NSData *)data {
    return [self convertMd5Bytes2String:[self dataMD5:data]];
}

+ (NSString *)fileMD5String:(NSString *)path {
    return [self convertMd5Bytes2String:[self fileMD5:path]];
}

+ (NSString*)base64ForData:(uint8_t *)input length:(int32_t)length {
    if (input == nil) {
        return nil;
    }
    NSData * data = [NSData dataWithBytes:input length:length];
    return [data base64EncodedStringWithOptions:0];
}

+ (NSString *)getRelativePath:(NSString *)fullPath {
    NSString * userName = NSUserName();
    NSString * rootPath = NSHomeDirectoryForUser(userName);
    return [fullPath stringByReplacingOccurrencesOfString:rootPath withString:@""];
}

@end