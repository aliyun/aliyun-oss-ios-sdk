//
//  OSSRangeTests.m
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/11/20.
//  Copyright © 2017年 zhouzhuo. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/OSSModel.h>

@interface OSSRangeTests : XCTestCase

@end

@implementation OSSRangeTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    OSSRange *range = [[OSSRange alloc] initWithStart:-1 withEnd:-99];
    XCTAssertEqual(range.startPosition, -1);
    XCTAssertEqual(range.endPosition, -99);
    XCTAssert(range.description);
}

@end
