//
//  ConcurrencyTests.m
//  AliyunOSSiOSTests
//
//  Created by huaixu on 2018/3/13.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "AliyunOSSTests.h"

@interface ConcurrencyTests : AliyunOSSTests

@end

@implementation ConcurrencyTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testConcurrentCreation {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    NSOperationQueue *queue = [NSOperationQueue new];
    for (int i = 0; i < 10000; i++) {
        [queue addOperationWithBlock:^{
            @autoreleasepool{
            OSSAuthCredentialProvider *credential = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
            OSSClient *client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:credential];
            }
        }];
        
    }
    [queue waitUntilAllOperationsAreFinished];
}

@end
