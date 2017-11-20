//
//  OSSCredentialProviderTests.m
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/11/20.
//  Copyright © 2017年 zhouzhuo. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "OSSModel.h"
#import "OSSTaskCompletionSource.h"
#import "OSSTask.h"
#import "OSSUtil.h"

#define RIGHT_PROVIDER_SERVER @"http://30.40.38.15:3015/sts/getsts"
#define WRONG_PROVIDER_SERVER @"http://30.40.38.78:3015/sts/getsts"

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
            NSDictionary *credentials = object[@"Credentials"];
            XCTAssertNotNil(credentials);
            OSSFederationToken * token = [OSSFederationToken new];
            // All the entries below are mandatory.
            token.tAccessKey = credentials[@"AccessKeyId"];
            token.tSecretKey = credentials[@"AccessKeySecret"];
            token.tToken = credentials[@"SecurityToken"];
            token.expirationTimeInGMTFormat = credentials[@"Expiration"];
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
            NSDictionary *credentials = object[@"Credentials"];
            XCTAssertNotNil(credentials);
            OSSFederationToken * token = [OSSFederationToken new];
            // All the entries below are mandatory.
            token.tAccessKey = credentials[@"AccessKeyId"];
            token.tSecretKey = credentials[@"AccessKeySecret"];
            token.tToken = credentials[@"SecurityToken"];
            token.expirationTimeInGMTFormat = credentials[@"Expiration"];
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
    NSDictionary *credentials = object[@"Credentials"];
    XCTAssertNotNil(credentials);
    OSSFederationToken * token = [OSSFederationToken new];
    // All the entries below are mandatory.
    token.tAccessKey = credentials[@"AccessKeyId"];
    token.tSecretKey = credentials[@"AccessKeySecret"];
    token.tToken = credentials[@"SecurityToken"];
    token.expirationTimeInGMTFormat = credentials[@"Expiration"];
    NSLog(@"AccessKeyId: %@\nAccessKeySecret: %@\nSecurityToken: %@\nExpiration: %@", token.tAccessKey, token.tSecretKey, token.tToken, token.expirationTimeInGMTFormat);
    OSSStsTokenCredentialProvider *provider = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:credentials[@"AccessKeyId"] secretKeyId:credentials[@"AccessKeySecret"] securityToken:credentials[@"SecurityToken"]];
    OSSFederationToken *federationToken = [provider getToken];
    XCTAssertNotNil(federationToken.tAccessKey);
    XCTAssertNotNil(federationToken.tSecretKey);
    XCTAssertNotNil(federationToken.tToken);
    
    NSError *signError;
    NSString *signedString = [provider sign:@"hello world" error:&signError];
    NSLog(@"signedString: %@",signedString);
    XCTAssertNil(signError);
}

@end
