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

- (void)testOriginHost {
    NSString *host = @"*.aliyuncs.com";
    BOOL isTrue = [OSSUtil isOssOriginBucketHost:host];
    XCTAssertTrue(isTrue);
}

- (void)testCnameHost {
    NSString *host = @"*.abc.com";
    BOOL isFalse = [OSSUtil isOssOriginBucketHost:host];
    XCTAssertFalse(isFalse);
}

- (void)testIpHost {
    NSString *host = @"10.0.0.2";
    BOOL isFalse = [OSSUtil isOssOriginBucketHost:host];
    XCTAssertFalse(isFalse);
}

@end
