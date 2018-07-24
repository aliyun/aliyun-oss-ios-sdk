//
//  OSSUtilsTests.m
//  AliyunOSSiOSTests
//
//  Created by huaixu on 2018/4/27.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/OSSUtil.h>
#import <AliyunOSSiOS/OSSIPv6Adapter.h>

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

- (void)testForIpv4 {
    OSSIPv6Adapter *adapter = [OSSIPv6Adapter getInstance];
    BOOL isIPv4 = [adapter isIPv4Address: @"http://www.baidu.com"];
    XCTAssertFalse(isIPv4);
    
    isIPv4 = [adapter isIPv4Address: @"0:0:0:0:0:0:0:1"];
    XCTAssertFalse(isIPv4);
    
    isIPv4 = [adapter isIPv4Address: @"30.43.120.112"];
    XCTAssertTrue(isIPv4);
}

- (void)testForIpv6 {
    OSSIPv6Adapter *adapter = [OSSIPv6Adapter getInstance];
    BOOL isIPv6 = [adapter isIPv6Address: @"http://www.baidu.com"];
    XCTAssertFalse(isIPv6);
    
    isIPv6 = [adapter isIPv6Address: @"30.43.120.112"];
    XCTAssertFalse(isIPv6);
    
    isIPv6 = [adapter isIPv6Address: @"0:0:0:0:0:0:0:1"];
    XCTAssertTrue(isIPv6);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
