//
//  OSSCredentialProviderTests.m
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/11/20.
//  Copyright © 2017年 zhouzhuo. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/OSSModel.h>
#import <AliyunOSSiOS/OSSTaskCompletionSource.h>
#import <AliyunOSSiOS/OSSTask.h>
#import <AliyunOSSiOS/OSSUtil.h>

#define RIGHT_PROVIDER_SERVER @"http://*.*.*.*:****/sts/getsts"
#define WRONG_PROVIDER_SERVER @"http://*.*.*.*:****/sts/getsts"

@interface OSSCredentialProviderTests : XCTestCase

@end

@implementation OSSCredentialProviderTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testForFederationCredentialProvider
{
    OSSFederationCredentialProvider *provider = [[OSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^OSSFederationToken *{
        NSURL * url = [NSURL URLWithString:RIGHT_PROVIDER_SERVER];
        NSURLRequest * request = [NSURLRequest requestWithURL:url];
        OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
        NSURLSession * session = [NSURLSession sharedSession];
        NSURLSessionTask * sessionTask = [session dataTaskWithRequest:request
                                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                        if (error) {
                                                            [tcs setError:error];
                                                            return;
                                                        }
                                                        [tcs setResult:data];
                                                    }];
        [sessionTask resume];
        [tcs.task waitUntilFinished];
        if (tcs.task.error) {
            return nil;
        } else {
            NSDictionary * object = [NSJSONSerialization JSONObjectWithData:tcs.task.result
                                                                    options:kNilOptions
                                                                      error:nil];
            XCTAssertNotNil(object);
            OSSFederationToken * token = [OSSFederationToken new];
            // All the entries below are mandatory.
            token.tAccessKey = object[@"AccessKeyId"];
            token.tSecretKey = object[@"AccessKeySecret"];
            token.tToken = object[@"SecurityToken"];
            token.expirationTimeInGMTFormat = object[@"Expiration"];
            NSLog(@"AccessKeyId: %@\nAccessKeySecret: %@\nSecurityToken: %@\nExpiration: %@", token.tAccessKey, token.tSecretKey, token.tToken, token.expirationTimeInGMTFormat);
            return token;
        }
    }];
    
    NSError *error;
    OSSFederationToken *token = [provider getToken:&error];
    NSLog(@"token:%@",token);
    XCTAssertNil(error);
    
    NSError *otherError;
    OSSFederationToken *otherToken = [provider getToken:&otherError];
    NSLog(@"otherToken:%@",otherToken);
    XCTAssertNil(otherError);
}

- (void)testNotGetFederationCredentialProvider
{
    OSSFederationCredentialProvider *provider = [[OSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^OSSFederationToken *{
        NSURL * url = [NSURL URLWithString:WRONG_PROVIDER_SERVER];
        NSURLRequest * request = [NSURLRequest requestWithURL:url];
        OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
        NSURLSession * session = [NSURLSession sharedSession];
        NSURLSessionTask * sessionTask = [session dataTaskWithRequest:request
                                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                        if (error) {
                                                            [tcs setError:error];
                                                            return;
                                                        }
                                                        [tcs setResult:data];
                                                    }];
        [sessionTask resume];
        [tcs.task waitUntilFinished];
        if (tcs.task.error) {
            return nil;
        } else {
            NSDictionary * object = [NSJSONSerialization JSONObjectWithData:tcs.task.result
                                                                    options:kNilOptions
                                                                      error:nil];
            XCTAssertNotNil(object);
            OSSFederationToken * token = [OSSFederationToken new];
            // All the entries below are mandatory.
            token.tAccessKey = object[@"AccessKeyId"];
            token.tSecretKey = object[@"AccessKeySecret"];
            token.tToken = object[@"SecurityToken"];
            token.expirationTimeInGMTFormat = object[@"Expiration"];
            NSLog(@"AccessKeyId: %@\nAccessKeySecret: %@\nSecurityToken: %@\nExpiration: %@", token.tAccessKey, token.tSecretKey, token.tToken, token.expirationTimeInGMTFormat);
            return token;
        }
    }];
    
    NSError *error;
    OSSFederationToken *token = [provider getToken:&error];
    NSLog(@"token:%@",token);
    XCTAssertNotNil(error);
}

