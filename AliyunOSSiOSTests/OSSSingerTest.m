//
//  SingerTest.m
//  AliyunOSSiOSTests
//
//  Created by ws on 2024/1/2.
//  Copyright © 2024 aliyun. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import <AliyunOSSiOS/OSSSignerParams.h>
#import <AliyunOSSiOS/OSSSignerBase.h>
#import "OSSTestMacros.h"

@interface OSSSingerTest : XCTestCase

@end

@implementation OSSSingerTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)test_singerWithSignerV4 {
    OSSSignVersion version = OSSSignVersionV4;
    
    id<OSSCredentialProvider> credentialProvider = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:@"ak" secretKey:@"sk"];
    
    NSString *bucket = @"bucket";
    NSString *key = @"1234+-/123/1.txt";
    NSString *region = @"cn-hangzhou";
    NSString *product = @"oss";
    NSTimeInterval t = 1702743657.018L;
    [NSDate oss_setClockSkew:[NSDate new].timeIntervalSince1970 - t];
    
    NSMutableDictionary *headers = @{}.mutableCopy;
    NSMutableDictionary *parameters = @{}.mutableCopy;

    headers[@"x-oss-head1"] = @"value";
    headers[@"abc"] = @"value";
    headers[@"ZAbc"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"content-type"] = @"text/plain";
    headers[@"x-oss-content-sha256"] = @"UNSIGNED-PAYLOAD";
    
    parameters[@"param1"] = @"value1";
    parameters[@"|param1"] = @"value2";
    parameters[@"+param1"] = @"value3";
    parameters[@"|param1"] = @"value4";
    parameters[@"+param2"] = @"";
    parameters[@"|param2"] = @"";
    parameters[@"param2"] = @"";
    
    OSSAllRequestNeededMessage *requestMessage = [OSSAllRequestNeededMessage new];
    requestMessage.isAuthenticationRequired = YES;
    requestMessage.httpMethod = @"PUT";
    requestMessage.bucketName = bucket;
    requestMessage.objectKey = key;
    requestMessage.headerParams = headers;
    requestMessage.params = parameters;
    
    NSString *resource = [@"/" stringByAppendingString:((bucket != nil) ? [bucket stringByAppendingString:@"/"] : @"")];
    resource = [resource stringByAppendingString:(key != nil ? key : @"")];
    OSSSignerParams *signerParam = [OSSSignerParams new];
    signerParam.credentialProvider = credentialProvider;
    signerParam.resourcePath = resource;
    signerParam.product = product;
    signerParam.region = region;
    
    id<OSSRequestSigner> signer = [OSSSignerBase createRequestSignerWithSignerVersion:version
                                                                         signerParams:signerParam];
    [signer sign:requestMessage];
    
    NSString *authPat = @"OSS4-HMAC-SHA256 Credential=ak/20231216/cn-hangzhou/oss/aliyun_v4_request,Signature=6cd8ae10232afa353f05151a5d38f991a3ac9aa6e97bb2168571f417074683e5";
    XCTAssertTrue([authPat isEqualToString:requestMessage.headerParams[OSSHttpHeaderAuthorization]]);
}

