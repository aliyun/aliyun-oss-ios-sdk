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

@import AliyunOSSiOS.OSSAllRequestNeededMessage;
@import AliyunOSSiOS.OSSDefine;

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

- (void)testForOSSUASettingInterceptorWithNotAllowUACarrySystemInfo {
    NSString *ua = @"User-Agent";
    NSString *location = [[NSLocale currentLocale] localeIdentifier];

    OSSClientConfiguration *clientConfig = [OSSClientConfiguration new];
    clientConfig.isAllowUACarrySystemInfo = NO;
    OSSUASettingInterceptor *interceptor = [[OSSUASettingInterceptor alloc] initWithClientConfiguration:clientConfig];
    
    OSSAllRequestNeededMessage *allRequestMessage = [OSSAllRequestNeededMessage new];
    [interceptor interceptRequestMessage:allRequestMessage];
    NSString *expectValue = [NSString stringWithFormat:@"%@/%@(/%@)", OSSUAPrefix, OSSSDKVersion, location];
    XCTAssertTrue([allRequestMessage.headerParams[ua] isEqualToString:expectValue]);
    
    clientConfig = [OSSClientConfiguration new];
    clientConfig.isAllowUACarrySystemInfo = NO;
    clientConfig.userAgentMark = @"userAgent";
    interceptor = [[OSSUASettingInterceptor alloc] initWithClientConfiguration:clientConfig];
    
    allRequestMessage = [OSSAllRequestNeededMessage new];
    [interceptor interceptRequestMessage:allRequestMessage];
    expectValue = [NSString stringWithFormat:@"%@/%@(/%@)/%@", OSSUAPrefix, OSSSDKVersion, location, clientConfig.userAgentMark];
    XCTAssertTrue([allRequestMessage.headerParams[ua] isEqualToString:expectValue]);
}

- (void)testForOSSUASettingInterceptorWithAllowUACarrySystemInfo {
    NSString *ua = @"User-Agent";
    NSString *location = [[NSLocale currentLocale] localeIdentifier];
    NSString *systemName = [[[UIDevice currentDevice] systemName] stringByReplacingOccurrencesOfString:@" " withString:@"-"];
    NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
    
    OSSClientConfiguration *clientConfig = [OSSClientConfiguration new];
    clientConfig.isAllowUACarrySystemInfo = YES;
    OSSUASettingInterceptor *interceptor = [[OSSUASettingInterceptor alloc] initWithClientConfiguration:clientConfig];
    
    OSSAllRequestNeededMessage *allRequestMessage = [OSSAllRequestNeededMessage new];
    [interceptor interceptRequestMessage:allRequestMessage];
    NSString *expectValue = [NSString stringWithFormat:@"%@/%@(/%@/%@/%@)", OSSUAPrefix, OSSSDKVersion, systemName, systemVersion, location];
    XCTAssertTrue([allRequestMessage.headerParams[ua] isEqualToString:expectValue]);
    
    clientConfig = [OSSClientConfiguration new];
    clientConfig.isAllowUACarrySystemInfo = YES;
    clientConfig.userAgentMark = @"userAgent";
    interceptor = [[OSSUASettingInterceptor alloc] initWithClientConfiguration:clientConfig];
    
    allRequestMessage = [OSSAllRequestNeededMessage new];
    [interceptor interceptRequestMessage:allRequestMessage];
    expectValue = [NSString stringWithFormat:@"%@/%@(/%@/%@/%@)/%@", OSSUAPrefix, OSSSDKVersion, systemName, systemVersion, location, clientConfig.userAgentMark];
    XCTAssertTrue([allRequestMessage.headerParams[ua] isEqualToString:expectValue]);
}

@end
