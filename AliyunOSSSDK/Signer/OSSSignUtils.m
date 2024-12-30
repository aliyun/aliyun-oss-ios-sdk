//
//  SignUtils.m
//  AliyunOSSSDK
//
//  Created by ws on 2023/12/26.
//  Copyright © 2023 aliyun. All rights reserved.
//

#import "OSSSignUtils.h"
#import "OSSDefine.h"
#import "OSSAllRequestNeededMessage.h"
#import "OSSUtil.h"
#import "OSSServiceSignature.h"

@implementation OSSSignUtils

#define NewLine @"\n"

+ (NSString *)composeRequestAuthorization:(NSString *)accessKeyId
                                signature:(NSString *)signature {
    return [NSString stringWithFormat:@"%@%@:%@", OSSAuthorizationPrefix, accessKeyId, signature];
}

+ (NSString *)buildCanonicalString:(NSString *)method
                      resourcePath:(NSString *)resourcePath
                           request:(OSSAllRequestNeededMessage *)request
                           expires:(nullable NSString *)expires {
    NSMutableString *canonicalString = [NSMutableString new];
    [canonicalString appendString:method];
    [canonicalString appendString:NewLine];
    
    NSMutableDictionary<NSString *, NSString *> *headersToSign = @{}.mutableCopy;
    
    if (request.contentType) {
        headersToSign[OSSHttpHeaderContentType.lowercaseString] = request.contentType;
    }
    if (request.contentMd5) {
        headersToSign[OSSHttpHeaderContentMD5.lowercaseString] = request.contentMd5;
    }
    
    [request.headerParams enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *lowerKey = [key lowercaseString];
        if ([lowerKey isEqualToString:OSSHttpHeaderDate.lowercaseString] ||
            [lowerKey hasPrefix:OSSPrefix.lowercaseString]) {
            headersToSign[lowerKey] = [obj oss_trim];
        }
    }];
    
    if (![[headersToSign allKeys] containsObject:OSSHttpHeaderContentType.lowercaseString]) {
        headersToSign[OSSHttpHeaderContentType.lowercaseString] = @"";
    }
    
    if (![[headersToSign allKeys] containsObject:OSSHttpHeaderContentMD5.lowercaseString]) {
        headersToSign[OSSHttpHeaderContentMD5.lowercaseString] = @"";
    }
    
    NSArray * sortedKey = [[headersToSign allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];
    for (NSString * key in sortedKey) {
        if ([key hasPrefix:OSSPrefix]) {
            [canonicalString appendString:key];
            [canonicalString appendString:@":"];
            [canonicalString appendString:headersToSign[key]];
        } else {
            [canonicalString appendString:headersToSign[key]];
        }
        [canonicalString appendString:NewLine];
    }
    
    [canonicalString appendString:[self buildCanonicalizedResource:resourcePath
                                                        parameters:request.params]];
    
    return canonicalString;
}

+ (NSString *)buildCanonicalizedResource:(NSString *)resourcePath
                              parameters:(NSDictionary *)parameters {
    NSAssert([resourcePath hasPrefix:@"/"], @"Resource path should start with slash character");
    
    NSMutableArray * subresource = [NSMutableArray new];
    NSArray *sortKeys = [parameters.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *key in sortKeys) {
        NSString * keyStr = [key oss_trim];
        NSString * valueStr = [parameters[key] oss_trim];
        if ([OSSUtil isSubresource:keyStr]) {
            if ([valueStr length] == 0) {
                [subresource addObject:keyStr];
            } else {
                [subresource addObject:[NSString stringWithFormat:@"%@=%@", keyStr, valueStr]];
            }
        }
    }
    if (subresource.count != 0) {
        resourcePath = [[resourcePath stringByAppendingString:@"?"] stringByAppendingString:[subresource componentsJoinedByString:@"&"]];
    }
    
    return resourcePath;
}

+ (NSString *)buildSignature:(NSString *)secretAccessKey
                  httpMethod:(NSString *)httpMethod
                resourcePath:(NSString *)resourcePath
                     request:(OSSAllRequestNeededMessage *)request {
    NSString *canonicalString = [self buildCanonicalString:httpMethod
                                              resourcePath:resourcePath
                                                   request:request
                                                   expires:nil];
    return [[HmacSHA1Signature new] computeSignature:secretAccessKey
                                                data:canonicalString];
}

@end