- (void)test_singerWithSignerV4Token {
    OSSSignVersion version = OSSSignVersionV4;
    
    id<OSSCredentialProvider> credentialProvider = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:@"ak" secretKeyId:@"sk" securityToken:@"token"];
    
    NSString *bucket = @"bucket";
    NSString *key = @"1234+-/123/1.txt";
    NSString *region = @"cn-hangzhou";
    NSString *product = @"oss";
    NSTimeInterval t = 1702743657.018L;
    [NSDate oss_setClockSkew:[NSDate new].timeIntervalSince1970 - t];
    
    NSMutableDictionary *headers = @{}.mutableCopy;
    NSMutableDictionary *parameters = @{}.mutableCopy;

    headers[@"x-oss-head1"] = @"value";
    headers[@"abc"] = @"value";
    headers[@"ZAbc"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"content-type"] = @"text/plain";
    headers[@"x-oss-content-sha256"] = @"UNSIGNED-PAYLOAD";
    
    parameters[@"param1"] = @"value1";
    parameters[@"|param1"] = @"value2";
    parameters[@"+param1"] = @"value3";
    parameters[@"|param1"] = @"value4";
    parameters[@"+param2"] = @"";
    parameters[@"|param2"] = @"";
    parameters[@"param2"] = @"";
    
    OSSAllRequestNeededMessage *requestMessage = [OSSAllRequestNeededMessage new];
    requestMessage.isAuthenticationRequired = YES;
    requestMessage.httpMethod = @"PUT";
    requestMessage.bucketName = bucket;
    requestMessage.objectKey = key;
    requestMessage.headerParams = headers;
    requestMessage.params = parameters;
    
    NSString *resource = [@"/" stringByAppendingString:((bucket != nil) ? [bucket stringByAppendingString:@"/"] : @"")];
    resource = [resource stringByAppendingString:(key != nil ? key : @"")];
    OSSSignerParams *signerParam = [OSSSignerParams new];
    signerParam.credentialProvider = credentialProvider;
    signerParam.resourcePath = resource;
    signerParam.product = product;
    signerParam.region = region;
    
    id<OSSRequestSigner> signer = [OSSSignerBase createRequestSignerWithSignerVersion:version
                                                                         signerParams:signerParam];
    [signer sign:requestMessage];
    
    NSString *authPat = @"OSS4-HMAC-SHA256 Credential=ak/20231216/cn-hangzhou/oss/aliyun_v4_request,Signature=9faee2e4e5c19df7ba4da437b74454c68104151ee7b254cc344701ac7c4dac3c";
    XCTAssertTrue([authPat isEqualToString:requestMessage.headerParams[OSSHttpHeaderAuthorization]]);
}

