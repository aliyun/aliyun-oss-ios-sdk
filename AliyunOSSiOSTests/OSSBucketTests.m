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
    NSString *bucketName;
    int fileCount;
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
    
    OSSGetServiceResult *result = nil;
    do {
        request = [OSSGetServiceRequest new];
        request.maxKeys = 2;
        request.marker = result.nextMarker;
        task = [_client getService:request];
        [task waitUntilFinished];
        result = task.result;
    } while (result.isTruncated);
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

- (void)testGetBucketV2 {
    int fileCount = 50;
    int delimiterFileCount = 10;
    NSString *bucketName = @"oss-ios-bucket-get-bucket-test";
    NSString *delimiterPrefix = @"delimiterFile";
    NSString *prefix = @"file";
    OSSCreateBucketRequest *createRq = [OSSCreateBucketRequest new];
    createRq.bucketName = bucketName;
    [[_client createBucket:createRq] waitUntilFinished];
    
    for (int i = 0; i < fileCount; i++) {
        OSSPutObjectRequest *putRq = [OSSPutObjectRequest new];
        putRq.bucketName = bucketName;
        putRq.objectKey = [NSString stringWithFormat:@"%@%d", prefix, i];
        if (fileCount - i <= delimiterFileCount) {
            putRq.objectKey = [NSString stringWithFormat:@"%@%d", delimiterPrefix, i];
        }
        putRq.uploadingData = [self createRandomData:1024];
        [[_client putObject:putRq] waitUntilFinished];
    }
    
    OSSGetBucketV2Request *request = [OSSGetBucketV2Request new];
    request.bucketName = bucketName;
    [[[_client getBucketV2:request] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        OSSGetBucketV2Result *result = task.result;
        XCTAssertTrue(result.contents.count == fileCount);
        return nil;
    }] waitUntilFinished];
    
    
    __block int count = 0;
    __block BOOL is;
    __block NSString *nextContinuationToken;
    do {
        request = [OSSGetBucketV2Request new];
        request.bucketName = bucketName;
        request.maxKeys = 20;
        request.continuationToken = nextContinuationToken;
        [[[_client getBucketV2:request] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
            XCTAssertNil(task.error);
            OSSGetBucketV2Result *result = task.result;
            XCTAssertTrue(result.contents.count <= request.maxKeys);
            XCTAssertTrue(result.keyCount <= request.maxKeys);
            is = result.isTruncated;
            count += result.keyCount;
            nextContinuationToken = result.nextContinuationToken;
            return nil;
        }] waitUntilFinished];
    } while(is);
    XCTAssertTrue(count == fileCount);
    
    
    request = [OSSGetBucketV2Request new];
    request.bucketName = bucketName;
    request.prefix = prefix;
    [[[_client getBucketV2:request] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        OSSGetBucketV2Result *result = task.result;
        XCTAssertTrue(result.keyCount == fileCount - delimiterFileCount);
        return nil;
    }] waitUntilFinished];
    
    request = [OSSGetBucketV2Request new];
    request.bucketName = bucketName;
    request.delimiter = @"f";
    [[[_client getBucketV2:request] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        OSSGetBucketV2Result *result = task.result;
        XCTAssertTrue(result.contents.count == delimiterFileCount);
        XCTAssertTrue(result.commonPrefixes.count == 1);
        return nil;
    }] waitUntilFinished];
    
    request = [OSSGetBucketV2Request new];
    request.bucketName = bucketName;
    request.delimiter = @"i";
    [[[_client getBucketV2:request] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        OSSGetBucketV2Result *result = task.result;
        XCTAssertTrue(result.commonPrefixes.count == 2);
        return nil;
    }] waitUntilFinished];
    
    request = [OSSGetBucketV2Request new];
    request.bucketName = bucketName;
    request.startAfter = @"file10";
    [[[_client getBucketV2:request] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        OSSGetBucketV2Result *result = task.result;
        XCTAssertTrue(result.contents.count == 37);
        return nil;
    }] waitUntilFinished];
    
    request = [OSSGetBucketV2Request new];
    request.bucketName = bucketName;
    request.encodingType = @"url";
    request.prefix = @"+=";
    [[[_client getBucketV2:request] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        OSSGetBucketV2Result *result = task.result;
        XCTAssertTrue([result.prefix isEqual:[OSSUtil encodeURL:request.prefix]]);
        return nil;
    }] waitUntilFinished];
    
    request = [OSSGetBucketV2Request new];
    request.bucketName = bucketName;
    request.fetchOwner = true;
    [[[_client getBucketV2:request] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        OSSGetBucketV2Result *result = task.result;
        for (NSDictionary *content in result.contents) {
            XCTAssertNotNil(content[@"Owner"]);
        }
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:bucketName with:_client];
}

- (NSData *)createRandomData:(NSInteger)size {
    void * bytes = malloc(size);
    NSData * data = [NSData dataWithBytes:bytes length:size];
    free(bytes);
    return data;
}

@end
