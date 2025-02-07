//
//  OSSConfigurationTest.m
//  AliyunOSSiOSTests
//
//  Created by ws on 2021/3/17.
//  Copyright © 2021 aliyun. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import <AliyunOSSiOS/OSSServiceSignature.h>
#import <AliyunOSSiOS/NSData+OSS.h>
#import "OSSTestMacros.h"
#import "OSSTestUtils.h"

@interface OSSConfigurationTest : XCTestCase {
    NSString *host;
    NSString *scheme;
    NSString *endpoint;
    NSString *cname;
    NSString *cnameEndpoint;
    NSString *bucketEndpoint;
}

@end

@implementation OSSConfigurationTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    host = @"oss-cn-beijing.aliyuncs.com";
    cname = @"oss.cname.com";
    scheme = @"https://";
    endpoint = [NSString stringWithFormat:@"%@%@", scheme, host];
    cnameEndpoint = [NSString stringWithFormat:@"%@%@", scheme, cname];
    bucketEndpoint = [NSString stringWithFormat:@"%@.%@", OSS_BUCKET_PUBLIC, host];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testDefault {
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    OSSAuthCredentialProvider *credentialProvider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:endpoint credentialProvider:credentialProvider clientConfiguration:config];
    OSSGetObjectRequest *get = [OSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertTrue([task.error.userInfo[@"HostId"] isEqualToString:bucketEndpoint]);
        XCTAssertTrue([task.error.userInfo[@"Bucket"] isEqualToString:OSS_BUCKET_PUBLIC]);
        return task;
    }] waitUntilFinished];
}

- (void)testPathStyleAccessEnable {
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    config.maxRetryCount = 0;
    config.isPathStyleAccessEnable = YES;
    config.cnameExcludeList = @[cname];
    OSSAuthCredentialProvider *credentialProvider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:cnameEndpoint credentialProvider:credentialProvider clientConfiguration:config];
    OSSGetObjectRequest *get = [OSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNotNil(task.error);
        NSString *url = [NSString stringWithFormat:@"%@%@/%@/%@", scheme, cname, OSS_BUCKET_PUBLIC, OSS_MULTIPART_UPLOADKEY];
        XCTAssertTrue([task.error.userInfo[@"NSErrorFailingURLStringKey"] isEqualToString:url]);
        return task;
    }] waitUntilFinished];
}

- (void)testSupportCnameEnable {
    NSArray *cnameExcludeList = @[cname];
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    config.maxRetryCount = 0;
    config.cnameExcludeList = cnameExcludeList;
    OSSAuthCredentialProvider *credentialProvider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:cnameEndpoint credentialProvider:credentialProvider clientConfiguration:config];
    OSSGetObjectRequest *get = [OSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNotNil(task.error);
        NSString *url = [NSString stringWithFormat:@"%@%@.%@/%@", scheme, OSS_BUCKET_PUBLIC, cname, OSS_MULTIPART_UPLOADKEY];
        XCTAssertTrue([task.error.userInfo[@"NSErrorFailingURLStringKey"] isEqualToString:url]);
        return task;
    }] waitUntilFinished];
    
    config = [OSSClientConfiguration new];
    config.maxRetryCount = 0;
    client = [[OSSClient alloc] initWithEndpoint:cnameEndpoint credentialProvider:credentialProvider clientConfiguration:config];
    get = [OSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNotNil(task.error);
        NSString *url = [NSString stringWithFormat:@"%@%@/%@", scheme, cname, OSS_MULTIPART_UPLOADKEY];
        XCTAssertTrue([task.error.userInfo[@"NSErrorFailingURLStringKey"] isEqualToString:url]);
        return task;
    }] waitUntilFinished];
}

- (void)testCustomPathPrefixEnable {
    NSString *endpointPath = [NSString stringWithFormat:@"%@/%@", cnameEndpoint, OSS_BUCKET_PUBLIC];
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    config.maxRetryCount = 0;
    config.isCustomPathPrefixEnable = YES;
    OSSAuthCredentialProvider *credentialProvider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:endpointPath credentialProvider:credentialProvider clientConfiguration:config];
    OSSGetObjectRequest *get = [OSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNotNil(task.error);
        NSString *url = [NSString stringWithFormat:@"%@/%@", endpointPath, OSS_MULTIPART_UPLOADKEY];
        XCTAssertTrue([task.error.userInfo[@"NSErrorFailingURLStringKey"] isEqualToString:url]);
        return task;
    }] waitUntilFinished];
}

