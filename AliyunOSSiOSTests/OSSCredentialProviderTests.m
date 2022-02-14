//
//  OSSCredentialProviderTests.m
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/11/20.
//  Copyright © 2017年 zhouzhuo. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import "OSSTestMacros.h"
#import "OSSTestUtils.h"

@interface OSSCredentialProviderTests : XCTestCase
{
    OSSFederationToken *_token;
    NSString *_privateBucketName;
}

@end

@implementation OSSCredentialProviderTests

- (void)setUp
{
    [super setUp];
    NSArray *array1 = [self.name componentsSeparatedByString:@" "];
    NSString *testName = [[array1[1] substringToIndex:([array1[1] length] -1)] lowercaseString];
    _privateBucketName = OSS_BUCKET_PRIVATE;
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [self setUpFederationToken];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)setUpFederationToken
{
    NSURL * url = [NSURL URLWithString:OSS_STSTOKEN_URL];
    NSURLRequest * request = [NSURLRequest requestWithURL:url];
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    NSURLSession * session = [NSURLSession sharedSession];
    NSURLSessionDataTask * dataTask = [session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                     XCTAssertNil(error);
                                                     [tcs setResult:data];
                                                 }];
    [dataTask resume];
    [tcs.task waitUntilFinished];
    
    NSDictionary * result = [NSJSONSerialization JSONObjectWithData:tcs.task.result
                                                            options:kNilOptions
                                                              error:nil];
    XCTAssertNotNil(result);
    _token = [OSSFederationToken new];
    _token.tAccessKey = result[@"AccessKeyId"];
    _token.tSecretKey = result[@"AccessKeySecret"];
    _token.tToken = result[@"SecurityToken"];
    _token.expirationTimeInGMTFormat = result[@"Expiration"];
    
    NSLog(@"tokenInfo: %@", _token);
}

- (void)headObjectWithBackgroundSessionIdentifier:(nonnull NSString *)identifier provider:(id<OSSCredentialProvider>)provider
{
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    config.backgroundSesseionIdentifier = identifier;
    config.enableBackgroundTransmitService = YES;
    
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:provider];
    OSSPutObjectRequest * put = [OSSPutObjectRequest new];
    put.bucketName = _privateBucketName;
    put.objectKey = OSS_IMAGE_KEY;
    put.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"hasky" withExtension:@"jpeg"];
    [[client putObject:put] waitUntilFinished];
        
}

- (void)testGetStsTokenCredentialProvider
{
    OSSStsTokenCredentialProvider *provider = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:_token.tAccessKey secretKeyId:_token.tSecretKey securityToken:_token.tToken];
    [self headObjectWithBackgroundSessionIdentifier:@"com.aliyun.testcases.ststokencredentialprovider.identifier" provider:provider];
}


@end
