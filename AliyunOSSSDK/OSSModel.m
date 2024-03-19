//
//  OSSModel.m
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//
#import "OSSDefine.h"
#import "OSSModel.h"
#import "OSSBolts.h"
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

@implementation OSSPlainTextAKSKPairCredentialProvider

- (instancetype)initWithPlainTextAccessKey:(nonnull NSString *)accessKey secretKey:(nonnull NSString *)secretKey {
    if (self = [super init]) {
        self.accessKey = [accessKey oss_trim];
        self.secretKey = [secretKey oss_trim];
    }
    return self;
}

- (nullable NSString *)sign:(NSString *)content error:(NSError **)error {
    if (![self.accessKey oss_isNotEmpty] || ![self.secretKey oss_isNotEmpty])
    {
        if (error != nil)
        {
            *error = [NSError errorWithDomain:OSSClientErrorDomain
                                         code:OSSClientErrorCodeSignFailed
                                     userInfo:@{OSSErrorMessageTOKEN: @"accessKey or secretKey can't be null"}];
        }
        
        return nil;
    }
    NSString * sign = [OSSUtil calBase64Sha1WithData:content withSecret:self.secretKey];
    return [NSString stringWithFormat:@"OSS %@:%@", self.accessKey, sign];
}

@end

@implementation OSSCustomSignerCredentialProvider

- (instancetype)initWithImplementedSigner:(OSSCustomSignContentBlock)signContent
{
    NSParameterAssert(signContent);
    if (self = [super init])
    {
        _signContent = signContent;
    }
    return self;
}

- (NSString *)sign:(NSString *)content error:(NSError **)error
{
    NSString * signature = @"";
    @synchronized(self) {
        signature = self.signContent(content, error);
    }
    if (*error) {
        *error = [NSError errorWithDomain:OSSClientErrorDomain
                                     code:OSSClientErrorCodeSignFailed
                                 userInfo:[[NSDictionary alloc] initWithDictionary:[*error userInfo]]];
        return nil;
    }
    return signature;
}

@end

@implementation OSSFederationCredentialProvider

- (instancetype)initWithFederationTokenGetter:(OSSGetFederationTokenBlock)federationTokenGetter {
    if (self = [super init]) {
        self.federationTokenGetter = federationTokenGetter;
    }
    return self;
}

- (nullable OSSFederationToken *)getToken:(NSError **)error {
    OSSFederationToken * validToken = nil;
    @synchronized(self) {
        if (self.cachedToken == nil) {

            self.cachedToken = self.federationTokenGetter();
        } else {
            if (self.cachedToken.expirationTimeInGMTFormat) {
                NSDateFormatter * fm = [NSDateFormatter new];
                fm.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
                [fm setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
                self.cachedToken.expirationTimeInMilliSecond = [[fm dateFromString:self.cachedToken.expirationTimeInGMTFormat] timeIntervalSince1970] * 1000;
                self.cachedToken.expirationTimeInGMTFormat = nil;
                OSSLogVerbose(@"Transform GMT date to expirationTimeInMilliSecond: %lld", self.cachedToken.expirationTimeInMilliSecond);
            }

            NSDate * expirationDate = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)(self.cachedToken.expirationTimeInMilliSecond / 1000)];
            NSTimeInterval interval = [expirationDate timeIntervalSinceDate:[NSDate oss_clockSkewFixedDate]];
            /* if this token will be expired after less than 2min, we abort it in case of when request arrived oss server,
               it's expired already. */
            if (interval < 5 * 60) {
                OSSLogDebug(@"get federation token, but after %lf second it would be expired", interval);
                self.cachedToken = self.federationTokenGetter();
            }
        }

        validToken = self.cachedToken;
    }
    if (!validToken)
    {
        if (error != nil)
        {
            *error = [NSError errorWithDomain:OSSClientErrorDomain
                                         code:OSSClientErrorCodeSignFailed
                                     userInfo:@{OSSErrorMessageTOKEN: @"Can't get a federation token"}];
        }
        
        return nil;
    }
    return validToken;
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

@implementation OSSAuthCredentialProvider

- (instancetype)initWithAuthServerUrl:(NSString *)authServerUrl
{
    return [self initWithAuthServerUrl:authServerUrl responseDecoder:nil];
}