- (void)testCustomPathPrefixEnableWithNoPathEndpont {
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    config.maxRetryCount = 0;
    config.isCustomPathPrefixEnable = YES;
    OSSAuthCredentialProvider *credentialProvider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:cnameEndpoint credentialProvider:credentialProvider clientConfiguration:config];
    OSSGetObjectRequest *get = [OSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNotNil(task.error);
        NSString *url = [NSString stringWithFormat:@"%@/%@", cnameEndpoint, OSS_MULTIPART_UPLOADKEY];
        XCTAssertTrue([task.error.userInfo[@"NSErrorFailingURLStringKey"] isEqualToString:url]);
        return task;
    }] waitUntilFinished];
}

- (void)testCustomPathPrefixEnableWithNullObject {
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    config.maxRetryCount = 0;
    OSSAuthCredentialProvider *credentialProvider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:cnameEndpoint credentialProvider:credentialProvider clientConfiguration:config];
    OSSGetBucketRequest *get = [OSSGetBucketRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    [[[client getBucket:get] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNotNil(task.error);
        XCTAssertTrue([task.error.userInfo[@"NSErrorFailingURLStringKey"] isEqualToString:[cnameEndpoint stringByAppendingString:@"/"]]);
        return task;
    }] waitUntilFinished];
}

- (void)testAllowNetworkMetricInfo {
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    OSSAuthCredentialProvider *credentialProvider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:credentialProvider clientConfiguration:config];
    
    NSString *privateBucketName = [OSSTestUtils getBucketName];
    OSSCreateBucketRequest *createBucket = [OSSCreateBucketRequest new];
    createBucket.bucketName = privateBucketName;
    OSSTask *task = [client createBucket:createBucket];
    [task waitUntilFinished];
    XCTAssertNil(((OSSResult *)task.result).metrics);

    OSSPutObjectRequest * put = [OSSPutObjectRequest new];
    put.bucketName = privateBucketName;
    put.objectKey = OSS_IMAGE_KEY;
    put.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"hasky" withExtension:@"jpeg"];
    task = [client putObject:put];
    [task waitUntilFinished];
    XCTAssertNil(((OSSResult *)task.result).metrics);
    
    OSSGetObjectRequest *get = [OSSGetObjectRequest new];
    get.bucketName = privateBucketName;
    get.objectKey = @"error";
    get.onRecieveData = ^(NSData * _Nonnull data) {
    };
    task = [client getObject:get];
    [task waitUntilFinished];
    XCTAssertNil(task.error.userInfo[OSSNetworkTaskMetrics]);
    
    config = [OSSClientConfiguration new];
    config.isAllowNetworkMetricInfo = YES;
    client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:credentialProvider clientConfiguration:config];
    
    put = [OSSPutObjectRequest new];
    put.bucketName = privateBucketName;
    put.objectKey = OSS_IMAGE_KEY;
    put.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"hasky" withExtension:@"jpeg"];
    task = [client putObject:put];
    [task waitUntilFinished];
    XCTAssertNotNil(((OSSResult *)task.result).metrics);
    
    get = [OSSGetObjectRequest new];
    get.bucketName = privateBucketName;
    get.objectKey = @"error";
    get.onRecieveData = ^(NSData * _Nonnull data) {
    };
    task = [client getObject:get];
    [task waitUntilFinished];
    XCTAssertNotNil(task.error.userInfo[OSSNetworkTaskMetrics]);
    
    [OSSTestUtils cleanBucket:privateBucketName with:client];
}

