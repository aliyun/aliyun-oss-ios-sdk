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
    NSTimeInterval t = 1702743657.0L;
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
    
    NSString *authPat = @"OSS4-HMAC-SHA256 Credential=ak/20231216/cn-hangzhou/oss/aliyun_v4_request,Signature=e21d18daa82167720f9b1047ae7e7f1ce7cb77a31e8203a7d5f4624fa0284afe";
    XCTAssertTrue([authPat isEqualToString:requestMessage.headerParams[OSSHttpHeaderAuthorization]]);
}

- (void)test_singerWithSignerV4Token {
    OSSSignVersion version = OSSSignVersionV4;
    
    id<OSSCredentialProvider> credentialProvider = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:@"ak" secretKeyId:@"sk" securityToken:@"token"];
    
    NSString *bucket = @"bucket";
    NSString *key = @"1234+-/123/1.txt";
    NSString *region = @"cn-hangzhou";
    NSString *product = @"oss";
    NSTimeInterval t = 1702784856.0L;
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
    
    NSString *authPat = @"OSS4-HMAC-SHA256 Credential=ak/20231217/cn-hangzhou/oss/aliyun_v4_request,Signature=b94a3f999cf85bcdc00d332fbd3734ba03e48382c36fa4d5af5df817395bd9ea";
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
    NSTimeInterval t = 1702784856.0L;
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
    
    NSString *authPat = @"OSS4-HMAC-SHA256 Credential=ak/20231217/cn-hangzhou/oss/aliyun_v4_request,Signature=b94a3f999cf85bcdc00d332fbd3734ba03e48382c36fa4d5af5df817395bd9ea";
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
    
    id<OSSCredentialProvider> credentialProvider = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:@"ak" secretKey:@"sk"];
    
    NSString *bucket = @"bucket";
    NSString *key = @"1234+-/123/1.txt";
    NSString *region = @"cn-hangzhou";
    NSString *product = @"oss";
    NSTimeInterval t = 1702747512.0L;
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
    
    NSString *authPat = @"OSS4-HMAC-SHA256 Credential=ak/20231216/cn-hangzhou/oss/aliyun_v4_request,AdditionalHeaders=abc;zabc,Signature=4a4183c187c07c8947db7620deb0a6b38d9fbdd34187b6dbaccb316fa251212f";
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

- (void)test_signerV4WithAdditionalHeadersByToken {
    OSSSignVersion version = OSSSignVersionV4;
    
    id<OSSCredentialProvider> credentialProvider = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:@"ak" secretKeyId:@"sk" securityToken:@"token"];
    
    NSString *bucket = @"bucket";
    NSString *key = @"1234+-/123/1.txt";
    NSString *region = @"cn-hangzhou";
    NSString *product = @"oss";
    NSTimeInterval t = 1702747512.0L;
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
    
    NSString *authPat = @"OSS4-HMAC-SHA256 Credential=ak/20231216/cn-hangzhou/oss/aliyun_v4_request,AdditionalHeaders=abc;zabc,Signature=203120400fdac93fd2f87640e5071f19de7c4561090e8a5fcffbe7d1ef89e073";
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
    NSTimeInterval t = 1702781677.0L;
    [NSDate oss_setClockSkew:[NSDate new].timeIntervalSince1970 - t];
    
    NSMutableDictionary *headers = @{}.mutableCopy;
    NSMutableDictionary *parameters = @{}.mutableCopy;

    headers[@"x-oss-head1"] = @"value";
    headers[@"abc"] = @"value";
    headers[@"ZAbc"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"content-type"] = @"application/octet-stream";
    
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
    XCTAssertTrue([@"20231217T025437Z" isEqualToString:requestMessage.params[@"x-oss-date"]]);
    XCTAssertTrue([@"599" isEqualToString:requestMessage.params[@"x-oss-expires"]]);
    XCTAssertTrue([@"ak/20231217/cn-hangzhou/oss/aliyun_v4_request" isEqualToString:requestMessage.params[@"x-oss-credential"]]);
    XCTAssertTrue([@"a39966c61718be0d5b14e668088b3fa07601033f6518ac7b523100014269c0fe" isEqualToString:requestMessage.params[@"x-oss-signature"]]);
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
    NSTimeInterval t = 1702785388.0L;
    [NSDate oss_setClockSkew:[NSDate new].timeIntervalSince1970 - t];
    
    NSMutableDictionary *headers = @{}.mutableCopy;
    NSMutableDictionary *parameters = @{}.mutableCopy;

    headers[@"x-oss-head1"] = @"value";
    headers[@"abc"] = @"value";
    headers[@"ZAbc"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"content-type"] = @"application/octet-stream";
    
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
    XCTAssertTrue([@"20231217T035628Z" isEqualToString:requestMessage.params[@"x-oss-date"]]);
    XCTAssertTrue([@"599" isEqualToString:requestMessage.params[@"x-oss-expires"]]);
    XCTAssertTrue([@"ak/20231217/cn-hangzhou/oss/aliyun_v4_request" isEqualToString:requestMessage.params[@"x-oss-credential"]]);
    XCTAssertTrue([@"3817ac9d206cd6dfc90f1c09c00be45005602e55898f26f5ddb06d7892e1f8b5" isEqualToString:requestMessage.params[@"x-oss-signature"]]);
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

