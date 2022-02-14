//
//  OSSModel.m
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//
#import "OSSDefine.h"
#import "OSSModel.h"
#import "OSSUtil.h"
#import "OSSNetworking.h"
#import "OSSLog.h"
#import "OSSXMLDictionary.h"
#if TARGET_OS_IOS
#import <UIKit/UIDevice.h>
#endif

#import "OSSAllRequestNeededMessage.h"

@implementation NSDictionary (OSS)

- (NSString *)base64JsonString {
    NSError * error;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:self
                                                        options:0
                                                          error:&error];

    if (!jsonData) {
        return @"e30="; // base64("{}");
    } else {
        NSString * jsonStr = [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
        NSLog(@"callback json - %@", jsonStr);
        return [[jsonStr dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    }
}

@end

@implementation OSSSyncMutableDictionary

- (instancetype)init {
    if (self = [super init]) {
        _dictionary = [NSMutableDictionary dictionary];
        _dispatchQueue = dispatch_queue_create("com.aliyun.aliyunsycmutabledictionary", DISPATCH_QUEUE_SERIAL);
    }

    return self;
}

- (NSArray *)allKeys {
    __block NSArray *allKeys = nil;
    dispatch_sync(self.dispatchQueue, ^{
        allKeys = [self.dictionary allKeys];
    });
    return allKeys;
}

- (id)objectForKey:(id)aKey {
    __block id returnObject = nil;

    dispatch_sync(self.dispatchQueue, ^{
        returnObject = [self.dictionary objectForKey:aKey];
    });

    return returnObject;
}

- (void)setObject:(id)anObject forKey:(id <NSCopying>)aKey {
    dispatch_sync(self.dispatchQueue, ^{
        [self.dictionary oss_setObject:anObject forKey:aKey];
    });
}

- (void)removeObjectForKey:(id)aKey {
    dispatch_sync(self.dispatchQueue, ^{
        [self.dictionary removeObjectForKey:aKey];
    });
}

@end

@implementation OSSFederationToken

- (NSString *)description
{
    return [NSString stringWithFormat:@"OSSFederationToken<%p>:{AccessKeyId: %@\nAccessKeySecret: %@\nSecurityToken: %@\nExpiration: %@}", self, _tAccessKey, _tSecretKey, _tToken, _expirationTimeInGMTFormat];
}

@end

@implementation OSSStsTokenCredentialProvider

- (OSSFederationToken *)getToken {
    OSSFederationToken * token = [OSSFederationToken new];
    token.tAccessKey = self.accessKeyId;
    token.tSecretKey = self.secretKeyId;
    token.tToken = self.securityToken;
    token.expirationTimeInMilliSecond = NSIntegerMax;
    return token;
}

- (instancetype)initWithAccessKeyId:(NSString *)accessKeyId secretKeyId:(NSString *)secretKeyId securityToken:(NSString *)securityToken {
    if (self = [super init]) {
        self.accessKeyId = [accessKeyId oss_trim];
        self.secretKeyId = [secretKeyId oss_trim];
        self.securityToken = [securityToken oss_trim];
    }
    return self;
}

- (NSString *)sign:(NSString *)content error:(NSError **)error {
    NSString * sign = [OSSUtil calBase64Sha1WithData:content withSecret:self.secretKeyId];
    return [NSString stringWithFormat:@"OSS %@:%@", self.accessKeyId, sign];
}

@end

NSString * const BACKGROUND_SESSION_IDENTIFIER = @"com.aliyun.oss.backgroundsession";

@implementation OSSClientConfiguration

- (instancetype)init {
    if (self = [super init]) {
        self.maxRetryCount = OSSDefaultRetryCount;
        self.maxConcurrentRequestCount = OSSDefaultMaxConcurrentNum;
        self.enableBackgroundTransmitService = NO;
        self.backgroundSesseionIdentifier = BACKGROUND_SESSION_IDENTIFIER;
        self.timeoutIntervalForRequest = OSSDefaultTimeoutForRequestInSecond;
        self.timeoutIntervalForResource = OSSDefaultTimeoutForResourceInSecond;
        self.isPathStyleAccessEnable = NO;
        self.isCustomPathPrefixEnable = NO;
        self.cnameExcludeList = @[];
    }
    return self;
}

- (void)setCnameExcludeList:(NSArray *)cnameExcludeList {
    NSMutableArray * array = [NSMutableArray new];
    [cnameExcludeList enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString * host = [(NSString *)obj lowercaseString];
        if ([host containsString:@"://"]) {
            NSString * trimHost = [host substringFromIndex:[host rangeOfString:@"://"].location + 3];
            [array addObject:trimHost];
        } else {
            [array addObject:host];
        }
    }];
    _cnameExcludeList = array.copy;
}

@end

@implementation OSSSignerInterceptor

- (instancetype)initWithCredentialProvider:(id<OSSCredentialProvider>)credentialProvider {
    if (self = [super init]) {
        self.credentialProvider = credentialProvider;
    }
    return self;
}

- (OSSTask *)interceptRequestMessage:(OSSAllRequestNeededMessage *)requestMessage {
    OSSLogVerbose(@"signing intercepting - ");
    NSError * error = nil;

    /****************************************************************
    * define a constant array to contain all specified subresource */
    static NSArray * OSSSubResourceARRAY = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        OSSSubResourceARRAY = @[@"acl", @"uploadId", @"partNumber", @"uploads", @"logging", @"website", @"location",
                                @"lifecycle", @"referer", @"cors", @"delete", @"append", @"position", @"security-token", @"x-oss-process", @"sequential",@"bucketInfo",@"symlink", @"restore"];
    });
    /****************************************************************/

    /* initial each part of content to sign */
    NSString * method = requestMessage.httpMethod;
    NSString * contentType = @"";
    NSString * contentMd5 = @"";
    NSString * date = requestMessage.date;
    NSString * xossHeader = @"";
    NSString * resource = @"";

    OSSFederationToken * federationToken = nil;

    if (requestMessage.contentType) {
        contentType = requestMessage.contentType;
    }
    if (requestMessage.contentMd5) {
        contentMd5 = requestMessage.contentMd5;
    }

    if ([self.credentialProvider isKindOfClass:[OSSStsTokenCredentialProvider class]]) {
        federationToken = [(OSSStsTokenCredentialProvider *)self.credentialProvider getToken];
        [requestMessage.headerParams oss_setObject:federationToken.tToken forKey:@"x-oss-security-token"];
    }
    
    [requestMessage.headerParams oss_setObject:requestMessage.contentSHA1 forKey:OSSHttpHeaderHashSHA1];
        
    /* construct CanonicalizedOSSHeaders */
    if (requestMessage.headerParams) {
        NSMutableArray * params = [[NSMutableArray alloc] init];
        NSArray * sortedKey = [[requestMessage.headerParams allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [obj1 compare:obj2];
        }];
        for (NSString * key in sortedKey) {
            if ([key hasPrefix:@"x-oss-"]) {
                [params addObject:[NSString stringWithFormat:@"%@:%@", key, [requestMessage.headerParams objectForKey:key]]];
            }
        }
        if ([params count]) {
            xossHeader = [NSString stringWithFormat:@"%@\n", [params componentsJoinedByString:@"\n"]];
        }
    }

    /* construct CanonicalizedResource */
    resource = @"/";
    if (requestMessage.bucketName) {
        resource = [NSString stringWithFormat:@"/%@/", requestMessage.bucketName];
    }
    if (requestMessage.objectKey) {
        resource = [resource oss_stringByAppendingPathComponentForURL:requestMessage.objectKey];
    }
    if (requestMessage.params) {
        NSMutableArray * querys = [[NSMutableArray alloc] init];
        NSArray * sortedKey = [[requestMessage.params allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [obj1 compare:obj2];
        }];
        for (NSString * key in sortedKey) {
            NSString * value = [requestMessage.params objectForKey:key];

            if (![OSSSubResourceARRAY containsObject:key]) { // notice it's based on content compare
                continue;
            }

            if ([value isEqualToString:@""]) {
                [querys addObject:[NSString stringWithFormat:@"%@", key]];
            } else {
                [querys addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
            }
        }
        if ([querys count]) {
            resource = [resource stringByAppendingString:[NSString stringWithFormat:@"?%@",[querys componentsJoinedByString:@"&"]]];
        }
    }

    /* now, join every part of content and sign */
    NSString * stringToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@%@", method, contentMd5, contentType, date, xossHeader, resource];
    OSSLogDebug(@"string to sign: %@", stringToSign);
    if ([self.credentialProvider isKindOfClass:[OSSStsTokenCredentialProvider class]]) {
        NSString * signature = [self.credentialProvider sign:stringToSign error:&error];
        if (error) {
            return [OSSTask taskWithError:error];
        }
        [requestMessage.headerParams oss_setObject:signature forKey:@"Authorization"];
    }
    return [OSSTask taskWithResult:nil];
}

