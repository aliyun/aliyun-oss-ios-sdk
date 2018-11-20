//
//  OSSBucketTests.m
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/12/11.
//  Copyright © 2017年 阿里云. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "OSSTestMacros.h"
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import "OSSTestUtils.h"

@interface OSSBucketTests : XCTestCase
{
    OSSClient *_client;
}

@end

@implementation OSSBucketTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [self initOSSClient];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)initOSSClient
{
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    OSSAuthCredentialProvider *authProv = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    _client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                               credentialProvider:authProv
                              clientConfiguration:config];
}

- (void)testAPI_creatBucket
{
    NSString *bucket = @"oss-ios-create-bucket-test";
    OSSCreateBucketRequest *req = [OSSCreateBucketRequest new];
    req.bucketName = bucket;
    req.xOssACL = @"public-read";
    OSSTask *task = [_client createBucket:req];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:bucket with:_client];
}

- (void)testAPI_getBucketInfo {
    NSString *bucketName = @"oss-ios-get-bucket-info-test";
    OSSCreateBucketRequest *req = [OSSCreateBucketRequest new];
    req.bucketName = bucketName;
    [[_client createBucket:req] waitUntilFinished];
    
    OSSGetBucketInfoRequest * request = [OSSGetBucketInfoRequest new];
    request.bucketName = bucketName;
    OSSTask * task = [_client getBucketInfo:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        XCTAssertNotNil(task.result);
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:bucketName with:_client];
}

- (void)testAPI_getBucketACL
{
    OSSCreateBucketRequest *req = [OSSCreateBucketRequest new];
    req.bucketName = @"oss-ios-get-bucket-acl-test";
    [[_client createBucket:req] waitUntilFinished];
    
    OSSGetBucketACLRequest * request = [OSSGetBucketACLRequest new];
    request.bucketName = @"oss-ios-get-bucket-acl-test";
    OSSTask * task = [_client getBucketACL:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetBucketACLResult * result = task.result;
        XCTAssertEqualObjects(@"private", result.aclGranted);
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:@"oss-ios-get-bucket-acl-test" with:_client];
}

