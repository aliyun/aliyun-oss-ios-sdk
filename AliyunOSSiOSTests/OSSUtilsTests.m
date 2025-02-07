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
#import <AliyunOSSiOS/OSSServiceSignature.h>
#import <AliyunOSSiOS/NSData+OSS.h>

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
    
    
    NSString *result2 = [self getResultEndpoint:@"http://192.168.0.1:8081" andBucketName:bucketName];
    XCTAssertTrue([result2 isEqualToString:@"http://192.168.0.1:8081/test-image"]);

    NSString *result3 = [self getResultEndpoint:@"http://192.168.0.1" andBucketName:bucketName];
    XCTAssertTrue([result3 isEqualToString:@"http://192.168.0.1/test-image"]);

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
        OSSIPv6Adapter *ipAdapter = [OSSIPv6Adapter getInstance];
        if ([OSSUtil isOssOriginBucketHost:temComs.host]) {
            // eg. insert bucket to the begining of host.
            temComs.host = [NSString stringWithFormat:@"%@.%@",
                            name, temComs.host];
            if ([temComs.scheme.lowercaseString isEqualToString:@"http"] ) {
            NSString *dnsResult = [OSSUtil getIpByHost: temComs.host];
            temComs.host = dnsResult;
            }
        } else if ([ipAdapter isIPv4Address:temComs.host] || [ipAdapter isIPv6Address:temComs.host]) {
                temComs.path = [NSString stringWithFormat:@"/%@",name];
        }
    }
    return temComs.string;
}
 
- (void)test_methodDataMD5String {
    NSData *data = [@"objectKey" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *md5 = @"01C5B2F19CD97A7F8EF0E89E018356C4";
    
    NSError *error;
    NSString *figureMd5 = [OSSUtil dataMD5String:data error:&error];
    XCTAssertNil(error);
    XCTAssertTrue([md5 isEqualToString:figureMd5]);
    
    NSString *oldMethodfigureMd5 = [OSSUtil dataMD5String:data];
    XCTAssertTrue([oldMethodfigureMd5 isEqualToString:figureMd5]);
    
    
    data = [@"document/document/document/document/document/document/document/document/document/document/document/objectKey" dataUsingEncoding:NSUTF8StringEncoding];
    md5 = @"666CCA65279EB5E95D2AC797E1A63701";
    
    error = nil;
    figureMd5 = [OSSUtil dataMD5String:data error:&error];
    XCTAssertNil(error);
    XCTAssertTrue([md5 isEqualToString:figureMd5]);
    
    oldMethodfigureMd5 = [OSSUtil dataMD5String:data];
    XCTAssertTrue([oldMethodfigureMd5 isEqualToString:figureMd5]);
    
    
    error = nil;
    [OSSUtil dataMD5String:nil error:&error];
    XCTAssertNotNil(error);
}

- (void)test_methodFileMD5String {
    NSString *file = [[NSBundle mainBundle] pathForResource:@"hasky" ofType:@"jpeg"];
    NSString *md5 = @"E1CB762FDDAF4F93FB5B2487B03C6FEA";
    
    NSError *error = nil;
    NSString *figureMd5 = [OSSUtil fileMD5String:file error:&error];
    XCTAssertNil(error);
    XCTAssertTrue([md5 isEqualToString:figureMd5]);
    
    NSString *oldMethodfigureMd5 = [OSSUtil fileMD5String:file];
    XCTAssertTrue([oldMethodfigureMd5 isEqualToString:figureMd5]);
}

- (void)test_sha1WithFilePath {
    NSString *file = [[NSBundle mainBundle] pathForResource:@"hasky" ofType:@"jpeg"];
    NSString *sh1 = @"94692b2712cbaf4d75d44c1f4719776d66bea2b4";
    
    NSString *figureSHA1 = [OSSUtil sha1WithFilePath:file];
    XCTAssertTrue([sh1 isEqualToString:figureSHA1]);
}

- (void)test_methodCalculateSha256 {
    NSData *se = [[HmacSHA256Signature new] computeHash:[@"signingKey" dataUsingEncoding:NSUTF8StringEncoding]
                                                   data:[@"stringToSign" dataUsingEncoding:NSUTF8StringEncoding]];
    NSData *dataSha256 = [se oss_calculateSha256];
    
    XCTAssertTrue([[dataSha256 oss_hexString] isEqualToString:@"1e618d7a5cfcac0dcf62cf5f98c69297c43606ee4ee497ce4813f098a83968b3"]);
}

@end
