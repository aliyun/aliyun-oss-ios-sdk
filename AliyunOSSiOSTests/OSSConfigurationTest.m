//
//  OSSConfigurationTest.m
//  AliyunOSSiOSTests
//
//  Created by ws on 2021/3/17.
//  Copyright © 2021 aliyun. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import "OSSTestMacros.h"

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

@end