- (void)testAPI_getService
{
    OSSGetServiceRequest *request = [OSSGetServiceRequest new];
    OSSTask * task = [_client getService:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_deleteBucket
{
    NSString * bucket = @"oss-ios-delete-bucket-test";
    OSSCreateBucketRequest *req = [OSSCreateBucketRequest new];
    req.bucketName = bucket;
    req.xOssACL = @"public-read";
    OSSTask *task = [_client createBucket:req];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    
    OSSDeleteBucketRequest *request = [OSSDeleteBucketRequest new];
    request.bucketName = bucket;
    task = [_client deleteBucket:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testListMultipartUploads
{
    OSSCreateBucketRequest *req = [OSSCreateBucketRequest new];
    req.bucketName = @"oss-ios-bucket-list-multipart-uploads-test";
    [[_client createBucket:req] waitUntilFinished];
    
    OSSListMultipartUploadsRequest *listreq = [OSSListMultipartUploadsRequest new];
    listreq.bucketName = @"oss-ios-bucket-list-multipart-uploads-test";
    listreq.maxUploads = 1000;
    OSSTask *task = [_client listMultipartUploads:listreq];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSListMultipartUploadsResult * result = task.result;
        XCTAssertTrue(result.maxUploads == 1000);
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:@"oss-ios-bucket-list-multipart-uploads-test" with:_client];
}

- (void)testPutBucketACL
{
    OSSCreateBucketRequest *req = [OSSCreateBucketRequest new];
    req.bucketName = @"oss-ios-bucket-put-bucket-acl";
    [[_client createBucket:req] waitUntilFinished];
    
    OSSPutBucketACLRequest *putBucketACLReq = [[OSSPutBucketACLRequest alloc] init];
    putBucketACLReq.bucketName = @"oss-ios-bucket-put-bucket-acl";
    putBucketACLReq.aclType = OSSACLPublicRead;
    
    OSSTask *putBucketACLTask = [_client putBucketACL:putBucketACLReq];
    
    [[putBucketACLTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:@"oss-ios-bucket-put-bucket-acl" with:_client];
}

- (void)testBucketLogging
{
    OSSCreateBucketRequest *createBucketSrcReq = [OSSCreateBucketRequest new];
    createBucketSrcReq.bucketName = @"oss-ios-bucket-logging-source";
    [[_client createBucket:createBucketSrcReq] waitUntilFinished];
    
    OSSCreateBucketRequest *createBucketTargetReq = [OSSCreateBucketRequest new];
    createBucketTargetReq.bucketName = @"oss-ios-bucket-logging-bucket";
    [[_client createBucket:createBucketTargetReq] waitUntilFinished];
    
    OSSPutBucketLoggingRequest *putBucketLoggingReq = [[OSSPutBucketLoggingRequest alloc] init];
    putBucketLoggingReq.bucketName = @"oss-ios-bucket-logging-source";
    putBucketLoggingReq.targetBucketName = @"oss-ios-bucket-logging-bucket";
    putBucketLoggingReq.targetPrefix = @"oss-ios-bucket-logging-prefix";
    
    OSSTask *putBucketLoggingTask = [_client putBucketLogging:putBucketLoggingReq];
    
    [[putBucketLoggingTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    OSSGetBucketLoggingRequest *getBucketLoggingReq = [[OSSGetBucketLoggingRequest alloc] init];
    getBucketLoggingReq.bucketName = @"oss-ios-bucket-logging-source";
    
    OSSTask *getBucketLoggingTask = [_client getBucketLogging:getBucketLoggingReq];
    
    [[getBucketLoggingTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        XCTAssertNotNil(task.result);
        OSSGetBucketLoggingResult *result = (OSSGetBucketLoggingResult *)task.result;
        XCTAssertTrue(result.loggingEnabled);
        XCTAssertTrue([result.targetPrefix isEqualToString:@"oss-ios-bucket-logging-prefix"]);
        XCTAssertTrue([result.targetBucketName isEqualToString:@"oss-ios-bucket-logging-bucket"]);
        
        return nil;
    }] waitUntilFinished];
    
    OSSDeleteBucketLoggingRequest *delBucketLoggingReq = [[OSSDeleteBucketLoggingRequest alloc] init];
    delBucketLoggingReq.bucketName = @"oss-ios-bucket-logging-source";
    
    OSSTask *delBucketLoggingTask = [_client deleteBucketLogging:delBucketLoggingReq];
    
    [[delBucketLoggingTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:@"oss-ios-bucket-logging-bucket" with:_client];
    [OSSTestUtils cleanBucket:@"oss-ios-bucket-logging-source" with:_client];
}

- (void)testBucketReferer
{
    OSSCreateBucketRequest *createBucketSrcReq = [OSSCreateBucketRequest new];
    createBucketSrcReq.bucketName = @"oss-ios-sdk-test-bucket-referer";
    [[_client createBucket:createBucketSrcReq] waitUntilFinished];
    
    OSSPutBucketRefererRequest *putBucketRefererReq = [[OSSPutBucketRefererRequest alloc] init];
    putBucketRefererReq.bucketName = @"oss-ios-sdk-test-bucket-referer";
    putBucketRefererReq.allowEmpty = YES;
    putBucketRefererReq.referers = @[@"http://www.aliyun.com", @"http://www.taobao.com"];
    
    OSSTask *putBucketRefererTask = [_client putBucketReferer:putBucketRefererReq];
    
    [[putBucketRefererTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    OSSGetBucketRefererRequest *getBucketRefererReq = [[OSSGetBucketRefererRequest alloc] init];
    getBucketRefererReq.bucketName = @"oss-ios-sdk-test-bucket-referer";
    
    OSSTask *getBucketRefererTask = [_client getBucketReferer:getBucketRefererReq];
    
    [[getBucketRefererTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        XCTAssertNotNil(task.result);
        OSSGetBucketRefererResult *result = (OSSGetBucketRefererResult *)task.result;
        XCTAssertTrue(result.allowEmpty);
        XCTAssertTrue([result.referers containsObject:@"http://www.aliyun.com"]);
        XCTAssertTrue([result.referers containsObject:@"http://www.taobao.com"]);
        
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:@"oss-ios-sdk-test-bucket-referer" with:_client];
}

- (void)testBucketLifecycle
{
    NSString *lifecycle_bucket_name = @"oss-ios-sdk-test-bucket-lifecycle";
    OSSCreateBucketRequest *createBucketSrcReq = [OSSCreateBucketRequest new];
    createBucketSrcReq.bucketName = lifecycle_bucket_name;
    [[_client createBucket:createBucketSrcReq] waitUntilFinished];
    
    OSSPutBucketLifecycleRequest *putBucketLifecycleReq = [[OSSPutBucketLifecycleRequest alloc] init];
    putBucketLifecycleReq.bucketName = lifecycle_bucket_name;
    
    OSSBucketLifecycleRule *rule1 = [[OSSBucketLifecycleRule alloc] init];
    
    rule1.identifier = @"1";
    rule1.status = YES;
    rule1.prefix = @"rule1prefix";
    rule1.days = @"2";
    rule1.iaDays = @"1";
    rule1.multipartDays = @"1";
    
    OSSBucketLifecycleRule *rule2 = [[OSSBucketLifecycleRule alloc] init];
    
    rule2.identifier = @"2";
    rule2.status = YES;
    rule2.prefix = @"rule2prefix";
    rule2.days = @"3";
    rule2.iaDays = @"2";
    rule2.multipartDays = @"2";
    
    putBucketLifecycleReq.rules = @[rule1, rule2];
    
    OSSTask *putBucketLifecycleTask = [_client putBucketLifecycle:putBucketLifecycleReq];
    
    [[putBucketLifecycleTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    OSSGetBucketLifecycleRequest *getBucketLifecycleReq = [[OSSGetBucketLifecycleRequest alloc] init];
    getBucketLifecycleReq.bucketName = lifecycle_bucket_name;
    
    OSSTask *getBucketLifecycleTask = [_client getBucketLifecycle:getBucketLifecycleReq];
    
    [[getBucketLifecycleTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        
        return nil;
    }] waitUntilFinished];
    
    OSSDeleteBucketLifecycleRequest *deleteBucketLifecycleReq = [[OSSDeleteBucketLifecycleRequest alloc] init];
    deleteBucketLifecycleReq.bucketName = lifecycle_bucket_name;
    
    OSSTask *deleteBucketLifecycleTask = [_client deleteBucketLifecycle:deleteBucketLifecycleReq];
    [[deleteBucketLifecycleTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:lifecycle_bucket_name with:_client];
}

@end
