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

@interface OSSCredentialProviderTests : XCTestCase
{
    OSSFederationToken *_token;
}

@end

@implementation OSSCredentialProviderTests

- (void)setUp
{
    [super setUp];
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
    OSSHeadObjectRequest *request = [OSSHeadObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.objectKey = @"hasky.jpeg";
    OSSTask *task = [client headObject:request];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);
}

- (void)testForFederationCredentialProvider
{
    OSSFederationCredentialProvider *provider = [[OSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^OSSFederationToken *{
        return _token;
    }];
    
    [self headObjectWithBackgroundSessionIdentifier:@"com.aliyun.testcases.federationprovider.identifier" provider:provider];
}

- (void)testGetStsTokenCredentialProvider
{
    OSSStsTokenCredentialProvider *provider = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:_token.tAccessKey secretKeyId:_token.tSecretKey securityToken:_token.tToken];
    [self headObjectWithBackgroundSessionIdentifier:@"com.aliyun.testcases.ststokencredentialprovider.identifier" provider:provider];
}

- (void)testCustomSignerCredentialProvider
{
    OSSCustomSignerCredentialProvider *provider = [[OSSCustomSignerCredentialProvider alloc] initWithImplementedSigner:^NSString *(NSString *contentToSign, NSError *__autoreleasing *error) {
        
        OSSFederationToken *token = [OSSFederationToken new];
        token.tAccessKey = OSS_ACCESSKEY_ID;
        token.tSecretKey = OSS_SECRETKEY_ID;
        
        NSString *signedContent = [OSSUtil sign:contentToSign withToken:token];
        return signedContent;
    }];
    
    [self headObjectWithBackgroundSessionIdentifier:@"com.aliyun.testcases.customsignercredentialprovider.identifier" provider:provider];
}

-(void)testPlainTextAKSKPairCredentialProvider
{
    // invalid credentialProvider
    OSSPlainTextAKSKPairCredentialProvider *provider = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:OSS_ACCESSKEY_ID secretKey:OSS_SECRETKEY_ID];
    [self headObjectWithBackgroundSessionIdentifier:@"com.aliyun.testcases.plainakskpaircredentialprovider.identifier" provider:provider];
}

-(void)testAuthCredentialProvider
{
    // invalid credentialProvider
    OSSAuthCredentialProvider *provider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    
    [self headObjectWithBackgroundSessionIdentifier:@"com.aliyun.testcases.authcredentialprovider.identifier" provider:provider];
}

- (void)testAuthCredentialProviderWithDecoder
{
    id<OSSCredentialProvider> provider =
    [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL responseDecoder:^NSData *(NSData *data) {
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSData* decodeData = [str dataUsingEncoding:NSUTF8StringEncoding];
        if (decodeData) {
            return decodeData;
        }
        return data;
    }];
    
    [self headObjectWithBackgroundSessionIdentifier:@"com.aliyun.testcases.authcredentialproviderwithdecoder.identifier" provider:provider];
}

@end