- (instancetype)initWithAuthServerUrl:(NSString *)authServerUrl responseDecoder:(nullable OSSResponseDecoderBlock)decoder
{
    self = [super initWithFederationTokenGetter:^OSSFederationToken * {
        NSURL * url = [NSURL URLWithString:self.authServerUrl];
        NSURLRequest * request = [NSURLRequest requestWithURL:url];
        OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
        NSURLSession * session = [NSURLSession sharedSession];
        NSURLSessionTask * sessionTask = [session dataTaskWithRequest:request
                                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                        if (error) {
                                                            [tcs setError:error];
                                                            return;
                                                        }
                                                        [tcs setResult:data];
                                                    }];
        [sessionTask resume];
        [tcs.task waitUntilFinished];
        if (tcs.task.error) {
            return nil;
        } else {
            NSData* data = tcs.task.result;
            if(decoder){
                data = decoder(data);
            }
            NSDictionary * object = [NSJSONSerialization JSONObjectWithData:data
                                                                    options:kNilOptions
                                                                      error:nil];
            int statusCode = [[object objectForKey:@"StatusCode"] intValue];
            if (statusCode == 200) {
                OSSFederationToken * token = [OSSFederationToken new];
                // All the entries below are mandatory.
                token.tAccessKey = [object objectForKey:@"AccessKeyId"];
                token.tSecretKey = [object objectForKey:@"AccessKeySecret"];
                token.tToken = [object objectForKey:@"SecurityToken"];
                token.expirationTimeInGMTFormat = [object objectForKey:@"Expiration"];
                OSSLogDebug(@"token: %@ %@ %@ %@", token.tAccessKey, token.tSecretKey, token.tToken, [object objectForKey:@"Expiration"]);
                return token;
            }else{
                return nil;
            }
            
        }
    }];
    if(self){
        self.authServerUrl = authServerUrl;
    }
    return self;
}

@end

NSString * const BACKGROUND_SESSION_IDENTIFIER = @"com.aliyun.oss.backgroundsession";

@implementation OSSClientConfiguration

