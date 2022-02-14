//
//  OSSUtilsTests.m
//  AliyunOSSiOSTests
//
//  Created by huaixu on 2018/4/27.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/OSSUtil.h>

@interface OSSUtilsTests : XCTestCase

@end

@implementation OSSUtilsTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testMIMEWithLowercaseExt {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    NSString *fileName = @"testMIME.mp4";
    NSString *mime = [OSSUtil detemineMimeTypeForFilePath:fileName uploadName:nil];
    XCTAssertTrue([mime isEqualToString:@"video/mp4"]);
}

- (void)testMIMEWithUppercaseExt {
    NSString *fileName = @"testMIME.MP4";
    NSString *mime = [OSSUtil detemineMimeTypeForFilePath:fileName uploadName:nil];
    XCTAssertTrue([mime isEqualToString:@"video/mp4"]);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

- (void)testBucketName{
    ///^[a-z0-9][a-z0-9\\-]{1,61}[a-z0-9]$"
    
    BOOL result1 = [OSSUtil validateBucketName:@"123-456abc"];
    XCTAssertTrue(result1);
   
    BOOL result2 = [OSSUtil validateBucketName:@"123-456abc*"];
    XCTAssertFalse(result2);
    
    BOOL result3 = [OSSUtil validateBucketName:@"-123-456abc"];
    XCTAssertFalse(result3);
    
    BOOL result4 = [OSSUtil validateBucketName:@"123\\456abc"];
    XCTAssertFalse(result4);
    
    BOOL result5 = [OSSUtil validateBucketName:@"abc123"];
    XCTAssertTrue(result5);
       
    BOOL result6 = [OSSUtil validateBucketName:@"abc_123"];
    XCTAssertFalse(result6);
       
    BOOL result7 = [OSSUtil validateBucketName:@"a"];
    XCTAssertFalse(result7);
       
    BOOL result8 = [OSSUtil validateBucketName:@"abcdefghig-abcdefghig-abcdefghig-abcdefghig-abcdefghig-abcdefghig"];
    XCTAssertFalse(result8);
       
}


- (void)testEndpoint{
    NSString *bucketName = @"test-image";
    NSString *result1 = [self getResultEndpoint:@"http://123.test:8989/path?ooob" andBucketName:bucketName];
    XCTAssertTrue([result1 isEqualToString:@"http://123.test:8989"]);
    
    NSString *result4 = [self getResultEndpoint:@"http://oss-cn-region.aliyuncs.com" andBucketName:bucketName];
    XCTAssertTrue([result4 isEqualToString:@"http://test-image.oss-cn-region.aliyuncs.com"]);

}

- (NSString *)getResultEndpoint:(NSString *)endpoint andBucketName:(NSString *)name{
    NSURLComponents *urlComponents = [[NSURLComponents alloc]initWithString:endpoint];
    
    NSURLComponents *temComs = [NSURLComponents new];
    temComs.scheme = urlComponents.scheme;
    temComs.host = urlComponents.host;
    temComs.port = urlComponents.port;
       
    if ([name oss_isNotEmpty]) {
        if ([OSSUtil isOssOriginBucketHost:temComs.host]) {
            // eg. insert bucket to the begining of host.
            temComs.host = [NSString stringWithFormat:@"%@.%@",
                            name, temComs.host];
        }
    }
    return temComs.string;
}
 


@end