- (void)test_presignWithAdditionalHeaders {
    OSSSignVersion version = OSSSignVersionV4;
    
    id<OSSCredentialProvider> credentialProvider = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:@"ak" secretKey:@"sk"];
    
    NSString *bucket = @"bucket";
    NSString *key = @"1234+-/123/1.txt";
    NSString *region = @"cn-hangzhou";
    NSString *product = @"oss";
    NSTimeInterval t = 1702783809.0L;
    [NSDate oss_setClockSkew:[NSDate new].timeIntervalSince1970 - t];
    
    NSMutableDictionary *headers = @{}.mutableCopy;
    NSMutableDictionary *parameters = @{}.mutableCopy;
    NSMutableSet<NSString *> *signHeaders = [NSMutableSet new];

    headers[@"x-oss-head1"] = @"value";
    headers[@"abc"] = @"value";
    headers[@"ZAbc"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"content-type"] = @"application/octet-stream";
    
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
    XCTAssertTrue([@"20231217T033009Z" isEqualToString:requestMessage.params[@"x-oss-date"]]);
    XCTAssertTrue([@"599" isEqualToString:requestMessage.params[@"x-oss-expires"]]);
    XCTAssertTrue([@"ak/20231217/cn-hangzhou/oss/aliyun_v4_request" isEqualToString:requestMessage.params[@"x-oss-credential"]]);
    XCTAssertTrue([@"6bd984bfe531afb6db1f7550983a741b103a8c58e5e14f83ea474c2322dfa2b7" isEqualToString:requestMessage.params[@"x-oss-signature"]]);
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
    XCTAssertTrue([@"20231217T033009Z" isEqualToString:requestMessage.params[@"x-oss-date"]]);
    XCTAssertTrue([@"599" isEqualToString:requestMessage.params[@"x-oss-expires"]]);
    XCTAssertTrue([@"ak/20231217/cn-hangzhou/oss/aliyun_v4_request" isEqualToString:requestMessage.params[@"x-oss-credential"]]);
    XCTAssertTrue([@"6bd984bfe531afb6db1f7550983a741b103a8c58e5e14f83ea474c2322dfa2b7" isEqualToString:requestMessage.params[@"x-oss-signature"]]);
    XCTAssertTrue([requestMessage.params[@"x-oss-additional-headers"] isEqualToString:@"abc;zabc"]);
}

- (void)test_presignWithAdditionalHeadersByToken {
    OSSSignVersion version = OSSSignVersionV4;
    
    id<OSSCredentialProvider> credentialProvider = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:@"ak" secretKeyId:@"sk" securityToken:@"token"];
    
    NSString *bucket = @"bucket";
    NSString *key = @"1234+-/123/1.txt";
    NSString *region = @"cn-hangzhou";
    NSString *product = @"oss";
    NSTimeInterval t = 1702783809.0L;
    [NSDate oss_setClockSkew:[NSDate new].timeIntervalSince1970 - t];
    
    NSMutableDictionary *headers = @{}.mutableCopy;
    NSMutableDictionary *parameters = @{}.mutableCopy;
    NSMutableSet<NSString *> *signHeaders = [NSMutableSet new];

    headers[@"x-oss-head1"] = @"value";
    headers[@"abc"] = @"value";
    headers[@"ZAbc"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"XYZ"] = @"value";
    headers[@"content-type"] = @"application/octet-stream";
    
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
    XCTAssertTrue([@"20231217T033009Z" isEqualToString:requestMessage.params[@"x-oss-date"]]);
    XCTAssertTrue([@"599" isEqualToString:requestMessage.params[@"x-oss-expires"]]);
    XCTAssertTrue([@"ak/20231217/cn-hangzhou/oss/aliyun_v4_request" isEqualToString:requestMessage.params[@"x-oss-credential"]]);
    XCTAssertTrue([@"2143a96a0e0e02889309ac8f8db57e79ffc275a0c9ebe3af676c8a1ce5635eca" isEqualToString:requestMessage.params[@"x-oss-signature"]]);
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
    XCTAssertTrue([@"20231217T033009Z" isEqualToString:requestMessage.params[@"x-oss-date"]]);
    XCTAssertTrue([@"599" isEqualToString:requestMessage.params[@"x-oss-expires"]]);
    XCTAssertTrue([@"ak/20231217/cn-hangzhou/oss/aliyun_v4_request" isEqualToString:requestMessage.params[@"x-oss-credential"]]);
    XCTAssertTrue([@"2143a96a0e0e02889309ac8f8db57e79ffc275a0c9ebe3af676c8a1ce5635eca" isEqualToString:requestMessage.params[@"x-oss-signature"]]);
    XCTAssertTrue([requestMessage.params[@"x-oss-additional-headers"] isEqualToString:@"abc;zabc"]);
}

@end
