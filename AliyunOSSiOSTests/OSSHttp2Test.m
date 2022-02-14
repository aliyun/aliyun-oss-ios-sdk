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
    NSString *_bucketName;
    NSString *_http2endpoint;
}

@end

@implementation OSSHttp2Tests

- (void)setUp {
    [super setUp];
    
    [OSSLog enableLog];
    _bucketName = OSS_BUCKET_PRIVATE;
    _http2endpoint = OSS_ENDPOINT;
    [self setUpOSSClient];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)setUpOSSClient
{
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    
    OSSFederationToken *token = [OSSTestUtils getSts];
    OSSStsTokenCredentialProvider *authProv = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:token.tAccessKey secretKeyId:token.tSecretKey securityToken:token.tToken];
    _client = [[OSSClient alloc] initWithEndpoint:_http2endpoint
                               credentialProvider:authProv
                              clientConfiguration:config];
}

#pragma mark - putObject


//批量操作测试
- (void)testAPI_putObjectMultiTimes
{
    NSMutableArray<OSSTask *> *allTasks = [NSMutableArray array];
    int max = 30;
    for (int i = 0; i < max; i++){
        NSString *objectKey = @"http2-wangwang.zip";
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"wangwang" ofType:@"zip"];;
        NSURL * fileURL = [NSURL fileURLWithPath:filePath];
        
        OSSPutObjectRequest * putRequest = [OSSPutObjectRequest new];
        putRequest.bucketName = _bucketName;
        putRequest.objectKey = objectKey;
        putRequest.uploadingFileURL = fileURL;
        
        OSSTask *putTask = [_client putObject:putRequest];
        [allTasks addObject:putTask];
    }
    
    OSSTask *complexTask = [OSSTask taskForCompletionOfAllTasks:allTasks];
    [complexTask waitUntilFinished];
    XCTAssertTrue(complexTask.error == nil);
}



@end