- (void)test_singerWithFederationCredentialProvider {
    OSSSignVersion version = OSSSignVersionV4;
    
    id<OSSCredentialProvider> credentialProvider = [[OSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^OSSFederationToken * _Nullable{
        OSSFederationToken *federationToken = [OSSFederationToken new];
        federationToken.tAccessKey = @"ak";
        federationToken.tSecretKey = @"sk";
        federationToken.tToken = @"token";
        return federationToken;
    }];
    
    NSString *bucket = @"bucket";
    NSString *key = @"1234+-/123/1.txt";
    NSString *region = @"cn-hangzhou";
    NSString *product = @"oss";
    NSTimeInterval t = 1702743657.018L;
    [NSDate oss_setClockSkew:[NSDate new].timeIntervalSince1970 - t];
    
    NSMutableDictionary *headers = @{}.mutableCopy;
    NSMutableDictionary *parameters = @{}.mutableCopy;

    headers[@"x-oss-head1"] = @"value";
    headers[@"abc"] = @"value";
    headers[@"ZAbc"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"content-type"] = @"text/plain";
    headers[@"x-oss-content-sha256"] = @"UNSIGNED-PAYLOAD";
    
    parameters[@"param1"] = @"value1";
    parameters[@"|param1"] = @"value2";
    parameters[@"+param1"] = @"value3";
    parameters[@"|param1"] = @"value4";
    parameters[@"+param2"] = @"";
    parameters[@"|param2"] = @"";
    parameters[@"param2"] = @"";
    
    OSSAllRequestNeededMessage *requestMessage = [OSSAllRequestNeededMessage new];
    requestMessage.isAuthenticationRequired = YES;
    requestMessage.httpMethod = @"PUT";
    requestMessage.bucketName = bucket;
    requestMessage.objectKey = key;
    requestMessage.headerParams = headers;
    requestMessage.params = parameters;
    
    NSString *resource = [@"/" stringByAppendingString:((bucket != nil) ? [bucket stringByAppendingString:@"/"] : @"")];
    resource = [resource stringByAppendingString:(key != nil ? key : @"")];
    OSSSignerParams *signerParam = [OSSSignerParams new];
    signerParam.credentialProvider = credentialProvider;
    signerParam.resourcePath = resource;
    signerParam.product = product;
    signerParam.region = region;
    
    id<OSSRequestSigner> signer = [OSSSignerBase createRequestSignerWithSignerVersion:version
                                                                         signerParams:signerParam];
    [signer sign:requestMessage];
    
    NSString *authPat = @"OSS4-HMAC-SHA256 Credential=ak/20231216/cn-hangzhou/oss/aliyun_v4_request,Signature=9faee2e4e5c19df7ba4da437b74454c68104151ee7b254cc344701ac7c4dac3c";
    XCTAssertTrue([authPat isEqualToString:requestMessage.headerParams[OSSHttpHeaderAuthorization]]);
    
    
    credentialProvider = [[OSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^OSSFederationToken * _Nullable{
        return nil;
    }];
    
    signerParam = [OSSSignerParams new];
    signerParam.credentialProvider = credentialProvider;
    signerParam.resourcePath = resource;
    signerParam.product = product;
    signerParam.region = region;
    signer = [OSSSignerBase createRequestSignerWithSignerVersion:version
                                                    signerParams:signerParam];
    OSSTask *task = [signer sign:requestMessage];
    
    XCTAssertNotNil(task.error);
    XCTAssertEqual(task.error.code, OSSClientErrorCodeSignFailed);
}

- (void)test_singerWithOSSCustomSignerCredentialProvider {
    OSSSignVersion version = OSSSignVersionV4;
    NSString *bucket = @"bucket";
    NSString *key = @"1234+-/123/1.txt";
    NSString *region = @"cn-hangzhou";
    NSString *product = @"oss";
    NSTimeInterval t = 1702743657.018L;
    [NSDate oss_setClockSkew:[NSDate new].timeIntervalSince1970 - t];
    
    id<OSSCredentialProvider> credentialProvider = [[OSSCustomSignerCredentialProvider alloc] initWithImplementedSigner:^NSString * _Nullable(NSString * _Nonnull contentToSign, NSError *__autoreleasing  _Nullable * _Nullable error) {
        NSData *jsonData = [contentToSign dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *content = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                options:NSJSONReadingMutableContainers
                                                                  error:error];
        XCTAssertTrue([region isEqualToString:content[@"region"]]);
        XCTAssertTrue([product isEqualToString:content[@"product"]]);
        XCTAssertTrue([@"20231216" isEqualToString:content[@"date"]]);
        XCTAssertTrue([@"OSS4-HMAC-SHA256" isEqualToString:content[@"algorithm"]]);
        XCTAssertTrue([@"OSS4-HMAC-SHA256\n20231216T162057Z\n20231216/cn-hangzhou/oss/aliyun_v4_request\n6f8e1ffc6bfa3c7acf637102db36372c97019223641f786cd147a8cdf79b4464" isEqualToString:content[@"stringToSign"]]);
        return @"OSS4-HMAC-SHA256 Credential=ak/20231216/cn-hangzhou/oss/aliyun_v4_request,Signature=0436fec1623c737d5827c11d200afd3df51d067b80196080438f57c94d99b9b0";
    }];
    
    NSMutableDictionary *headers = @{}.mutableCopy;
    NSMutableDictionary *parameters = @{}.mutableCopy;

    headers[@"x-oss-head1"] = @"value";
    headers[@"abc"] = @"value";
    headers[@"ZAbc"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"content-type"] = @"text/plain";
    headers[@"x-oss-content-sha256"] = @"UNSIGNED-PAYLOAD";
    
    parameters[@"param1"] = @"value1";
    parameters[@"|param1"] = @"value2";
    parameters[@"+param1"] = @"value3";
    parameters[@"|param1"] = @"value4";
    parameters[@"+param2"] = @"";
    parameters[@"|param2"] = @"";
    parameters[@"param2"] = @"";
    
    OSSAllRequestNeededMessage *requestMessage = [OSSAllRequestNeededMessage new];
    requestMessage.isAuthenticationRequired = YES;
    requestMessage.httpMethod = @"PUT";
    requestMessage.bucketName = bucket;
    requestMessage.objectKey = key;
    requestMessage.headerParams = headers;
    requestMessage.params = parameters;
    
    NSString *resource = [@"/" stringByAppendingString:((bucket != nil) ? [bucket stringByAppendingString:@"/"] : @"")];
    resource = [resource stringByAppendingString:(key != nil ? key : @"")];
    OSSSignerParams *signerParam = [OSSSignerParams new];
    signerParam.credentialProvider = credentialProvider;
    signerParam.resourcePath = resource;
    signerParam.product = product;
    signerParam.region = region;
    
    id<OSSRequestSigner> signer = [OSSSignerBase createRequestSignerWithSignerVersion:version
                                                                         signerParams:signerParam];
    [signer sign:requestMessage];
    
    NSString *authPat = @"OSS4-HMAC-SHA256 Credential=ak/20231216/cn-hangzhou/oss/aliyun_v4_request,Signature=0436fec1623c737d5827c11d200afd3df51d067b80196080438f57c94d99b9b0";
    NSLog(@"%@", requestMessage.headerParams);
    XCTAssertTrue([authPat isEqualToString:requestMessage.headerParams[OSSHttpHeaderAuthorization]]);
}

- (void)test_signerV4WithAdditionalHeaders {
    OSSSignVersion version = OSSSignVersionV4;
    
    id<OSSCredentialProvider> credentialProvider = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:@"ak" secretKeyId:@"sk" securityToken:@"token"];
    
    NSString *bucket = @"bucket";
    NSString *key = @"1234+-/123/1.txt";
    NSString *region = @"cn-hangzhou";
    NSString *product = @"oss";
    NSTimeInterval t = 1702743657.018L;
    [NSDate oss_setClockSkew:[NSDate new].timeIntervalSince1970 - t];
    
    NSMutableDictionary *headers = @{}.mutableCopy;
    NSMutableDictionary *parameters = @{}.mutableCopy;
    NSMutableSet<NSString *> *signHeaders = [NSMutableSet new];

    headers[@"x-oss-head1"] = @"value";
    headers[@"abc"] = @"value";
    headers[@"ZAbc"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"content-type"] = @"text/plain";
    headers[@"x-oss-content-sha256"] = @"UNSIGNED-PAYLOAD";
    
    parameters[@"param1"] = @"value1";
    parameters[@"|param1"] = @"value2";
    parameters[@"+param1"] = @"value3";
    parameters[@"|param1"] = @"value4";
    parameters[@"+param2"] = @"";
    parameters[@"|param2"] = @"";
    parameters[@"param2"] = @"";
    
    [signHeaders addObject:@"abc"];
    [signHeaders addObject:@"ZAbc"];

    OSSAllRequestNeededMessage *requestMessage = [OSSAllRequestNeededMessage new];
    requestMessage.isAuthenticationRequired = YES;
    requestMessage.httpMethod = @"PUT";
    requestMessage.bucketName = bucket;
    requestMessage.objectKey = key;
    requestMessage.headerParams = headers;
    requestMessage.params = parameters;
    requestMessage.additionalHeaderNames = signHeaders;
    
    NSString *resource = [@"/" stringByAppendingString:((bucket != nil) ? [bucket stringByAppendingString:@"/"] : @"")];
    resource = [resource stringByAppendingString:(key != nil ? key : @"")];
    OSSSignerParams *signerParam = [OSSSignerParams new];
    signerParam.credentialProvider = credentialProvider;
    signerParam.resourcePath = resource;
    signerParam.product = product;
    signerParam.region = region;
    
    id<OSSRequestSigner> signer = [OSSSignerBase createRequestSignerWithSignerVersion:version
                                                                         signerParams:signerParam];
    [signer sign:requestMessage];
    
    NSString *authPat = @"OSS4-HMAC-SHA256 Credential=ak/20231216/cn-hangzhou/oss/aliyun_v4_request,AdditionalHeaders=abc;zabc,Signature=4b374b4b54ae386e0eab4e90585afeadc7314eec060f44c2db1eaa3a1ec2e33c";
    XCTAssertTrue([authPat isEqualToString:requestMessage.headerParams[OSSHttpHeaderAuthorization]]);
    
    // 2
    signHeaders = [NSMutableSet new];
    [signHeaders addObject:@"abc"];
    [signHeaders addObject:@"ZAbc"];
    [signHeaders addObject:@"x-oss-head1"];
    [signHeaders addObject:@"x-oss-no-exist"];

    requestMessage = [OSSAllRequestNeededMessage new];
    requestMessage.isAuthenticationRequired = YES;
    requestMessage.httpMethod = @"PUT";
    requestMessage.bucketName = bucket;
    requestMessage.objectKey = key;
    requestMessage.headerParams = headers;
    requestMessage.params = parameters;
    requestMessage.additionalHeaderNames = signHeaders;
    
    resource = [@"/" stringByAppendingString:((bucket != nil) ? [bucket stringByAppendingString:@"/"] : @"")];
    resource = [resource stringByAppendingString:(key != nil ? key : @"")];
    signerParam = [OSSSignerParams new];
    signerParam.credentialProvider = credentialProvider;
    signerParam.resourcePath = resource;
    signerParam.product = product;
    signerParam.region = region;
    
    signer = [OSSSignerBase createRequestSignerWithSignerVersion:version
                                                                         signerParams:signerParam];
    [signer sign:requestMessage];
    
    NSLog(@"%@", requestMessage.headerParams);
    XCTAssertTrue([authPat isEqualToString:requestMessage.headerParams[OSSHttpHeaderAuthorization]]);
}

- (void)test_singerWithSignerV4Presign {
    OSSSignVersion version = OSSSignVersionV4;
    
    id<OSSCredentialProvider> credentialProvider = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:@"ak" secretKey:@"sk"];
    
    NSString *bucket = @"bucket";
    NSString *key = @"1234+-/123/1.txt";
    NSString *region = @"cn-hangzhou";
    NSString *product = @"oss";
    NSTimeInterval t = 1702743657.018L;
    [NSDate oss_setClockSkew:[NSDate new].timeIntervalSince1970 - t];
    
    NSMutableDictionary *headers = @{}.mutableCopy;
    NSMutableDictionary *parameters = @{}.mutableCopy;

    headers[@"x-oss-head1"] = @"value";
    headers[@"abc"] = @"value";
    headers[@"ZAbc"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"content-type"] = @"text/plain";
    headers[@"x-oss-content-sha256"] = @"UNSIGNED-PAYLOAD";
    
    parameters[@"param1"] = @"value1";
    parameters[@"|param1"] = @"value2";
    parameters[@"+param1"] = @"value3";
    parameters[@"|param1"] = @"value4";
    parameters[@"+param2"] = @"";
    parameters[@"|param2"] = @"";
    parameters[@"param2"] = @"";
    
    OSSAllRequestNeededMessage *requestMessage = [OSSAllRequestNeededMessage new];
    requestMessage.isAuthenticationRequired = YES;
    requestMessage.httpMethod = @"PUT";
    requestMessage.bucketName = bucket;
    requestMessage.objectKey = key;
    requestMessage.headerParams = headers;
    requestMessage.params = parameters;
    requestMessage.isUseUrlSignature = YES;
    
    NSString *resource = [@"/" stringByAppendingString:((bucket != nil) ? [bucket stringByAppendingString:@"/"] : @"")];
    resource = [resource stringByAppendingString:(key != nil ? key : @"")];
    OSSSignerParams *signerParam = [OSSSignerParams new];
    signerParam.credentialProvider = credentialProvider;
    signerParam.resourcePath = resource;
    signerParam.product = product;
    signerParam.region = region;
    signerParam.expiration = 599;
    
    id<OSSRequestPresigner> signer = [OSSSignerBase createRequestPresignerWithSignerVersion:version
                                                                               signerParams:signerParam];
    [signer presign:requestMessage];
    
    XCTAssertTrue([@"OSS4-HMAC-SHA256" isEqualToString:requestMessage.params[@"x-oss-signature-version"]]);
    XCTAssertTrue([@"20231216T162057Z" isEqualToString:requestMessage.params[@"x-oss-date"]]);
    XCTAssertTrue([@"599" isEqualToString:requestMessage.params[@"x-oss-expires"]]);
    XCTAssertTrue([@"ak/20231216/cn-hangzhou/oss/aliyun_v4_request" isEqualToString:requestMessage.params[@"x-oss-credential"]]);
    XCTAssertTrue([@"6cd8ae10232afa353f05151a5d38f991a3ac9aa6e97bb2168571f417074683e5" isEqualToString:requestMessage.params[@"x-oss-signature"]]);
    XCTAssertNil(requestMessage.params[@"x-oss-additional-headers"]);
}

