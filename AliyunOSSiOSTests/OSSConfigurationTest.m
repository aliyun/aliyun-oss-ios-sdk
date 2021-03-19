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
    NSString *bucketEndpoint;
}

@end

@implementation OSSConfigurationTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    host = @"oss-cn-beijing.aliyuncs.com";
    scheme = @"https://";
    endpoint = [NSString stringWithFormat:@"%@%@", scheme, host];
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
        XCTAssertTrue([task.error.userInfo[@"BucketName"] isEqualToString:OSS_BUCKET_PUBLIC]);
        return task;
    }] waitUntilFinished];
}

- (void)testPathStyleAccessEnable {
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    config.isPathStyleAccessEnable = YES;
    OSSAuthCredentialProvider *credentialProvider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:endpoint credentialProvider:credentialProvider clientConfiguration:config];
    OSSGetObjectRequest *get = [OSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertTrue([task.error.userInfo[@"HostId"] isEqualToString:host]);
        XCTAssertTrue([task.error.userInfo[@"BucketName"] isEqualToString:OSS_BUCKET_PUBLIC]);
        return task;
    }] waitUntilFinished];
}

- (void)testSupportCnameEnable {
    NSArray *cnameExcludeList = @[host];
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    config.isSupportCnameEnable = YES;
    config.cnameExcludeList = cnameExcludeList;
    OSSAuthCredentialProvider *credentialProvider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:endpoint credentialProvider:credentialProvider clientConfiguration:config];
    OSSGetObjectRequest *get = [OSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertTrue([task.error.userInfo[@"HostId"] isEqualToString:bucketEndpoint]);
        XCTAssertTrue([task.error.userInfo[@"BucketName"] isEqualToString:OSS_BUCKET_PUBLIC]);
        return task;
    }] waitUntilFinished];
}

- (void)testSupportCnameEnableWithNullCnameExcludeList {
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    config.isSupportCnameEnable = YES;
    OSSAuthCredentialProvider *credentialProvider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:endpoint credentialProvider:credentialProvider clientConfiguration:config];
    OSSGetObjectRequest *get = [OSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertTrue([task.error.userInfo[@"HostId"] isEqualToString:host]);
        XCTAssertTrue([task.error.userInfo[@"BucketName"] isEqualToString:OSS_MULTIPART_UPLOADKEY]);
        return task;
    }] waitUntilFinished];
}

- (void)testCustomPathPrefixEnable {
    NSString *endpointPath = [NSString stringWithFormat:@"%@/%@", endpoint, OSS_BUCKET_PUBLIC];
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    config.isCustomPathPrefixEnable = YES;
    config.isSupportCnameEnable = YES;
    OSSAuthCredentialProvider *credentialProvider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:endpointPath credentialProvider:credentialProvider clientConfiguration:config];
    OSSGetObjectRequest *get = [OSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertTrue([task.error.userInfo[@"HostId"] isEqualToString:host]);
        XCTAssertTrue([task.error.userInfo[@"BucketName"] isEqualToString:OSS_BUCKET_PUBLIC]);
        return task;
    }] waitUntilFinished];
}

- (void)testCustomPathPrefixEnableWithNoPathEndpont {
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    config.isCustomPathPrefixEnable = YES;
    config.isSupportCnameEnable = YES;
    OSSAuthCredentialProvider *credentialProvider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:endpoint credentialProvider:credentialProvider clientConfiguration:config];
    OSSGetObjectRequest *get = [OSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertTrue([task.error.userInfo[@"HostId"] isEqualToString:host]);
        XCTAssertTrue([task.error.userInfo[@"BucketName"] isEqualToString:OSS_MULTIPART_UPLOADKEY]);
        return task;
    }] waitUntilFinished];
}

- (void)testCustomPathPrefixEnableWithNullObject {
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    OSSAuthCredentialProvider *credentialProvider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:endpoint credentialProvider:credentialProvider clientConfiguration:config];
    OSSGetBucketRequest *get = [OSSGetBucketRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    [[[client getBucket:get] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertTrue([task.error.userInfo[@"HostId"] isEqualToString:bucketEndpoint]);
        return task;
    }] waitUntilFinished];
}

@end
