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

- (void)testAPI_verifyStrict
{
    NSURL * fileURL = [[NSBundle mainBundle] URLForResource:@"hasky" withExtension:@"jpeg"];
    NSString *objectKey = @"?测\r试-中.~,+\"'*&￥#@%！（文）+字符|？/.zip";
    NSString *bucketName = [NSString stringWithFormat:@"verifystrict-%ld", @([[NSDate date] timeIntervalSince1970]).integerValue];
    
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    OSSAuthCredentialProvider *authProv = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                               credentialProvider:authProv
                              clientConfiguration:config];
    XCTAssertTrue(config.isVerifyObjectStrictEnable);
    
    OSSCreateBucketRequest *createBucket = [OSSCreateBucketRequest new];
    createBucket.bucketName = bucketName;
    [[client createBucket:createBucket] waitUntilFinished];
    
    OSSPutObjectRequest * putRequest = [OSSPutObjectRequest new];
    putRequest.bucketName = bucketName;
    putRequest.objectKey = objectKey;
    putRequest.uploadingFileURL = fileURL;
    OSSTask *task = [client putObject:putRequest];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);

    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = bucketName;
    request.objectKey = objectKey;
    task = [client getObject:request];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);

    config = [OSSClientConfiguration new];
    config.isVerifyObjectStrictEnable = NO;
    client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                               credentialProvider:authProv
                              clientConfiguration:config];
    XCTAssertFalse(config.isVerifyObjectStrictEnable);
    
    putRequest = [OSSPutObjectRequest new];
    putRequest.bucketName = bucketName;
    putRequest.objectKey = objectKey;
    putRequest.uploadingFileURL = fileURL;
    task = [client putObject:putRequest];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);

    request = [OSSGetObjectRequest new];
    request.bucketName = bucketName;
    request.objectKey = objectKey;
    task = [client getObject:request];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);
}

- (void)testAPI_verifyStrictWithPresign {
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    OSSAuthCredentialProvider *authProv = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                               credentialProvider:authProv
                              clientConfiguration:config];
    XCTAssertTrue(config.isVerifyObjectStrictEnable);
    
    NSString *bucketName = @"verifyStrictWithPresign";
    NSTimeInterval expiration = 60;
    NSString *objectKey = @"123";
    OSSTask *task = [client presignConstrainURLWithBucketName:bucketName
                                                withObjectKey:objectKey
                                       withExpirationInterval:expiration];
    XCTAssertNil(task.error);
    task = [client presignPublicURLWithBucketName:bucketName
                                    withObjectKey:objectKey];
    XCTAssertNil(task.error);
    
    objectKey = @"?123";
    task = [client presignConstrainURLWithBucketName:bucketName
                                       withObjectKey:objectKey
                              withExpirationInterval:expiration];
    XCTAssertNotNil(task.error);
    XCTAssertTrue([task.error.userInfo[@"ErrorMessage"] isEqualToString:@"Object key invalid"]);
    task = [client presignPublicURLWithBucketName:bucketName
                                    withObjectKey:objectKey];
    XCTAssertNotNil(task.error);
    XCTAssertTrue([task.error.userInfo[@"ErrorMessage"] isEqualToString:@"Object key invalid"]);
    
    objectKey = @"?";
    task = [client presignConstrainURLWithBucketName:bucketName
                                       withObjectKey:objectKey
                              withExpirationInterval:expiration];
    XCTAssertNotNil(task.error);
    XCTAssertTrue([task.error.userInfo[@"ErrorMessage"] isEqualToString:@"Object key invalid"]);
    task = [client presignPublicURLWithBucketName:bucketName
                                    withObjectKey:objectKey];
    XCTAssertNotNil(task.error);
    XCTAssertTrue([task.error.userInfo[@"ErrorMessage"] isEqualToString:@"Object key invalid"]);
    
    
    config = [OSSClientConfiguration new];
    config.isVerifyObjectStrictEnable = false;
    client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                               credentialProvider:authProv
                              clientConfiguration:config];
    XCTAssertFalse(config.isVerifyObjectStrictEnable);
    objectKey = @"123";
    task = [client presignConstrainURLWithBucketName:bucketName
                                                withObjectKey:objectKey
                                       withExpirationInterval:expiration];
    XCTAssertNil(task.error);
    task = [client presignPublicURLWithBucketName:bucketName
                                    withObjectKey:objectKey];
    XCTAssertNil(task.error);
    
    objectKey = @"?123";
    task = [client presignConstrainURLWithBucketName:bucketName
                                       withObjectKey:objectKey
                              withExpirationInterval:expiration];
    XCTAssertNil(task.error);
    task = [client presignPublicURLWithBucketName:bucketName
                                    withObjectKey:objectKey];
    XCTAssertNil(task.error);
    
    objectKey = @"?";
    task = [client presignConstrainURLWithBucketName:bucketName
                                       withObjectKey:objectKey
                              withExpirationInterval:expiration];
    XCTAssertNil(task.error);
    task = [client presignPublicURLWithBucketName:bucketName
                                    withObjectKey:objectKey];
    XCTAssertNil(task.error);    
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
    NSString *objectKey = @"signerV4";
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
        NSString *signature = [result hexString];
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
    XCTAssertNil(task.error);

    get = [OSSGetObjectRequest new];
    get.bucketName = bucketName;
    get.objectKey = objectKey;
    task = [client getObject:get];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    [OSSTestUtils cleanBucket:bucketName with:client];
}

@end