@end

@implementation OSSUASettingInterceptor

- (instancetype)initWithClientConfiguration:(OSSClientConfiguration *)clientConfiguration{
    if (self = [super init]) {
        self.clientConfiguration = clientConfiguration;
    }
    return self;
}

- (OSSTask *)interceptRequestMessage:(OSSAllRequestNeededMessage *)request {
    NSString * userAgent = [self getUserAgent:self.clientConfiguration.userAgentMark];
    [request.headerParams oss_setObject:userAgent forKey:@"User-Agent"];
    return [OSSTask taskWithResult:nil];
}


- (NSString *)getUserAgent:(NSString *)customUserAgent {
    static NSString * userAgent = nil;
    static dispatch_once_t once;
    NSString * tempUserAgent = nil;
    dispatch_once(&once, ^{
        NSString *localeIdentifier = [[NSLocale currentLocale] localeIdentifier];
#if TARGET_OS_IOS
        NSString *systemName = [[[UIDevice currentDevice] systemName] stringByReplacingOccurrencesOfString:@" " withString:@"-"];
        NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
        userAgent = [NSString stringWithFormat:@"%@/%@(/%@/%@/%@)", OSSUAPrefix, OSSSDKVersion, systemName, systemVersion, localeIdentifier];
#elif TARGET_OS_OSX
        userAgent = [NSString stringWithFormat:@"%@/%@(/%@/%@/%@)", OSSUAPrefix, OSSSDKVersion, @"OSX", [NSProcessInfo processInfo].operatingSystemVersionString, localeIdentifier];
#endif
    });
    if(customUserAgent){
        if(userAgent){
            tempUserAgent = [[userAgent stringByAppendingString:@"/"] stringByAppendingString:customUserAgent];
        }else{
            tempUserAgent = customUserAgent;
        }
    }else{
        tempUserAgent = userAgent;
    }
    return tempUserAgent;
}

@end

@implementation OSSTimeSkewedFixingInterceptor

- (OSSTask *)interceptRequestMessage:(OSSAllRequestNeededMessage *)request {
    request.date = [[NSDate oss_clockSkewFixedDate] oss_asStringValue];
    return [OSSTask taskWithResult:nil];
}

@end

#pragma mark request and result objects

@implementation OSSPutObjectRequest

- (instancetype)init {
    if (self = [super init]) {
        self.objectMeta = [NSDictionary new];
    }
    return self;
}

@end

@implementation OSSPutObjectResult
@end
