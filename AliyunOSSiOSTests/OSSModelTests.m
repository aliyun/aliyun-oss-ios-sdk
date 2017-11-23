//
//  OSSModelTests.m
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/11/20.
//  Copyright © 2017年 zhouzhuo. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/OSSModel.h>
#import <AliyunOSSiOS/OSSUtil.h>

@interface OSSModelTests : XCTestCase

@end

@implementation OSSModelTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testForCategoryForNSString {
    NSString *urlString = @"https://www.aliyun.com";
    urlString = [urlString oss_stringByAppendingPathComponentForURL:@"oss/sdk/ios"];
    
    NSString *urlString1 = @"https://www.aliyun.com/";
    urlString1 = [urlString1 oss_stringByAppendingPathComponentForURL:@"oss/sdk/ios"];
    
    XCTAssertEqualObjects(urlString,urlString1);
}

- (void)testForOSSSyncMutableDictionary
{
    OSSSyncMutableDictionary *syncMutableDict = [[OSSSyncMutableDictionary alloc] init];
    [syncMutableDict setObject:@"hello" forKey:@"verb"];
    [syncMutableDict setObject:@"world" forKey:@"noun"];
    XCTAssertNotNil(syncMutableDict.allKeys);
}

@end