- (void)testAPI_signerV1 {
    NSString *bucketName = [@"test-signerv1-" stringByAppendingFormat:@"%@", @((NSInteger)[NSDate new].timeIntervalSince1970)];
    NSString *objectKey = @"signerV1";
    NSURL * fileURL = [[NSBundle mainBundle] URLForResource:@"hasky" withExtension:@"jpeg"];

    OSSClientConfiguration *config = [OSSClientConfiguration new];
    config.signVersion = OSSSignVersionV1;
    
    // OSSPlainTextAKSKPairCredentialProvider
    id<OSSCredentialProvider> credentialProvider = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:OSS_ACCESSKEY_ID
                                                                                                                    secretKey:OSS_SECRETKEY_ID];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:endpoint
                                         credentialProvider:credentialProvider
                                        clientConfiguration:config];
    
    OSSCreateBucketRequest *createBucketRequest = [OSSCreateBucketRequest new];
    createBucketRequest.bucketName = bucketName;
    OSSTask *task = [client createBucket:createBucketRequest];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    OSSPutObjectRequest *putObjectRequest = [OSSPutObjectRequest new];
    putObjectRequest.bucketName = bucketName;
    putObjectRequest.objectKey = objectKey;
    putObjectRequest.uploadingFileURL = fileURL;
    task = [client putObject:putObjectRequest];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    OSSGetObjectRequest *get = [OSSGetObjectRequest new];
    get.bucketName = bucketName;
    get.objectKey = objectKey;
    task = [client getObject:get];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    // OSSStsTokenCredentialProvider
    OSSFederationToken *federationToken = [OSSTestUtils getOssFederationToken];
    credentialProvider = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:federationToken.tAccessKey
                                                                        secretKeyId:federationToken.tSecretKey
                                                                      securityToken:federationToken.tToken];
    client = [[OSSClient alloc] initWithEndpoint:endpoint
                              credentialProvider:credentialProvider
                             clientConfiguration:config];
    
    putObjectRequest = [OSSPutObjectRequest new];
    putObjectRequest.bucketName = bucketName;
    putObjectRequest.objectKey = objectKey;
    putObjectRequest.uploadingFileURL = fileURL;
    task = [client putObject:putObjectRequest];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    get = [OSSGetObjectRequest new];
    get.bucketName = bucketName;
    get.objectKey = objectKey;
    task = [client getObject:get];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    
    // OSSFederationCredentialProvider
    credentialProvider = [[OSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^OSSFederationToken * _Nullable{
        return [OSSTestUtils getOssFederationToken];
    }];
    client = [[OSSClient alloc] initWithEndpoint:endpoint
                              credentialProvider:credentialProvider
                             clientConfiguration:config];
    
    putObjectRequest = [OSSPutObjectRequest new];
    putObjectRequest.bucketName = bucketName;
    putObjectRequest.objectKey = objectKey;
    putObjectRequest.uploadingFileURL = fileURL;
    task = [client putObject:putObjectRequest];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    get = [OSSGetObjectRequest new];
    get.bucketName = bucketName;
    get.objectKey = objectKey;
    task = [client getObject:get];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    
    // OSSCustomSignerCredentialProvider
    credentialProvider = [[OSSCustomSignerCredentialProvider alloc] initWithImplementedSigner:^NSString * _Nullable(NSString * _Nonnull contentToSign, NSError *__autoreleasing  _Nullable * _Nullable error) {
        NSString *signature = [OSSUtil calBase64Sha1WithData:contentToSign withSecret:OSS_SECRETKEY_ID];
        XCTAssertNotNil(signature);
        return [NSString stringWithFormat:@"OSS %@:%@", OSS_ACCESSKEY_ID, signature];
    }];
    client = [[OSSClient alloc] initWithEndpoint:endpoint
                              credentialProvider:credentialProvider
                             clientConfiguration:config];
    
    putObjectRequest = [OSSPutObjectRequest new];
    putObjectRequest.bucketName = bucketName;
    putObjectRequest.objectKey = objectKey;
    putObjectRequest.uploadingFileURL = fileURL;
    task = [client putObject:putObjectRequest];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    get = [OSSGetObjectRequest new];
    get.bucketName = bucketName;
    get.objectKey = objectKey;
    task = [client getObject:get];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    [OSSTestUtils cleanBucket:bucketName with:client];
}

