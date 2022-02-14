//
//  OSSNetworkingRequestDelegateTest.m
//  AliyunOSSiOSTests
//
//  Created by ws on 2021/3/26.
//  Copyright © 2021 aliyun. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import "OSSTestMacros.h"

#define SCHEME @"https://"
#define ENDPOINT @"oss-cn-hangzhou.aliyuncs.com"
#define CNAME_ENDPOINT @"oss.custom.com"
#define IP_ENDPOINT @"192.168.1.1:8080"
#define CUSTOMPATH @"/path"
#define CUSTOMPATH_ENDPOINT @"oss.custom.com/path"
#define BUCKET_NAME @"BucketName"
#define OBJECT_KEY @"ObjectKey"

@interface OSSNetworkingRequestDelegateTest : XCTestCase

@end

@implementation OSSNetworkingRequestDelegateTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
}

- (void)testBuildUrlWithCname {
    OSSAllRequestNeededMessage *message = [OSSAllRequestNeededMessage new];
    message.endpoint = [SCHEME stringByAppendingString:CNAME_ENDPOINT];
    message.bucketName = OSS_BUCKET_PRIVATE;
    message.objectKey = OBJECT_KEY;
    message.isHostInCnameExcludeList = NO;
    
    OSSNetworkingRequestDelegate *delegate = [OSSNetworkingRequestDelegate new];
    delegate.operType = 1;
    delegate.allNeededMessage = message;
    [delegate buildInternalHttpRequest];
    NSString *url = delegate.internalRequest.URL.absoluteString;
    NSString *canonicalUrl = [NSString stringWithFormat:@"%@%@/%@", SCHEME, CNAME_ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([url isEqualToString:canonicalUrl]);
}

- (void)testBuildUrlWithoutCname {
    OSSAllRequestNeededMessage *message = [OSSAllRequestNeededMessage new];
    message.endpoint = [SCHEME stringByAppendingString:CNAME_ENDPOINT];
    message.bucketName = OSS_BUCKET_PRIVATE;
    message.objectKey = OBJECT_KEY;
    message.isHostInCnameExcludeList = YES;
    
    OSSNetworkingRequestDelegate *delegate = [OSSNetworkingRequestDelegate new];
    delegate.operType = 1;
    delegate.allNeededMessage = message;
    [delegate buildInternalHttpRequest];
    NSString *url = delegate.internalRequest.URL.absoluteString;
    NSString *canonicalUrl = [NSString stringWithFormat:@"%@%@.%@/%@", SCHEME, OSS_BUCKET_PRIVATE, CNAME_ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([url isEqualToString:canonicalUrl]);
}

- (void)testBuildUrlWithCnameAndPathStyleAccessEnable {
    OSSAllRequestNeededMessage *message = [OSSAllRequestNeededMessage new];
    message.endpoint = [SCHEME stringByAppendingString:CNAME_ENDPOINT];
    message.bucketName = OSS_BUCKET_PRIVATE;
    message.objectKey = OBJECT_KEY;
    message.isHostInCnameExcludeList = YES;
    
    OSSNetworkingRequestDelegate *delegate = [OSSNetworkingRequestDelegate new];
    delegate.operType = 1;
    delegate.allNeededMessage = message;
    delegate.isPathStyleAccessEnable = YES;
    [delegate buildInternalHttpRequest];
    NSString *url = delegate.internalRequest.URL.absoluteString;
    NSString *canonicalUrl = [NSString stringWithFormat:@"%@%@/%@/%@", SCHEME, CNAME_ENDPOINT, OSS_BUCKET_PRIVATE, OBJECT_KEY];
    XCTAssertTrue([url isEqualToString:canonicalUrl]);
}

- (void)testBuildUrlWithPathStyleAccessEnable {
    OSSAllRequestNeededMessage *message = [OSSAllRequestNeededMessage new];
    message.endpoint = [SCHEME stringByAppendingString:ENDPOINT];
    message.bucketName = OSS_BUCKET_PRIVATE;
    message.objectKey = OBJECT_KEY;
    
    OSSNetworkingRequestDelegate *delegate = [OSSNetworkingRequestDelegate new];
    delegate.operType = 1;
    delegate.allNeededMessage = message;
    delegate.isPathStyleAccessEnable = YES;
    [delegate buildInternalHttpRequest];
    NSString *url = delegate.internalRequest.URL.absoluteString;
    NSString *canonicalUrl = [NSString stringWithFormat:@"%@%@.%@/%@", SCHEME, OSS_BUCKET_PRIVATE, ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([url isEqualToString:canonicalUrl]);
    
    message = [OSSAllRequestNeededMessage new];
    message.endpoint = [SCHEME stringByAppendingString:CNAME_ENDPOINT];
    message.bucketName = OSS_BUCKET_PRIVATE;
    message.objectKey = OBJECT_KEY;
    
    delegate = [OSSNetworkingRequestDelegate new];
    delegate.operType = 1;
    delegate.allNeededMessage = message;
    delegate.isPathStyleAccessEnable = YES;
    [delegate buildInternalHttpRequest];
    url = delegate.internalRequest.URL.absoluteString;
    canonicalUrl = [NSString stringWithFormat:@"%@%@/%@", SCHEME, CNAME_ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([url isEqualToString:canonicalUrl]);
}

- (void)testBuildUrlWithCustomPathPrefixEnable {
    OSSAllRequestNeededMessage *message = [OSSAllRequestNeededMessage new];
    message.endpoint = [SCHEME stringByAppendingString:CUSTOMPATH_ENDPOINT];
    message.bucketName = BUCKET_NAME;
    message.objectKey = OBJECT_KEY;
    
    OSSNetworkingRequestDelegate *delegate = [OSSNetworkingRequestDelegate new];
    delegate.operType = 1;
    delegate.allNeededMessage = message;
    delegate.isCustomPathPrefixEnable = YES;
    [delegate buildInternalHttpRequest];
    NSString *url = delegate.internalRequest.URL.absoluteString;
    NSString *canonicalUrl = [NSString stringWithFormat:@"%@%@/%@", SCHEME, CUSTOMPATH_ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([url isEqualToString:canonicalUrl]);
}

- (void)testBuildUrlWithCustomPathPrefixEnableAndPathStyleAccessEnable {
    OSSAllRequestNeededMessage *message = [OSSAllRequestNeededMessage new];
    message.endpoint = [SCHEME stringByAppendingString:CUSTOMPATH_ENDPOINT];
    message.bucketName = OSS_BUCKET_PRIVATE;
    message.objectKey = OBJECT_KEY;
    message.isHostInCnameExcludeList = YES;
    
    OSSNetworkingRequestDelegate *delegate = [OSSNetworkingRequestDelegate new];
    delegate.operType = 1;
    delegate.allNeededMessage = message;
    delegate.isCustomPathPrefixEnable = YES;
    delegate.isPathStyleAccessEnable = YES;
    [delegate buildInternalHttpRequest];
    NSString *url = delegate.internalRequest.URL.absoluteString;
    NSString *canonicalUrl = [NSString stringWithFormat:@"%@%@/%@/%@", SCHEME, CUSTOMPATH_ENDPOINT, OSS_BUCKET_PRIVATE, OBJECT_KEY];
    XCTAssertTrue([url isEqualToString:canonicalUrl]);
}

@end
