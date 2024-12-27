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
#import <AliyunOSSiOS/OSSV4Signer.h>
#import <AliyunOSSiOS/NSData+OSS.h>
#import <AliyunOSSiOS/OSSServiceSignature.h>
#import "OSSTestMacros.h"

@interface OSSSingerTest : XCTestCase

@end

@implementation OSSSingerTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [NSDate oss_setClockSkew:0];
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
    
    NSString *authPat = @"OSS4-HMAC-SHA256 Credential=ak/20231216/cn-hangzhou/oss/aliyun_v4_request,Signature=ce55e10e546688b0f2d388823029de98a79fbec965a1bf33af6d1bc9f4924086";
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
    
    NSString *authPat = @"OSS4-HMAC-SHA256 Credential=ak/20231216/cn-hangzhou/oss/aliyun_v4_request,Signature=1e41b26716487a1d8c671b8c5fa6041893473cd12d82c1e60830511f5077bf08";
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
    
    NSString *authPat = @"OSS4-HMAC-SHA256 Credential=ak/20231216/cn-hangzhou/oss/aliyun_v4_request,Signature=1e41b26716487a1d8c671b8c5fa6041893473cd12d82c1e60830511f5077bf08";
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
    OSSTask *task = [signer sign:requestMessage];
    
    XCTAssertNotNil(task.error);
    XCTAssertEqual(task.error.code, OSSClientErrorCodeSignFailed);
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
    
    NSString *authPat = @"OSS4-HMAC-SHA256 Credential=ak/20231216/cn-hangzhou/oss/aliyun_v4_request,AdditionalHeaders=abc;zabc,Signature=efcf972876edadf27b15c3d80fa74849370ea6bc2b0b1aa5851b8c30dc156300";
    XCTAssertTrue([authPat isEqualToString:requestMessage.headerParams[OSSHttpHeaderAuthorization]]);
    
    // 2
    signHeaders = [NSMutableSet new];
    [signHeaders addObject:@"abc"];
    [signHeaders addObject:@"ZAbc"];
    [signHeaders addObject:@"x-oss-head1"];
    [signHeaders addObject:@"x-oss-no-exist"];

    requestMessage = [OSSAllRequestNeededMessage new];
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
    XCTAssertTrue([@"b6f0296b6a9ec01e89296e300652fa886c47951d2fa654b860c470e8ebb193d0" isEqualToString:requestMessage.params[@"x-oss-signature"]]);
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
    XCTAssertTrue([@"8a7383424297ae9d6daa7b4f818513ba5615e2e9b23734e556d812ea8aed2017" isEqualToString:requestMessage.params[@"x-oss-signature"]]);
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
    OSSTask *task = [signer presign:requestMessage];
    XCTAssertNotNil(task.error);
    XCTAssertEqual(task.error.code, OSSClientErrorCodeSignFailed);
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
    XCTAssertTrue([@"e701fe88e85a733651fa9cd46e3ade7855c5535703b526e00906886ca62b3db8" isEqualToString:requestMessage.params[@"x-oss-signature"]]);
    XCTAssertTrue([requestMessage.params[@"x-oss-additional-headers"] isEqualToString:@"abc;zabc"]);
    
    // 2
    signHeaders = [NSMutableSet new];
    [signHeaders addObject:@"abc"];
    [signHeaders addObject:@"ZAbc"];
    [signHeaders addObject:@"x-oss-head1"];
    [signHeaders addObject:@"x-oss-no-exist"];

    requestMessage = [OSSAllRequestNeededMessage new];
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
    XCTAssertTrue([@"e701fe88e85a733651fa9cd46e3ade7855c5535703b526e00906886ca62b3db8" isEqualToString:requestMessage.params[@"x-oss-signature"]]);
    XCTAssertTrue([requestMessage.params[@"x-oss-additional-headers"] isEqualToString:@"abc;zabc"]);
}

- (void)testAA {
    
//    id<OSSCredentialProvider> credentialProvider = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:@"ak" secretKeyId:@"secretKey" securityToken:@"token"];
//    OSSFederationToken *token = [OSSFederationToken new];
//    token.tSecretKey = @"secretKey";
//
//    OSSSignerParams *signerParam = [OSSSignerParams new];
//    signerParam.credentialProvider = credentialProvider;
//    signerParam.resourcePath = @"";
//    signerParam.product = @"oss";
//    signerParam.region = @"cn-hangzhou";
//
//    OSSV4Signer *signer = [[OSSV4Signer alloc] init];
//    [signer initRequestDateTime];
//    NSLog(@"oss: %@", [[signer buildSigningKey:token] hexString]);
    
    HmacSHA256Signature *s = [HmacSHA256Signature new];
    NSData *d = [s computeHash:[@"key" dataUsingEncoding:NSUTF8StringEncoding] data:[@"data" dataUsingEncoding:NSUTF8StringEncoding]];
    NSLog(@"oss: %@", [d hexString]);
}

@end
