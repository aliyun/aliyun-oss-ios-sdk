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

@end