- (instancetype)init {
    if (self = [super init]) {
        self.maxRetryCount = OSSDefaultRetryCount;
        self.maxConcurrentRequestCount = OSSDefaultMaxConcurrentNum;
        self.enableBackgroundTransmitService = NO;
        self.isHttpdnsEnable = NO;
        self.backgroundSesseionIdentifier = BACKGROUND_SESSION_IDENTIFIER;
        self.timeoutIntervalForRequest = OSSDefaultTimeoutForRequestInSecond;
        self.timeoutIntervalForResource = OSSDefaultTimeoutForResourceInSecond;
        self.isPathStyleAccessEnable = NO;
        self.isCustomPathPrefixEnable = NO;
        self.cnameExcludeList = @[];
        self.isAllowUACarrySystemInfo = YES;
        self.isFollowRedirectsEnable = YES;
        // When the value <= 0, do not set HTTPMaximumConnectionsPerHost and use the default value of NSURLSessionConfiguration
        self.HTTPMaximumConnectionsPerHost = 0;
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
                                @"lifecycle", @"referer", @"cors", @"delete", @"append", @"position", @"security-token", @"x-oss-process", @"sequential",@"bucketInfo",@"symlink", @"restore", @"tagging"];
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

    /* if credential provider is a federation token provider, it need to specially handle */
    if ([self.credentialProvider isKindOfClass:[OSSFederationCredentialProvider class]]) {
        federationToken = [(OSSFederationCredentialProvider *)self.credentialProvider getToken:&error];
        if (error) {
            return [OSSTask taskWithError:error];
        }
        [requestMessage.headerParams oss_setObject:federationToken.tToken forKey:@"x-oss-security-token"];
    } else if ([self.credentialProvider isKindOfClass:[OSSStsTokenCredentialProvider class]]) {
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
    if ([self.credentialProvider isKindOfClass:[OSSFederationCredentialProvider class]]
        || [self.credentialProvider isKindOfClass:[OSSStsTokenCredentialProvider class]])
    {
        NSString * signature = [OSSUtil sign:stringToSign withToken:federationToken];
        [requestMessage.headerParams oss_setObject:signature forKey:@"Authorization"];
    }else if ([self.credentialProvider isKindOfClass:[OSSCustomSignerCredentialProvider class]])
    {
        OSSCustomSignerCredentialProvider *provider = (OSSCustomSignerCredentialProvider *)self.credentialProvider;
        
        NSError *customSignError;
        NSString * signature = [provider sign:stringToSign error:&customSignError];
        if (customSignError) {
            OSSLogError(@"OSSCustomSignerError: %@", customSignError)
            return [OSSTask taskWithError: customSignError];
        }
        [requestMessage.headerParams oss_setObject:signature forKey:@"Authorization"];
    }else
    {
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
        if (self.clientConfiguration.isAllowUACarrySystemInfo) {
            NSString *systemName = [[[UIDevice currentDevice] systemName] stringByReplacingOccurrencesOfString:@" " withString:@"-"];
            NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
            userAgent = [NSString stringWithFormat:@"%@/%@(/%@/%@/%@)", OSSUAPrefix, OSSSDKVersion, systemName, systemVersion, localeIdentifier];
        } else {
            userAgent = [NSString stringWithFormat:@"%@/%@(/%@)", OSSUAPrefix, OSSSDKVersion, localeIdentifier];
        }
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

@implementation OSSRange

- (instancetype)initWithStart:(int64_t)start withEnd:(int64_t)end {
    if (self = [super init]) {
        self.startPosition = start;
        self.endPosition = end;
    }
    return self;
}

- (NSString *)toHeaderString {

    NSString * rangeString = nil;

    if (self.startPosition < 0 && self.endPosition < 0) {
        rangeString = [NSString stringWithFormat:@"bytes=%lld-%lld", self.startPosition, self.endPosition];
    } else if (self.startPosition < 0) {
        rangeString = [NSString stringWithFormat:@"bytes=-%lld", self.endPosition];
    } else if (self.endPosition < 0) {
        rangeString = [NSString stringWithFormat:@"bytes=%lld-", self.startPosition];
    } else {
        rangeString = [NSString stringWithFormat:@"bytes=%lld-%lld", self.startPosition, self.endPosition];
    }

    return rangeString;
}

@end

#pragma mark request and result objects

@implementation OSSGetServiceRequest

- (NSDictionary *)requestParams {
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:self.prefix forKey:@"prefix"];
    [params oss_setObject:self.marker forKey:@"marker"];
    if (self.maxKeys > 0) {
        [params oss_setObject:[@(self.maxKeys) stringValue] forKey:@"max-keys"];
    }
    return [params copy];
}

@end

@implementation OSSGetServiceResult
@end

@implementation OSSCreateBucketRequest

- (instancetype)init
{
    self = [super init];
    if (self) {
        _storageClass = OSSBucketStorageClassStandard;
    }
    return self;
}

- (NSString *)storageClassAsString {
    NSString *storageClassString = nil;
    switch (_storageClass) {
        case OSSBucketStorageClassStandard:
            storageClassString = @"Standard";
            break;
        case OSSBucketStorageClassIA:
            storageClassString = @"IA";
            break;
        case OSSBucketStorageClassArchive:
            storageClassString = @"Archive";
            break;
        default:
            storageClassString = @"Unknown";
            break;
    }
    return storageClassString;
}

@end

@implementation OSSCreateBucketResult
@end

@implementation OSSDeleteBucketRequest
@end

@implementation OSSDeleteBucketResult
@end

@implementation OSSGetBucketRequest

- (NSDictionary *)requestParams {
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:self.delimiter forKey:@"delimiter"];
    [params oss_setObject:self.prefix forKey:@"prefix"];
    [params oss_setObject:self.marker forKey:@"marker"];
    if (self.maxKeys > 0) {
        [params oss_setObject:[@(self.maxKeys) stringValue] forKey:@"max-keys"];
    }
    return [params copy];
}

@end

@implementation OSSListMultipartUploadsRequest
- (NSDictionary *)requestParams {
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:self.delimiter forKey:@"delimiter"];
    [params oss_setObject:self.prefix forKey:@"prefix"];
    [params oss_setObject:self.keyMarker forKey:@"key-marker"];
    [params oss_setObject:self.uploadIdMarker forKey:@"upload-id-marker"];
    [params oss_setObject:self.encodingType forKey:@"encoding-type"];
    
    if (self.maxUploads > 0) {
        [params oss_setObject:[@(self.maxUploads) stringValue] forKey:@"max-uploads"];
    }
    
    return [params copy];
}
@end

@implementation OSSListMultipartUploadsResult
@end

