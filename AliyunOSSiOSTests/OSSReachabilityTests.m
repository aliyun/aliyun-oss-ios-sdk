//
//  OSSReachabilityTests.m
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/11/16.
//  Copyright © 2017年 zhouzhuo. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "OSSReachability.h"

@interface OSSReachabilityTests : XCTestCase

@end

@implementation OSSReachabilityTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testReachabilityWithHostName
{
    struct sockaddr sockaddr = {0};
    
    OSSReachability *reachability = [OSSReachability reachabilityWithAddress:&sockaddr];
    reachability = [OSSReachability reachabilityForInternetConnection];
    [reachability startNotifier];
    [reachability connectionRequired];
}

@end