- (void)test_V4PresignWithOSSFederationCredentialProvider {
    OSSSignVersion version = OSSSignVersionV4;
    
    id<OSSCredentialProvider> credentialProvider = [[OSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^OSSFederationToken * _Nullable{
        OSSFederationToken *federationToken = [OSSFederationToken new];
        federationToken.tAccessKey = @"ak";
        federationToken.tSecretKey = @"sk";
        federationToken.tToken = @"token";
        return federationToken;
    }];
    
    NSString *bucket = @"bucket";
    NSString *key = @"1234+-/123/1.txt";
    NSString *region = @"cn-hangzhou";
    NSString *product = @"oss";
    NSTimeInterval t = 1702743657.018L;
    [NSDate oss_setClockSkew:[NSDate new].timeIntervalSince1970 - t];
    
    NSMutableDictionary *headers = @{}.mutableCopy;
    NSMutableDictionary *parameters = @{}.mutableCopy;

    headers[@"x-oss-head1"] = @"value";
    headers[@"abc"] = @"value";
    headers[@"ZAbc"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"content-type"] = @"text/plain";
    headers[@"x-oss-content-sha256"] = @"UNSIGNED-PAYLOAD";
    
    parameters[@"param1"] = @"value1";
    parameters[@"|param1"] = @"value2";
    parameters[@"+param1"] = @"value3";
    parameters[@"|param1"] = @"value4";
    parameters[@"+param2"] = @"";
    parameters[@"|param2"] = @"";
    parameters[@"param2"] = @"";
    
    OSSAllRequestNeededMessage *requestMessage = [OSSAllRequestNeededMessage new];
    requestMessage.isAuthenticationRequired = YES;
    requestMessage.httpMethod = @"PUT";
    requestMessage.bucketName = bucket;
    requestMessage.objectKey = key;
    requestMessage.headerParams = headers;
    requestMessage.params = parameters;
    requestMessage.isUseUrlSignature = YES;
    
    NSString *resource = [@"/" stringByAppendingString:((bucket != nil) ? [bucket stringByAppendingString:@"/"] : @"")];
    resource = [resource stringByAppendingString:(key != nil ? key : @"")];
    OSSSignerParams *signerParam = [OSSSignerParams new];
    signerParam.credentialProvider = credentialProvider;
    signerParam.resourcePath = resource;
    signerParam.product = product;
    signerParam.region = region;
    signerParam.expiration = 599;
    
    id<OSSRequestPresigner> signer = [OSSSignerBase createRequestPresignerWithSignerVersion:version
                                                                               signerParams:signerParam];
    [signer presign:requestMessage];
    
    XCTAssertTrue([@"OSS4-HMAC-SHA256" isEqualToString:requestMessage.params[@"x-oss-signature-version"]]);
    XCTAssertTrue([@"20231216T162057Z" isEqualToString:requestMessage.params[@"x-oss-date"]]);
    XCTAssertTrue([@"599" isEqualToString:requestMessage.params[@"x-oss-expires"]]);
    XCTAssertTrue([@"ak/20231216/cn-hangzhou/oss/aliyun_v4_request" isEqualToString:requestMessage.params[@"x-oss-credential"]]);
    XCTAssertTrue([@"6cd8ae10232afa353f05151a5d38f991a3ac9aa6e97bb2168571f417074683e5" isEqualToString:requestMessage.params[@"x-oss-signature"]]);
    XCTAssertNil(requestMessage.params[@"x-oss-additional-headers"]);
}

- (void)test_V4PresignWithOSSCustomSignerCredentialProvider {
    OSSSignVersion version = OSSSignVersionV4;
    NSString *bucket = @"bucket";
    NSString *key = @"1234+-/123/1.txt";
    NSString *region = @"cn-hangzhou";
    NSString *product = @"oss";
    NSTimeInterval t = 1702743657.018L;
    [NSDate oss_setClockSkew:[NSDate new].timeIntervalSince1970 - t];
    
    id<OSSCredentialProvider> credentialProvider = [[OSSCustomSignerCredentialProvider alloc] initWithImplementedSigner:^NSString * _Nullable(NSString * _Nonnull contentToSign, NSError *__autoreleasing  _Nullable * _Nullable error) {
        NSData *jsonData = [contentToSign dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *content = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                options:NSJSONReadingMutableContainers
                                                                  error:error];
        XCTAssertTrue([region isEqualToString:content[@"region"]]);
        XCTAssertTrue([product isEqualToString:content[@"product"]]);
        XCTAssertTrue([@"20231216" isEqualToString:content[@"date"]]);
        XCTAssertTrue([@"OSS4-HMAC-SHA256" isEqualToString:content[@"algorithm"]]);
        XCTAssertTrue([@"OSS4-HMAC-SHA256\n20231216T162057Z\n20231216/cn-hangzhou/oss/aliyun_v4_request\n6f8e1ffc6bfa3c7acf637102db36372c97019223641f786cd147a8cdf79b4464" isEqualToString:content[@"stringToSign"]]);
        return @"OSS4-HMAC-SHA256 Credential=ak/20231216/cn-hangzhou/oss/aliyun_v4_request,Signature=0436fec1623c737d5827c11d200afd3df51d067b80196080438f57c94d99b9b0";
    }];
    
    NSMutableDictionary *headers = @{}.mutableCopy;
    NSMutableDictionary *parameters = @{}.mutableCopy;

    headers[@"x-oss-head1"] = @"value";
    headers[@"abc"] = @"value";
    headers[@"ZAbc"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"content-type"] = @"text/plain";
    headers[@"x-oss-content-sha256"] = @"UNSIGNED-PAYLOAD";
    
    parameters[@"param1"] = @"value1";
    parameters[@"|param1"] = @"value2";
    parameters[@"+param1"] = @"value3";
    parameters[@"|param1"] = @"value4";
    parameters[@"+param2"] = @"";
    parameters[@"|param2"] = @"";
    parameters[@"param2"] = @"";
    
    OSSAllRequestNeededMessage *requestMessage = [OSSAllRequestNeededMessage new];
    requestMessage.isAuthenticationRequired = YES;
    requestMessage.httpMethod = @"PUT";
    requestMessage.bucketName = bucket;
    requestMessage.objectKey = key;
    requestMessage.headerParams = headers;
    requestMessage.params = parameters;
    requestMessage.isUseUrlSignature = YES;
    
    NSString *resource = [@"/" stringByAppendingString:((bucket != nil) ? [bucket stringByAppendingString:@"/"] : @"")];
    resource = [resource stringByAppendingString:(key != nil ? key : @"")];
    OSSSignerParams *signerParam = [OSSSignerParams new];
    signerParam.credentialProvider = credentialProvider;
    signerParam.resourcePath = resource;
    signerParam.product = product;
    signerParam.region = region;
    signerParam.expiration = 599;
    
    id<OSSRequestPresigner> signer = [OSSSignerBase createRequestPresignerWithSignerVersion:version
                                                                               signerParams:signerParam];
    [signer presign:requestMessage];
    
    XCTAssertTrue([@"OSS4-HMAC-SHA256" isEqualToString:requestMessage.params[@"x-oss-signature-version"]]);
    XCTAssertTrue([@"20231216T162057Z" isEqualToString:requestMessage.params[@"x-oss-date"]]);
    XCTAssertTrue([@"599" isEqualToString:requestMessage.params[@"x-oss-expires"]]);
    XCTAssertTrue([@"ak/20231216/cn-hangzhou/oss/aliyun_v4_request" isEqualToString:requestMessage.params[@"x-oss-credential"]]);
    XCTAssertTrue([@"0436fec1623c737d5827c11d200afd3df51d067b80196080438f57c94d99b9b0" isEqualToString:requestMessage.params[@"x-oss-signature"]]);
    XCTAssertNil(requestMessage.params[@"x-oss-additional-headers"]);
}

- (void)test_singerWithSignerV4PresignToken {
    OSSSignVersion version = OSSSignVersionV4;
    
    id<OSSCredentialProvider> credentialProvider = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:@"ak" secretKeyId:@"sk" securityToken:@"token"];
    
    NSString *bucket = @"bucket";
    NSString *key = @"1234+-/123/1.txt";
    NSString *region = @"cn-hangzhou";
    NSString *product = @"oss";
    NSTimeInterval t = 1702743657.018L;
    [NSDate oss_setClockSkew:[NSDate new].timeIntervalSince1970 - t];
    
    NSMutableDictionary *headers = @{}.mutableCopy;
    NSMutableDictionary *parameters = @{}.mutableCopy;
    NSMutableSet<NSString *> *signHeaders = [NSMutableSet new];

    headers[@"x-oss-head1"] = @"value";
    headers[@"abc"] = @"value";
    headers[@"ZAbc"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"content-type"] = @"text/plain";
    headers[@"x-oss-content-sha256"] = @"UNSIGNED-PAYLOAD";
    
    parameters[@"param1"] = @"value1";
    parameters[@"|param1"] = @"value2";
    parameters[@"+param1"] = @"value3";
    parameters[@"|param1"] = @"value4";
    parameters[@"+param2"] = @"";
    parameters[@"|param2"] = @"";
    parameters[@"param2"] = @"";
    
    [signHeaders addObject:@"abc"];
    [signHeaders addObject:@"ZAbc"];

    OSSAllRequestNeededMessage *requestMessage = [OSSAllRequestNeededMessage new];
    requestMessage.isAuthenticationRequired = YES;
    requestMessage.httpMethod = @"PUT";
    requestMessage.bucketName = bucket;
    requestMessage.objectKey = key;
    requestMessage.headerParams = headers;
    requestMessage.params = parameters;
    requestMessage.additionalHeaderNames = signHeaders;
    requestMessage.isUseUrlSignature = YES;
    
    NSString *resource = [@"/" stringByAppendingString:((bucket != nil) ? [bucket stringByAppendingString:@"/"] : @"")];
    resource = [resource stringByAppendingString:(key != nil ? key : @"")];
    OSSSignerParams *signerParam = [OSSSignerParams new];
    signerParam.credentialProvider = credentialProvider;
    signerParam.resourcePath = resource;
    signerParam.product = product;
    signerParam.region = region;
    signerParam.expiration = 599;
    signerParam.additionalHeaderNames = signHeaders;

    id<OSSRequestPresigner> signer = [OSSSignerBase createRequestPresignerWithSignerVersion:version
                                                                               signerParams:signerParam];
    [signer presign:requestMessage];
    
    XCTAssertTrue([@"OSS4-HMAC-SHA256" isEqualToString:requestMessage.params[@"x-oss-signature-version"]]);
    XCTAssertTrue([@"20231216T162057Z" isEqualToString:requestMessage.params[@"x-oss-date"]]);
    XCTAssertTrue([@"599" isEqualToString:requestMessage.params[@"x-oss-expires"]]);
    XCTAssertTrue([@"ak/20231216/cn-hangzhou/oss/aliyun_v4_request" isEqualToString:requestMessage.params[@"x-oss-credential"]]);
    XCTAssertTrue([@"d6e4d6cad84025263a681be6d19c23e5559f605cc86089f6d7af0fbd676acdc4" isEqualToString:requestMessage.params[@"x-oss-signature"]]);
    XCTAssertTrue([requestMessage.params[@"x-oss-additional-headers"] isEqualToString:@"abc;zabc"]);
    
    // 2
    signHeaders = [NSMutableSet new];
    [signHeaders addObject:@"abc"];
    [signHeaders addObject:@"ZAbc"];
    [signHeaders addObject:@"x-oss-head1"];
    [signHeaders addObject:@"x-oss-no-exist"];

    requestMessage = [OSSAllRequestNeededMessage new];
    requestMessage.isAuthenticationRequired = YES;
    requestMessage.httpMethod = @"PUT";
    requestMessage.bucketName = bucket;
    requestMessage.objectKey = key;
    requestMessage.headerParams = headers;
    requestMessage.params = parameters;
    requestMessage.additionalHeaderNames = signHeaders;
    
    resource = [@"/" stringByAppendingString:((bucket != nil) ? [bucket stringByAppendingString:@"/"] : @"")];
    resource = [resource stringByAppendingString:(key != nil ? key : @"")];
    signerParam = [OSSSignerParams new];
    signerParam.credentialProvider = credentialProvider;
    signerParam.resourcePath = resource;
    signerParam.product = product;
    signerParam.region = region;
    signerParam.expiration = 599;
    signerParam.additionalHeaderNames = signHeaders;
    
    signer = [OSSSignerBase createRequestPresignerWithSignerVersion:version
                                                       signerParams:signerParam];
    [signer presign:requestMessage];
    
    XCTAssertTrue([@"OSS4-HMAC-SHA256" isEqualToString:requestMessage.params[@"x-oss-signature-version"]]);
    XCTAssertTrue([@"20231216T162057Z" isEqualToString:requestMessage.params[@"x-oss-date"]]);
    XCTAssertTrue([@"599" isEqualToString:requestMessage.params[@"x-oss-expires"]]);
    XCTAssertTrue([@"ak/20231216/cn-hangzhou/oss/aliyun_v4_request" isEqualToString:requestMessage.params[@"x-oss-credential"]]);
    XCTAssertTrue([@"d6e4d6cad84025263a681be6d19c23e5559f605cc86089f6d7af0fbd676acdc4" isEqualToString:requestMessage.params[@"x-oss-signature"]]);
    XCTAssertTrue([requestMessage.params[@"x-oss-additional-headers"] isEqualToString:@"abc;zabc"]);
}
@end