- (void)testGetStsTokenCredentialProvider
{
    NSURL * url = [NSURL URLWithString:RIGHT_PROVIDER_SERVER];
    NSURLRequest * request = [NSURLRequest requestWithURL:url];
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    NSURLSession * session = [NSURLSession sharedSession];
    NSURLSessionTask * sessionTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        [tcs setError:error];
                                                        return;
                                                    }
                                                    [tcs setResult:data];
                                                }];
    [sessionTask resume];
    [tcs.task waitUntilFinished];
    
    XCTAssertNil(tcs.task.error);
    NSDictionary * object = [NSJSONSerialization JSONObjectWithData:tcs.task.result
                                                            options:kNilOptions
                                                              error:nil];
    XCTAssertNotNil(object);
    OSSFederationToken * token = [OSSFederationToken new];
    // All the entries below are mandatory.
    token.tAccessKey = object[@"AccessKeyId"];
    token.tSecretKey = object[@"AccessKeySecret"];
    token.tToken = object[@"SecurityToken"];
    token.expirationTimeInGMTFormat = object[@"Expiration"];
    NSLog(@"AccessKeyId: %@\nAccessKeySecret: %@\nSecurityToken: %@\nExpiration: %@", token.tAccessKey, token.tSecretKey, token.tToken, token.expirationTimeInGMTFormat);
    OSSStsTokenCredentialProvider *provider = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:object[@"AccessKeyId"] secretKeyId:object[@"AccessKeySecret"] securityToken:object[@"SecurityToken"]];
    OSSFederationToken *federationToken = [provider getToken];
    XCTAssertNotNil(federationToken.tAccessKey);
    XCTAssertNotNil(federationToken.tSecretKey);
    XCTAssertNotNil(federationToken.tToken);
    
    NSError *signError;
    NSString *signedString = [provider sign:@"hello world" error:&signError];
    NSLog(@"signedString: %@",signedString);
    XCTAssertNil(signError);
}

- (void)testCustomSignerCredentialProvider
{
    NSURL * url = [NSURL URLWithString:RIGHT_PROVIDER_SERVER];
    NSURLRequest * request = [NSURLRequest requestWithURL:url];
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    NSURLSession * session = [NSURLSession sharedSession];
    NSURLSessionTask * sessionTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        [tcs setError:error];
                                                        return;
                                                    }
                                                    [tcs setResult:data];
                                                }];
    [sessionTask resume];
    [tcs.task waitUntilFinished];
    
    XCTAssertNil(tcs.task.error);
    NSDictionary * object = [NSJSONSerialization JSONObjectWithData:tcs.task.result
                                                            options:kNilOptions
                                                              error:nil];
    XCTAssertNotNil(object);
    OSSFederationToken * token = [OSSFederationToken new];
    // All the entries below are mandatory.
    token.tAccessKey = object[@"AccessKeyId"];
    token.tSecretKey = object[@"AccessKeySecret"];
    token.tToken = object[@"SecurityToken"];
    token.expirationTimeInGMTFormat = object[@"Expiration"];
    
    OSSCustomSignerCredentialProvider *provider = [[OSSCustomSignerCredentialProvider alloc] initWithImplementedSigner:^NSString *(NSString *contentToSign, NSError *__autoreleasing *error) {
        /** 用户将需要签名的字符串上传给自己的业务服务器，服务器进行签名之后返回给客户端 */
        NSString *signedContent = [OSSUtil sign:contentToSign withToken:token];
        return signedContent;
    }];
    
    NSError *error;
    NSString *signedString = [provider sign:@"hello world" error:&error];
    NSLog(@"signedString: %@",signedString);
    XCTAssertNil(error);
}

-(void)testPlainTextAKSKPairCredentialProvider
{
    // invalid credentialProvider
    OSSPlainTextAKSKPairCredentialProvider *provider = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:nil secretKey:nil];
    NSError *error;
    NSString *signedString = [provider sign:@"hello world" error:&error];
    NSLog(@"signedString: %@",signedString);
    XCTAssertNotNil(error);
}

@end