- (void)testAPI_signerV4 {
    NSString *bucketName = [@"test-signerv4-" stringByAppendingFormat:@"%@", @((NSInteger)[NSDate new].timeIntervalSince1970)];
    NSString *objectKey = @"signerV4/!@#$%^&*()_=\\|';:><[.-+]{}?\"~`";
    NSURL * fileURL = [[NSBundle mainBundle] URLForResource:@"hasky" withExtension:@"jpeg"];
    NSString *endpoint = OSS_ENDPOINT;

    OSSClientConfiguration *config = [OSSClientConfiguration new];
    config.signVersion = OSSSignVersionV4;
    
    // OSSPlainTextAKSKPairCredentialProvider
    id<OSSCredentialProvider> credentialProvider = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:OSS_ACCESSKEY_ID
                                                                                                                    secretKey:OSS_SECRETKEY_ID];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:endpoint
                                         credentialProvider:credentialProvider
                                        clientConfiguration:config];
    client.region = OSS_REGION;
    
    OSSCreateBucketRequest *createBucketRequest = [OSSCreateBucketRequest new];
    createBucketRequest.bucketName = bucketName;
    OSSTask *task = [client createBucket:createBucketRequest];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    OSSPutObjectRequest *putObjectRequest = [OSSPutObjectRequest new];
    putObjectRequest.bucketName = bucketName;
    putObjectRequest.objectKey = objectKey;
    putObjectRequest.uploadingFileURL = fileURL;
    task = [client putObject:putObjectRequest];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    OSSGetObjectRequest *get = [OSSGetObjectRequest new];
    get.bucketName = bucketName;
    get.objectKey = objectKey;
    task = [client getObject:get];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    // OSSStsTokenCredentialProvider
    OSSFederationToken *federationToken = [OSSTestUtils getOssFederationToken];
    credentialProvider = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:federationToken.tAccessKey
                                                                        secretKeyId:federationToken.tSecretKey
                                                                      securityToken:federationToken.tToken];
    client = [[OSSClient alloc] initWithEndpoint:endpoint
                              credentialProvider:credentialProvider
                             clientConfiguration:config];
    client.region = OSS_REGION;
    
    putObjectRequest = [OSSPutObjectRequest new];
    putObjectRequest.bucketName = bucketName;
    putObjectRequest.objectKey = objectKey;
    putObjectRequest.uploadingFileURL = fileURL;
    task = [client putObject:putObjectRequest];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    get = [OSSGetObjectRequest new];
    get.bucketName = bucketName;
    get.objectKey = objectKey;
    task = [client getObject:get];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    
    // OSSFederationCredentialProvider
    credentialProvider = [[OSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^OSSFederationToken * _Nullable{
        return [OSSTestUtils getOssFederationToken];
    }];
    client = [[OSSClient alloc] initWithEndpoint:endpoint
                              credentialProvider:credentialProvider
                             clientConfiguration:config];
    client.region = OSS_REGION;

    putObjectRequest = [OSSPutObjectRequest new];
    putObjectRequest.bucketName = bucketName;
    putObjectRequest.objectKey = objectKey;
    putObjectRequest.uploadingFileURL = fileURL;
    task = [client putObject:putObjectRequest];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    get = [OSSGetObjectRequest new];
    get.bucketName = bucketName;
    get.objectKey = objectKey;
    task = [client getObject:get];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    
    // OSSCustomSignerCredentialProvider
    credentialProvider = [[OSSCustomSignerCredentialProvider alloc] initWithImplementedSigner:^NSString * _Nullable(NSString * _Nonnull contentToSign, NSError *__autoreleasing  _Nullable * _Nullable error) {
        NSData *jsonData = [contentToSign dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *content = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                options:NSJSONReadingMutableContainers
                                                                  error:error];
        NSString *date = content[OSSContentDate];
        NSString *region = content[OSSContentRegion];
        NSString *product = content[OSSContentProduct];
        NSString *stringToSign = content[OSSContentStringToSign];
        id<OSSServiceSignature> serviceSignature = [HmacSHA256Signature new];
        NSData *signingSecret = [[@"aliyun_v4" stringByAppendingString:OSS_SECRETKEY_ID] dataUsingEncoding:NSUTF8StringEncoding];
        NSData *signingDate = [serviceSignature computeHash:signingSecret
                                                       data:[date dataUsingEncoding:NSUTF8StringEncoding]];
        NSData *signingRegion = [serviceSignature computeHash:signingDate
                                                         data:[region dataUsingEncoding:NSUTF8StringEncoding]];
        NSData *signingService = [serviceSignature computeHash:signingRegion
                                                          data:[product dataUsingEncoding:NSUTF8StringEncoding]];
        NSData *signingKey =[serviceSignature computeHash:signingService
                                                     data:[@"aliyun_v4_request" dataUsingEncoding:NSUTF8StringEncoding]];
        NSData *result = [serviceSignature computeHash:signingKey
                                                  data:[stringToSign dataUsingEncoding:NSUTF8StringEncoding]];
        NSString *signature = [result oss_hexString];
        NSString *credential = [NSString stringWithFormat:@"Credential=%@/%@/%@/%@/aliyun_v4_request", OSS_ACCESSKEY_ID, date, region, product];
        NSString *signedHeaders = @"";
        NSString *sign = [NSString stringWithFormat:@",Signature=%@", signature];
        return [NSString stringWithFormat:@"OSS4-HMAC-SHA256 %@%@%@", credential, signedHeaders, sign];
    }];
    client = [[OSSClient alloc] initWithEndpoint:endpoint
                              credentialProvider:credentialProvider
                             clientConfiguration:config];
    client.region = OSS_REGION;

    putObjectRequest = [OSSPutObjectRequest new];
    putObjectRequest.bucketName = bucketName;
    putObjectRequest.objectKey = objectKey;
    putObjectRequest.uploadingFileURL = fileURL;
    task = [client putObject:putObjectRequest];
    [task waitUntilFinished];
    XCTAssertNotNil(task.error);
    XCTAssertTrue([task.error.userInfo[OSSErrorMessageTOKEN] isEqualToString:@"V4 signature does not support OSSCustomSignerCredentialProvider"]);

    get = [OSSGetObjectRequest new];
    get.bucketName = bucketName;
    get.objectKey = objectKey;
    task = [client getObject:get];
    [task waitUntilFinished];
    XCTAssertNotNil(task.error);
    XCTAssertTrue([task.error.userInfo[OSSErrorMessageTOKEN] isEqualToString:@"V4 signature does not support OSSCustomSignerCredentialProvider"]);

    [OSSTestUtils cleanBucket:bucketName with:client];
}

@end
