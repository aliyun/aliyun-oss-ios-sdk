//
//  OSSClientTests.m
//  AliyunOSSiOSTests
//
//  Created by huaixu on 2018/8/10.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>

@interface OSSClientTests : XCTestCase

@end

@implementation OSSClientTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testClientWithInvalidEndpoint {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    NSString *endpoint = nil;
    
    XCTAssertThrowsSpecificNamed([[OSSClient alloc] initWithEndpoint:endpoint credentialProvider:nil clientConfiguration:nil], NSException, NSInvalidArgumentException, @"should throw NSInternalInconsistencyException");

    endpoint = @"https://1.1.1.1";
    XCTAssertThrowsSpecificNamed([[OSSClient alloc] initWithEndpoint:endpoint credentialProvider:nil clientConfiguration:nil], NSException, NSInvalidArgumentException, @"should throw NSInternalInconsistencyException");
    
    endpoint = @"1.1.1.1";
    XCTAssertThrowsSpecificNamed([[OSSClient alloc] initWithEndpoint:endpoint credentialProvider:nil clientConfiguration:nil], NSException, NSInvalidArgumentException, @"should throw NSInternalInconsistencyException");
    
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
