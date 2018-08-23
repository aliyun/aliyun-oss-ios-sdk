//
//  OSSHttp2Test.m
//  AliyunOSSiOSTests
//
//  Created by 王铮 on 2018/8/3.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <XCTest/XCTest.h>
#import "OSSTestMacros.h"
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import "OSSTestUtils.h"
@interface OSSHttp2Tests : XCTestCase
{
    OSSClient *_client;
    NSString *bucketName;
    NSString *http2endpoint;
}

@end

@implementation OSSHttp2Tests

- (void)setUp {
    [super setUp];
    bucketName = @"zuoqin-public";
    http2endpoint = @"https://xx.couldplus.com";
    [self setUpOSSClient];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)setUpOSSClient
{
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    
    OSSAuthCredentialProvider *authProv = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    _client = [[OSSClient alloc] initWithEndpoint:http2endpoint
                               credentialProvider:authProv
                              clientConfiguration:config];
    [OSSLog enableLog];
    
    //upload test image
    OSSPutObjectRequest * put = [OSSPutObjectRequest new];
    put.bucketName = bucketName;
    put.objectKey = OSS_IMAGE_KEY;
    put.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"hasky" withExtension:@"jpeg"];
    [[_client putObject:put] waitUntilFinished];
}



#pragma mark - putObject


//批量操作测试
- (void)testAPI_putObjectMultiTimes
{
    int max = 30;
    for (int i = 0; i < max; i++){
        NSString *objectKey = @"putObject-wangwang.zip";
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"wangwang" ofType:@"zip"];;
        NSURL * fileURL = [NSURL fileURLWithPath:filePath];
        
        OSSPutObjectRequest * put_request = [OSSPutObjectRequest new];
        put_request.bucketName = bucketName;
        put_request.objectKey = objectKey;
        put_request.uploadingFileURL = fileURL;
        
        OSSTask * put_task = [_client putObject:put_request];
        [[put_task continueWithBlock:^id(OSSTask *task) {
            XCTAssertNil(task.error);
            return nil;
        }] waitUntilFinished];
        
        
        OSSHeadObjectRequest * head = [OSSHeadObjectRequest new];
        head.bucketName = bucketName;
        head.objectKey = objectKey;
        
        [[[_client headObject:head] continueWithBlock:^id(OSSTask *task) {
            XCTAssertNil(task.error);
            return nil;
        }] waitUntilFinished];
        
        NSString *tmpFilePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"tempfile"];
        OSSGetObjectRequest * get_request = [OSSGetObjectRequest new];
        get_request.bucketName = bucketName;
        get_request.objectKey = objectKey;
        get_request.downloadToFileURL = [NSURL fileURLWithPath:tmpFilePath];
        
        OSSTask * get_task = [_client getObject:get_request];
        [[get_task continueWithBlock:^id(OSSTask *task) {
            XCTAssertNil(task.error);
            OSSGetObjectResult * result = task.result;
            XCTAssertNil(result.downloadedData);
            return nil;
        }] waitUntilFinished];
    }
}



@end