@implementation OSSGetBucketResult
@end

@implementation OSSGetBucketACLRequest

- (NSDictionary *)requestParams {
    return @{@"acl": @""};
}

@end

@implementation OSSGetBucketACLResult
@end

@implementation OSSHeadObjectRequest
@end

@implementation OSSHeadObjectResult
@end

@implementation OSSGetObjectRequest
@end

@implementation OSSGetObjectResult
@end

@implementation OSSPutObjectACLRequest

- (instancetype)init
{
    self = [super init];
    if (self) {
        _acl = @"default";
    }
    return self;
}

@end

@implementation OSSPutObjectACLResult
@end

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

@implementation OSSAppendObjectRequest

- (instancetype)init {
    if (self = [super init]) {
        self.objectMeta = [NSDictionary new];
    }
    return self;
}

@end

@implementation OSSAppendObjectResult
@end

@implementation OSSDeleteObjectRequest
@end

@implementation OSSDeleteObjectResult
@end

@implementation OSSCopyObjectRequest

- (instancetype)init {
    if (self = [super init]) {
        self.objectMeta = [NSDictionary new];
    }
    return self;
}

@end

@implementation OSSCopyObjectResult
@end

@implementation OSSInitMultipartUploadRequest

- (instancetype)init {
    if (self = [super init]) {
        self.objectMeta = [NSDictionary new];
    }
    return self;
}

@end

@implementation OSSInitMultipartUploadResult
@end

@implementation OSSUploadPartRequest
@end

@implementation OSSUploadPartResult
@end

@implementation OSSPartInfo

+ (instancetype)partInfoWithPartNum:(int32_t)partNum
                               eTag:(NSString *)eTag
                               size:(int64_t)size {
    return [self partInfoWithPartNum:partNum
                                eTag:eTag
                                size:size
                               crc64:0];
}

+ (instancetype)partInfoWithPartNum:(int32_t)partNum eTag:(NSString *)eTag size:(int64_t)size crc64:(uint64_t)crc64
{
    OSSPartInfo *parInfo = [OSSPartInfo new];
    parInfo.partNum = partNum;
    parInfo.eTag = eTag;
    parInfo.size = size;
    parInfo.crc64 = crc64;
    return parInfo;
}

- (nonnull NSDictionary *)entityToDictionary
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:@(_partNum) forKey:@"partNum"];
    if (_eTag)
    {
        [dict setValue:_eTag forKey:@"eTag"];
    }
    [dict setValue:@(_size) forKey:@"size"];
    [dict setValue:@(_crc64) forKey:@"crc64"];
    return [dict copy];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"OSSPartInfo<%p>:{partNum: %d,eTag: %@,partSize: %lld,crc64: %llu}",self,self.partNum,self.eTag,self.size,self.crc64];
}

#pragma marks - Protocol Methods
- (id)copyWithZone:(nullable NSZone *)zone
{
    OSSPartInfo *instance = [[[self class] allocWithZone:zone] init];
    instance.partNum = self.partNum;
    instance.eTag = self.eTag;
    instance.size = self.size;
    instance.crc64 = self.crc64;
    return instance;
}

@end

@implementation OSSCompleteMultipartUploadRequest
@end

@implementation OSSCompleteMultipartUploadResult
@end

@implementation OSSAbortMultipartUploadRequest
@end

@implementation OSSAbortMultipartUploadResult
@end

@implementation OSSListPartsRequest
@end

@implementation OSSListPartsResult
@end

@implementation OSSMultipartUploadRequest

- (instancetype)init {
    if (self = [super init]) {
        self.partSize = 256 * 1024;
        self.threadNum = OSSDefaultThreadNum;
    }
    return self;
}

- (void)cancel {
    [super cancel];
}

@end

@implementation OSSResumableUploadRequest

- (instancetype)init {
    if (self = [super init]) {
        self.deleteUploadIdOnCancelling = YES;
        self.partSize = 256 * 1024;
    }
    return self;
}

- (void)cancel {
    [super cancel];
    if(_runningChildrenRequest){
        [_runningChildrenRequest cancel];
    }
}

@end

@implementation OSSResumableUploadResult
@end

@implementation OSSCallBackRequest
@end

@implementation OSSCallBackResult
@end

@implementation OSSImagePersistRequest
@end

@implementation OSSImagePersistResult
@end
