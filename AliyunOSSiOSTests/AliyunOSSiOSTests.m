//
//  AliyunOSSiOSTests.m
//  AliyunOSSiOSTests
//
//  Created by zhouzhuo on 9/16/15.
//  Copyright (c) 2015 zhouzhuo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import <AliyunOSSiOS/OSSHttpdns.h>
#import "OSSTestMacros.h"
#import "OSSTestUtils.h"

@interface oss_ios_sdk_newTests : XCTestCase
{
    NSString *_privateBucketName;
}
@end

static NSArray * fileNameArray;
static NSArray * fileSizeArray;
static OSSClient * client;
static dispatch_queue_t test_queue;

id<OSSCredentialProvider> credential, authCredential;

@implementation oss_ios_sdk_newTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    NSArray *array1 = [self.name componentsSeparatedByString:@" "];
    NSString *testName = [[array1[1] substringToIndex:([array1[1] length] -1)] lowercaseString];
    _privateBucketName = [@"oss-ios-" stringByAppendingString:testName];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fileNameArray = @[@"file1k", @"file10k", @"file100k", @"file1m", @"file5m", @"file10m", @"fileDirA/", @"fileDirB/"];
        fileSizeArray = @[@1024, @10240, @102400, @(1024 * 1024 * 1), @(1024 * 1024 * 5), @(1024 * 1024 * 10), @1024, @1024];
        [self initOSSClient];
        [self initLocalFiles];
        test_queue = dispatch_queue_create("com.aliyun.oss.test", DISPATCH_QUEUE_CONCURRENT);
    });
    OSSCreateBucketRequest *createBucket1 = [OSSCreateBucketRequest new];
    createBucket1.bucketName = _privateBucketName;
    [[client createBucket:createBucket1] waitUntilFinished];
    
    //upload test image
    OSSPutObjectRequest * put = [OSSPutObjectRequest new];
    put.bucketName = _privateBucketName;
    put.objectKey = OSS_IMAGE_KEY;
    put.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"hasky" withExtension:@"jpeg"];
    [[client putObject:put] waitUntilFinished];
}

- (void)initLocalFiles {
    NSFileManager * fm = [NSFileManager defaultManager];
    NSString * mainDir = [NSString oss_documentDirectory];
    
    for (int i = 0; i < [fileNameArray count]; i++) {
        NSMutableData * basePart = [NSMutableData dataWithCapacity:1024];
        for (int j = 0; j < 1024/4; j++) {
            u_int32_t randomBit = j;// arc4random();
            [basePart appendBytes:(void*)&randomBit length:4];
        }
        NSString * name = [fileNameArray objectAtIndex:i];
        long size = [[fileSizeArray objectAtIndex:i] longValue];
        NSString * newFilePath = [mainDir stringByAppendingPathComponent:name];
        if ([fm fileExistsAtPath:newFilePath]) {
            [fm removeItemAtPath:newFilePath error:nil];
        }
        [fm createFileAtPath:newFilePath contents:nil attributes:nil];
        NSFileHandle * f = [NSFileHandle fileHandleForWritingAtPath:newFilePath];
        for (int k = 0; k < size/1024; k++) {
            [f writeData:basePart];
        }
        [f closeFile];
        // NSLog(@"file: %@, cal: %@", name, [OSSUtil base64Md5ForFilePath:newFilePath]);
    }
    NSLog(@"main bundle: %@", mainDir);
}

- (void)initOSSClient {
    [OSSLog enableLog];
    
    
    credential = [self newStsTokenCredentialProvider];
    authCredential = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    conf.maxRetryCount = 2;
    conf.timeoutIntervalForRequest = 30;
    conf.timeoutIntervalForResource = 24 * 60 * 60;
    conf.maxConcurrentRequestCount = 5;
    
    // switches to another credential provider.
    client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:authCredential clientConfiguration:conf];
}

// Initializes an OSSClient object with STS token and AK pairs.
// In this case, the OSSClient will not auto refresh the token. The caller needs to check if the token has been expired and refresh a new STS token.
// If the expired token is not updated, the authentication will fail for subsequential requests.
- (id<OSSCredentialProvider>)newStsTokenCredentialProvider {
    
    // Assuming the following is the returned data from app servers
    // {"accessKeyId":"STS.iA645eTOXEqP3cg3VeHf",
    // "accessKeySecret":"rV3VQrpFQ4BsyHSAvi5NVLpPIVffDJv4LojUBZCf",
    // "expiration":"2015-11-03T09:52:59Z[;",
    // "federatedUser":"335450541522398178:alice-001",
    // "requestId":"C0E01B94-332E-4582-87F9-B857C807EE52",
    // "securityToken":"CAES7QIIARKAAZPlqaN9ILiQZPS+JDkS/GSZN45RLx4YS/p3OgaUC+oJl3XSlbJ7StKpQp1Q3KtZVCeAKAYY6HYSFOa6rU0bltFXAPyW+jvlijGKLezJs0AcIvP5a4ki6yHWovkbPYNnFSOhOmCGMmXKIkhrRSHMGYJRj8AIUvICAbDhzryeNHvUGhhTVFMuaUE2NDVlVE9YRXFQM2NnM1ZlSGYiEjMzNTQ1MDU0MTUyMjM5ODE3OCoJYWxpY2UtMDAxMOG/g7v6KToGUnNhTUQ1QloKATEaVQoFQWxsb3cSHwoMQWN0aW9uRXF1YWxzEgZBY3Rpb24aBwoFb3NzOioSKwoOUmVzb3VyY2VFcXVhbHMSCFJlc291cmNlGg8KDWFjczpvc3M6KjoqOipKEDEwNzI2MDc4NDc4NjM4ODhSAFoPQXNzdW1lZFJvbGVVc2VyYABqEjMzNTQ1MDU0MTUyMjM5ODE3OHIHeHljLTAwMQ=="}
    
    NSURL * url = [NSURL URLWithString:OSS_STSTOKEN_URL];
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
        // If the call to retrieve token fails, return null.
        // In real world, a few retries are recommended.
        NSLog(@"Cant't init credential4, error: %@", tcs.task.error);
        return nil;
    } else {
        NSDictionary * object = [NSJSONSerialization JSONObjectWithData:tcs.task.result
                                                                options:kNilOptions
                                                                  error:nil];
        
        NSString * accessKey = [object objectForKey:@"AccessKeyId"];
        NSString * secretKey = [object objectForKey:@"AccessKeySecret"];
        NSString * token = [object objectForKey:@"SecurityToken"];
        OSSLogDebug(@"token: %@ %@ %@", accessKey, secretKey, token);
        
        return [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:accessKey secretKeyId:secretKey securityToken:token];
    }
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [OSSTestUtils cleanBucket:_privateBucketName with:client];
}

- (void)testAbortMultipartUpload
{
    __block NSString * uploadId = nil;
    OSSInitMultipartUploadRequest * init = [OSSInitMultipartUploadRequest new];
    init.bucketName = _privateBucketName;
    init.objectKey = OSS_MULTIPART_UPLOADKEY;
    init.contentType = @"application/octet-stream";
    init.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    OSSTask * task = [client multipartUploadInit:init];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSInitMultipartUploadResult * result = task.result;
        XCTAssertNotNil(result.uploadId);
        uploadId = result.uploadId;
        return nil;
    }] waitUntilFinished];
    
    OSSAbortMultipartUploadRequest * abort = [OSSAbortMultipartUploadRequest new];
    abort.bucketName = _privateBucketName;
    abort.objectKey = OSS_MULTIPART_UPLOADKEY;
    abort.uploadId = uploadId;
    
    OSSTask * abortTask = [client abortMultipartUpload:abort];
    
    [abortTask waitUntilFinished];
    
    XCTAssertNil(abortTask.error);
    OSSAbortMultipartUploadResult * abortResult = abortTask.result;
    XCTAssertEqual(204, abortResult.httpResponseCode);
}

- (void)testAccessViaHttpProxy {
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    
    conf.proxyHost = @"test";
    if ([conf.proxyHost isEqualToString:@"test"]) {
        /* your have to set your own proxy to run */
        return;
    }
    conf.proxyPort = @(8088);
    
    OSSClient * testProxyClient = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                                                   credentialProvider:client.credentialProvider
                                                  clientConfiguration:conf];
    
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file1m";
    
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    OSSTask * task = [testProxyClient getObject:request];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testUserAgentConfig {
    [OSSTestUtils putTestDataWithKey:@"file1m" withClient:client withBucket:_privateBucketName];
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    
    conf.userAgentMark = @"customUserAgent";
    
    OSSClient * testProxyClient = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                                                   credentialProvider:client.credentialProvider
                                                  clientConfiguration:conf];
    
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file1m";
    
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"progress: %lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    OSSTask * task = [testProxyClient getObject:request];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    OSSClientConfiguration * conf1 = [OSSClientConfiguration new];
    
    conf1.userAgentMark = @"customUserAgentOther";
    
    [testProxyClient setClientConfiguration:conf1];
    
    OSSGetObjectRequest * request1 = [OSSGetObjectRequest new];
    request1.bucketName = _privateBucketName;
    request1.objectKey = @"file1m";
    
    request1.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"progress: %lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    OSSTask * task1 = [testProxyClient getObject:request1];
    
    [[task1 continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
}

- (void)testMultiClientInstance {
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    conf.maxRetryCount = 3;
    conf.timeoutIntervalForRequest = 15;
    conf.timeoutIntervalForResource = 24 * 60 * 60;
    
    OSSClient * client1 = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                                           credentialProvider:credential
                                          clientConfiguration:conf];
    
    conf = [OSSClientConfiguration new];
    conf.maxRetryCount = 3;
    conf.enableBackgroundTransmitService = YES;
    conf.backgroundSesseionIdentifier = @"test_other_backgroundservice-enbaled_client";
    conf.timeoutIntervalForRequest = 15;
    conf.timeoutIntervalForResource = 24 * 60 * 60;
    OSSClient * client2 = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                                           credentialProvider:credential
                                          clientConfiguration:conf];
    
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file1m";
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
    
    request.uploadingData = [readFile readDataToEndOfFile];
    request.contentMd5 = [OSSUtil base64Md5ForData:request.uploadingData];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"1 -------------------- %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    OSSTask * task = [client1 putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        if (task.error) {
            OSSLogError(@"%@", task.error);
        }
        OSSPutObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        NSLog(@"Result - requestId: %@, headerFields: %@",
              result.requestId,
              result.httpResponseHeaderFields);
        return nil;
    }] waitUntilFinished];
    
    request = [OSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file1m";
    readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
    request.uploadingData = [readFile readDataToEndOfFile];
    request.contentMd5 = [OSSUtil base64Md5ForData:request.uploadingData];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"2 --------------- %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    task = [client2 putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        if (task.error) {
            OSSLogError(@"%@", task.error);
        }
        OSSPutObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        NSLog(@"Result - requestId: %@, headerFields: %@",
              result.requestId,
              result.httpResponseHeaderFields);
        return nil;
    }] waitUntilFinished];
}

- (void)testClientInitWithNoneSchemeEndpoint {
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    conf.maxRetryCount = 3;
    conf.timeoutIntervalForRequest = 15;
    conf.timeoutIntervalForResource = 24 * 60 * 60;
    
    OSSClient * client1 = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                                           credentialProvider:credential
                                          clientConfiguration:conf];
    
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file1m";
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
    
    request.uploadingData = [readFile readDataToEndOfFile];
    request.contentMd5 = [OSSUtil base64Md5ForData:request.uploadingData];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"1 -------------------- %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    OSSTask * task = [client1 putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        if (task.error) {
            OSSLogError(@"%@", task.error);
        }
        OSSPutObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        NSLog(@"Result - requestId: %@, headerFields: %@",
              result.requestId,
              result.httpResponseHeaderFields);
        return nil;
    }] waitUntilFinished];
}

- (void)testMultipartUploadNormal {
    OSSMultipartUploadRequest * multipartUploadRequest = [OSSMultipartUploadRequest new];
    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.bucketName = _privateBucketName;
    multipartUploadRequest.objectKey = OSS_MULTIPART_UPLOADKEY;
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.partSize = 1024 * 1024;
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };

    multipartUploadRequest.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    OSSTask * multipartTask = [client multipartUpload:multipartUploadRequest];
    
    [[multipartTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        if (task.error) {
            NSLog(@"error: %@", task.error);
            if ([task.error.domain isEqualToString:OSSClientErrorDomain] && task.error.code == OSSClientErrorCodeCannotResumeUpload) {
                // The upload cannot be resumed. Needs to re-initiate a upload.
            }
        } else {
            BOOL isEqual = [self isFileOnOSSBucket:_privateBucketName objectKey:OSS_MULTIPART_UPLOADKEY equalsToLocalFile:[multipartUploadRequest.uploadingFileURL path]];
            XCTAssertTrue(isEqual);
        }
        return nil;
    }] waitUntilFinished];
}

- (void)testMultipartUploadCancel {
    OSSMultipartUploadRequest * multipartUploadRequest = [OSSMultipartUploadRequest new];
    multipartUploadRequest.bucketName = _privateBucketName;
    multipartUploadRequest.objectKey = OSS_MULTIPART_UPLOADKEY;
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.partSize = 256 * 1024;
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    NSString * docDir = [NSString oss_documentDirectory];
    multipartUploadRequest.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file10m"]];
    OSSTask * resumeTask = [client multipartUpload:multipartUploadRequest];
    [resumeTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        NSLog(@"error: %@", task.error);
        XCTAssertEqual(OSSClientErrorCodeTaskCancelled, task.error.code);
        return nil;
    }];
    
    [NSThread sleepForTimeInterval:1];
    
    [multipartUploadRequest cancel];
    [resumeTask waitUntilFinished];
}

- (void)testResumableUploadNormal {
    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = _privateBucketName;
    resumableUpload.contentType = @"application/octet-stream";
    resumableUpload.objectKey = OSS_MULTIPART_UPLOADKEY;
    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    resumableUpload.partSize = 256 * 1024;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    resumableUpload.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    OSSTask * resumeTask = [client resumableUpload:resumableUpload];
    
    [[resumeTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        if (task.error) {
            NSLog(@"error: %@", task.error);
            if ([task.error.domain isEqualToString:OSSClientErrorDomain] && task.error.code == OSSClientErrorCodeCannotResumeUpload) {
                // The upload cannot be resumed. Needs to re-initiate a upload.
            }
        } else {
            NSString * recordFilePath = [self getRecordFilePath:resumableUpload];
            XCTAssertTrue(![[NSFileManager defaultManager] fileExistsAtPath:recordFilePath]);
            NSLog(@"Upload file success");
        }
        return nil;
    }] waitUntilFinished];
    
    BOOL isEqual = [self isFileOnOSSBucket:_privateBucketName objectKey:OSS_MULTIPART_UPLOADKEY equalsToLocalFile:[resumableUpload.uploadingFileURL path]];
    XCTAssertTrue(isEqual);
}

- (void)testResumableUploadSetACL {
    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = _privateBucketName;
    resumableUpload.contentType = @"application/octet-stream";
    resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    resumableUpload.objectKey = OSS_MULTIPART_UPLOADKEY;
    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.partSize = 100 * 1024;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    resumableUpload.completeMetaHeader = @{@"x-oss-object-acl": @"public-read-write"};
    NSString * docDir = [NSString oss_documentDirectory];
    resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    OSSTask * resumeTask = [client resumableUpload:resumableUpload];
    [[resumeTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        if (task.error) {
            NSLog(@"error: %@", task.error);
            if ([task.error.domain isEqualToString:OSSClientErrorDomain] && task.error.code == OSSClientErrorCodeCannotResumeUpload) {
                // The upload cannot be resumed. Needs to re-initiate a upload.
            }
        } else {
            NSString * recordFilePath = [self getRecordFilePath:resumableUpload];
            XCTAssertTrue(![[NSFileManager defaultManager] fileExistsAtPath:recordFilePath]);
            NSLog(@"Upload file success");
        }
        return nil;
    }] waitUntilFinished];
    
    BOOL isEqual = [self isFileOnOSSBucket:_privateBucketName objectKey:OSS_MULTIPART_UPLOADKEY equalsToLocalFile:[resumableUpload.uploadingFileURL path]];
    XCTAssertTrue(isEqual);
    
    OSSGetObjectRequest * getRequest = [OSSGetObjectRequest new];
    getRequest.bucketName = _privateBucketName;
    getRequest.objectKey = OSS_MULTIPART_UPLOADKEY;
    getRequest.isAuthenticationRequired = NO;
    OSSTask * getTask = [client getObject:getRequest];
    [getTask waitUntilFinished];
    XCTAssertNil(getTask.error);
}

- (void)testResumableUploadServerCallback {
    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = _privateBucketName;
    resumableUpload.objectKey = OSS_MULTIPART_UPLOADKEY;
    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.contentType = @"application/octet-stream";
    resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    resumableUpload.partSize = 100 * 1024;
    resumableUpload.callbackParam = @{
                                      @"callbackUrl": OSS_CALLBACK_URL,
                                      @"callbackBody": @"test"
                                      };
    resumableUpload.callbackVar = @{
                                    @"var1": @"value1",
                                    @"var2": @"value2"
                                    };
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    NSString * docDir = [NSString oss_documentDirectory];
    resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    OSSTask * resumeTask = [client resumableUpload:resumableUpload];
    [[resumeTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSResumableUploadResult * resumableUploadResult = task.result;
        if (task.error) {
            NSLog(@"error: %@", task.error);
            if ([task.error.domain isEqualToString:OSSClientErrorDomain] && task.error.code == OSSClientErrorCodeCannotResumeUpload) {
                // The upload cannot be resumed. Needs to re-initiate a upload.
            }
        } else {
            NSLog(@"Upload file success");
            XCTAssertNotNil(resumableUploadResult);
            XCTAssertNotNil(resumableUploadResult.serverReturnJsonString);
            NSString * recordFilePath = [self getRecordFilePath:resumableUpload];
            XCTAssertTrue(![[NSFileManager defaultManager] fileExistsAtPath:recordFilePath]);
        }
        return nil;
    }] waitUntilFinished];
    
}



- (void)testResumbleUploadCancel {
    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = _privateBucketName;
    resumableUpload.objectKey = OSS_MULTIPART_UPLOADKEY;
    BOOL isDelete = NO;
    resumableUpload.deleteUploadIdOnCancelling = isDelete;
    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.contentType = @"application/octet-stream";
    resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    resumableUpload.partSize = 256 * 1024;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    NSString * docDir = [NSString oss_documentDirectory];
    resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file10m"]];
    OSSTask * resumeTask = [client resumableUpload:resumableUpload];
    [resumeTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        NSLog(@"error: %@", task.error);
        XCTAssertEqual(OSSClientErrorCodeTaskCancelled, task.error.code);
        NSString * recordFilePath = [self getRecordFilePath:resumableUpload];
        if (isDelete){
            XCTAssertTrue(![[NSFileManager defaultManager] fileExistsAtPath:recordFilePath]);
        }else{
            XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:recordFilePath]);
        }
        
        return nil;
    }];
    
    [NSThread sleepForTimeInterval:1];
    [resumableUpload cancel];
    [resumeTask waitUntilFinished];
    
}

- (NSString *)getRecordFilePath:(OSSResumableUploadRequest *)resumableUpload {
    NSString *recordPathMd5 = [OSSUtil fileMD5String:[resumableUpload.uploadingFileURL path]];
    NSData *data = [[NSString stringWithFormat:@"%@%@%@%lld",recordPathMd5, resumableUpload.bucketName, resumableUpload.objectKey, resumableUpload.partSize] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *recordFileName = [OSSUtil dataMD5String:data];
    NSString *recordFilePath = [NSString stringWithFormat:@"%@/%@",resumableUpload.recordDirectoryPath,recordFileName];
    return recordFilePath;
}

- (void)testResumbleUploadAbort {
    __block bool cancel = NO;
    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = _privateBucketName;
    resumableUpload.objectKey = OSS_MULTIPART_UPLOADKEY;
    resumableUpload.deleteUploadIdOnCancelling = NO;
    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.contentType = @"application/octet-stream";
    resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    resumableUpload.partSize = 256 * 1024;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        if(totalByteSent >= totalBytesExpectedToSend /2){
            cancel = YES;
        }
    };
    NSString * docDir = [NSString oss_documentDirectory];
    resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file5m"]];
    OSSTask * resumeTask = [client resumableUpload:resumableUpload];
    [resumeTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        NSLog(@"error: %@", task.error);
        XCTAssertEqual(OSSClientErrorCodeTaskCancelled, task.error.code);
        return nil;
    }];
    
    while (!cancel) {
        [NSThread sleepForTimeInterval:0.1];
    }
    [resumableUpload cancel];
    [resumeTask waitUntilFinished];
    
    
    [[[client abortResumableMultipartUpload:resumableUpload] continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    
    resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = _privateBucketName;
    resumableUpload.objectKey = OSS_MULTIPART_UPLOADKEY;
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.contentType = @"application/octet-stream";
    resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    resumableUpload.partSize = 256 * 1024;
    resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file5m"]];
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    resumeTask = [client resumableUpload:resumableUpload];
    [[resumeTask continueWithBlock:^id(OSSTask *task) {
        NSLog(@"error: %@", task.error);
        XCTAssertNil(task.error);
        NSString * recordFilePath = [self getRecordFilePath:resumableUpload];
        XCTAssertTrue(![[NSFileManager defaultManager] fileExistsAtPath:recordFilePath]);
        return nil;
    }] waitUntilFinished];
}

- (void)testResumbleUploadCancelResumble {
    __block bool cancel = NO;
    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = _privateBucketName;
    resumableUpload.objectKey = OSS_MULTIPART_UPLOADKEY;
    resumableUpload.deleteUploadIdOnCancelling = NO;
    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.contentType = @"application/octet-stream";
    resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    resumableUpload.partSize = 100 * 1024;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        if(totalByteSent >= totalBytesExpectedToSend /2){
            cancel = YES;
        }
    };
    resumableUpload.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    OSSTask * resumeTask = [client resumableUpload:resumableUpload];
    [resumeTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        NSLog(@"error: %@", task.error);
        XCTAssertEqual(OSSClientErrorCodeTaskCancelled, task.error.code);
        return nil;
    }];
    
    while (!cancel) {
        [NSThread sleepForTimeInterval:0.1];
    }
    [resumableUpload cancel];
    [resumeTask waitUntilFinished];
    
    [NSThread sleepForTimeInterval:1];
    resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = _privateBucketName;
    resumableUpload.objectKey = OSS_MULTIPART_UPLOADKEY;
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.contentType = @"application/octet-stream";
    resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    resumableUpload.partSize = 100 * 1024;
    resumableUpload.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        XCTAssertGreaterThan(totalByteSent, totalBytesExpectedToSend / 3);
    };
    resumeTask = [client resumableUpload:resumableUpload];
    [[resumeTask continueWithBlock:^id(OSSTask *task) {
        NSLog(@"error: %@", task.error);
        XCTAssertNil(task.error);
        NSString * recordFilePath = [self getRecordFilePath:resumableUpload];
        XCTAssertTrue(![[NSFileManager defaultManager] fileExistsAtPath:recordFilePath]);
        return nil;
    }] waitUntilFinished];
    
}

- (void)testResumableUploadSmallFile {
    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = _privateBucketName;
    resumableUpload.objectKey = OSS_MULTIPART_UPLOADKEY;
    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.contentType = @"application/octet-stream";
    resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    resumableUpload.partSize = 1024 * 1024;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    NSString * docDir = [NSString oss_documentDirectory];
    resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1k"]];
    OSSTask * resumeTask = [client resumableUpload:resumableUpload];
    [[resumeTask continueWithBlock:^id(OSSTask *task) {
        NSLog(@"error: %@", task.error);
        XCTAssertNil(task.error);
        NSString * recordFilePath = [self getRecordFilePath:resumableUpload];
        XCTAssertTrue(![[NSFileManager defaultManager] fileExistsAtPath:recordFilePath]);
        return nil;
    }] waitUntilFinished];
    
    BOOL isEqual = [self isFileOnOSSBucket:_privateBucketName objectKey:OSS_MULTIPART_UPLOADKEY equalsToLocalFile:[resumableUpload.uploadingFileURL path]];
    XCTAssertTrue(isEqual);
}

- (void)testResumableUploadResumeUpload {
    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = _privateBucketName;
    resumableUpload.objectKey = OSS_MULTIPART_UPLOADKEY;
    resumableUpload.deleteUploadIdOnCancelling = NO;
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.contentType = @"application/octet-stream";
    resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    resumableUpload.partSize = 256 * 1024;
    __weak OSSResumableUploadRequest * upload = resumableUpload;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        if (totalByteSent > totalBytesExpectedToSend / 3) {
            [upload cancel];
        }
    };
    resumableUpload.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    OSSTask * resumeTask = [client resumableUpload:resumableUpload];
    [[resumeTask continueWithBlock:^id(OSSTask *task) {
        NSLog(@"error: %@", task.error);
        XCTAssertNotNil(task.error);
        XCTAssertEqual(OSSClientErrorCodeTaskCancelled, task.error.code);
        return nil;
    }] waitUntilFinished];
    
    resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = _privateBucketName;
    resumableUpload.objectKey = OSS_MULTIPART_UPLOADKEY;
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.contentType = @"application/octet-stream";
    resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    resumableUpload.partSize = 256 * 1024;
    resumableUpload.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        XCTAssertGreaterThan(totalByteSent, totalBytesExpectedToSend / 3);
    };
    resumeTask = [client resumableUpload:resumableUpload];
    [[resumeTask continueWithBlock:^id(OSSTask *task) {
        NSLog(@"error: %@", task.error);
        XCTAssertNil(task.error);
        NSString * recordFilePath = [self getRecordFilePath:resumableUpload];
        XCTAssertTrue(![[NSFileManager defaultManager] fileExistsAtPath:recordFilePath]);
        return nil;
    }] waitUntilFinished];
    
    
    BOOL isEqual = [self isFileOnOSSBucket:_privateBucketName objectKey:OSS_MULTIPART_UPLOADKEY equalsToLocalFile:[resumableUpload.uploadingFileURL path]];
    XCTAssertTrue(isEqual);
}

- (void)testResumableUploadwithinvalidpartSize {
    
    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = _privateBucketName;
    resumableUpload.objectKey = OSS_MULTIPART_UPLOADKEY;
    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.contentType = @"application/octet-stream";
    resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    resumableUpload.partSize = 1024;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    NSString * docDir = [NSString oss_documentDirectory];
    resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file10m"]];
    OSSTask * resumeTask = [client resumableUpload:resumableUpload];
    [[resumeTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(OSSClientErrorCodeInvalidArgument, task.error.code);
        NSLog(@"task.error: %@", task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testResumableUploadWithNotSetRecordPath{
    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = _privateBucketName;
    resumableUpload.objectKey = OSS_MULTIPART_UPLOADKEY;
    resumableUpload.contentType = @"application/octet-stream";
    resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    resumableUpload.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    OSSTask * resumeTask = [client resumableUpload:resumableUpload];
    [[resumeTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        NSString * recordFilePath = [self getRecordFilePath:resumableUpload];
        XCTAssertTrue(![[NSFileManager defaultManager] fileExistsAtPath:recordFilePath]);
        return nil;
    }] waitUntilFinished];
}

#pragma mark concurrent

- (void)testConcurrentPutObject {
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    __block int counter = 0;
    int max = 4;
    for (int i = 0; i < max; i++) {
        dispatch_async(test_queue, ^{
            OSSPutObjectRequest * request = [OSSPutObjectRequest new];
            request.bucketName = _privateBucketName;
            request.objectKey = [fileNameArray objectAtIndex:i];
            NSString * docDir = [NSString oss_documentDirectory];
            request.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:[fileNameArray objectAtIndex:i]]];
            request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
            request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
                NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
            };
            
            OSSTask * task = [client putObject:request];
            [[task continueWithBlock:^id(OSSTask *task) {
                XCTAssertNil(task.error);
                if (task.error) {
                    OSSLogError(@"%@", task.error);
                }
                OSSPutObjectResult * result = task.result;
                XCTAssertEqual(200, result.httpResponseCode);
                NSLog(@"Result - requestId: %@, headerFields: %@",
                      result.requestId,
                      result.httpResponseHeaderFields);
                return nil;
            }] waitUntilFinished];
            @synchronized(self) {
                counter ++;
                if (counter == max) {
                    [tcs setResult:nil];
                }
            }
        });
    }
    [tcs.task waitUntilFinished];
}

- (void)testConcurrentGetObject {
    [OSSTestUtils putTestDataWithKey:@"file1m" withClient:client withBucket:_privateBucketName];
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    __block int counter = 0;
    for (int i = 0; i < 5; i++) {
        dispatch_async(test_queue, ^{
            OSSGetObjectRequest * request = [OSSGetObjectRequest new];
            request.bucketName = _privateBucketName;
            request.objectKey = @"file1m";
            
            OSSTask * task = [client getObject:request];
            [[task continueWithBlock:^id(OSSTask *task) {
                XCTAssertNil(task.error);
                OSSGetObjectResult * result = task.result;
                XCTAssertEqual(200, result.httpResponseCode);
                XCTAssertEqual(1024 * 1024 * 1, [result.downloadedData length]);
                XCTAssertEqualObjects(@"1048576", [result.objectMeta objectForKey:@"Content-Length"]);
                NSLog(@"Result - requestId: %@, headerFields: %@, dataLength: %lu",
                      result.requestId,
                      result.httpResponseHeaderFields,
                      (unsigned long)[result.downloadedData length]);
                return nil;
            }] waitUntilFinished];
            @synchronized(self) {
                counter ++;
                if (counter == 5) {
                    [tcs setResult:nil];
                }
            }
        });
    }
    [tcs.task waitUntilFinished];
}

- (void)testSerialGetObjectWithConfiguration {
    [OSSTestUtils putTestDataWithKey:@"file1m" withClient:client withBucket:_privateBucketName];
    OSSClientConfiguration * configuration = [OSSClientConfiguration new];
    configuration.maxRetryCount = 2;
    configuration.timeoutIntervalForRequest = 30;
    configuration.timeoutIntervalForResource = 24 * 60 * 60;
    configuration.maxConcurrentRequestCount = 1;
    OSSClient * client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:credential clientConfiguration:configuration];
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    __block int counter = 0;
    for (int i = 0; i < 5; i++) {
        dispatch_async(test_queue, ^{
            OSSGetObjectRequest * request = [OSSGetObjectRequest new];
            request.bucketName = _privateBucketName;
            request.objectKey = @"file1m";
            
            OSSTask * task = [client getObject:request];
            [[task continueWithBlock:^id(OSSTask *task) {
                XCTAssertNil(task.error);
                OSSGetObjectResult * result = task.result;
                XCTAssertEqual(200, result.httpResponseCode);
                XCTAssertEqual(1024 * 1024 * 1, [result.downloadedData length]);
                XCTAssertEqualObjects(@"1048576", [result.objectMeta objectForKey:@"Content-Length"]);
                NSLog(@"Result - requestId: %@, headerFields: %@, dataLength: %lu",
                      result.requestId,
                      result.httpResponseHeaderFields,
                      (unsigned long)[result.downloadedData length]);
                return nil;
            }] waitUntilFinished];
            @synchronized(self) {
                counter ++;
                if (counter == 5) {
                    [tcs setResult:nil];
                }
            }
        });
    }
    [tcs.task waitUntilFinished];
}

- (void)testConcurrentCompatResumableUpload {
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    static int counter = 0;
    for (int i = 0; i < 5; i++) {
        dispatch_async(test_queue, ^{
            NSString * docDir = [NSString oss_documentDirectory];
            NSString * fileToUpload = [NSString stringWithFormat:@"%@/%@", docDir, @"file1m"];
            [client resumableUploadFile:fileToUpload
                        withContentType:@"application/octet-stream"
                         withObjectMeta:nil
                           toBucketName:_privateBucketName
                            toObjectKey:[NSString stringWithFormat:@"resumableUpload-%d", i]
                            onCompleted:^(BOOL isSuccess, NSError *error) {
                                NSLog(@"1. error: %@", error);
                                XCTAssertTrue(isSuccess);
                                @synchronized (self) {
                                    counter++;
                                    if (counter == 5) {
                                        [tcs setResult:nil];
                                    }
                                }
                            } onProgress:^(float progress) {
                                NSLog(@"%d. progress: %f", i, progress);
                            }];
        });
    }
    [tcs.task waitUntilFinished];
}

#pragma mark compat_test

- (void)testCompatResumableUpload {
    NSString * docDir = [NSString oss_documentDirectory];
    NSString * fileToUpload = [NSString stringWithFormat:@"%@/%@", docDir, @"file5m"];
    NSString * objectKey = @"resumableUpload0001";
    __block float progValue = 0;
    OSSTaskHandler * taskHandler = [client resumableUploadFile:fileToUpload
                                               withContentType:@"application/octet-stream"
                                                withObjectMeta:nil
                                                  toBucketName:_privateBucketName
                                                   toObjectKey:objectKey
                                                   onCompleted:^(BOOL isSuccess, NSError *error) {
                                                       NSLog(@"1. error: %@", error);
                                                       XCTAssertFalse(isSuccess);
                                                       XCTAssertEqual(error.code, OSSClientErrorCodeTaskCancelled);
                                                   } onProgress:^(float progress) {
                                                       NSLog(@"1. progress: %f", progress);
                                                       progValue = progress;
                                                   }];
    
    while (progValue < 0.5) {
        [NSThread sleepForTimeInterval:0.1];
        OSSLogError(@"sleep : %f", progValue);
    }
    
    [taskHandler cancel];
    
    OSSLogDebug(@"XCTest-------------cancelled!");
    OSSTaskCompletionSource * bcs = [OSSTaskCompletionSource taskCompletionSource];
    [client resumableUploadFile:fileToUpload
                withContentType:@"application/octet-stream"
                 withObjectMeta:nil
                   toBucketName:_privateBucketName
                    toObjectKey:objectKey
                    onCompleted:^(BOOL isSuccess, NSError *error) {
                        NSLog(@"2. error: %@", error);
                        XCTAssertTrue(isSuccess);
                        [bcs setResult:nil];
                    } onProgress:^(float progress) {
                        NSLog(@"2. progress: %f", progress);
                        if (progress < 0.4) {
                            /* should continue from last position which should larger than 0.5 */
                            XCTAssertTrue(false);
                        }
                    }];
    
    [bcs.task waitUntilFinished];
}

- (void)testCompatUploadObjectFromFile {
    NSString * docDir = [NSString oss_documentDirectory];
    NSString * fileToUpload = [NSString stringWithFormat:@"%@/%@", docDir, @"file1m"];
    __block float progValue = 0;
    
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    
    [client uploadFile:fileToUpload
       withContentType:@"application/octet-stream"
        withObjectMeta:nil
          toBucketName:_privateBucketName
           toObjectKey:@"compatFileUpload"
           onCompleted:^(BOOL isSuccess, NSError *error) {
               XCTAssertTrue(isSuccess);
               [tcs setResult:nil];
           } onProgress:^(float progress) {
               NSLog(@"Progress: %f", progress);
               progValue = progress;
           }];
    
    [tcs.task waitUntilFinished];
}

- (void)testCompatUploadObjectFromData {
    NSString * docDir = [NSString oss_documentDirectory];
    
    NSString * fileToUpload = [NSString stringWithFormat:@"%@/%@", docDir, @"file1m"];
    
    NSFileHandle * handle = [NSFileHandle fileHandleForReadingAtPath:fileToUpload];
    NSData * dataToUpload = [handle readDataToEndOfFile];
    
    __block float progValue = 0;
    
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    
    [client uploadData:dataToUpload
       withContentType:@"application/octet-stream"
        withObjectMeta:nil
          toBucketName:_privateBucketName
           toObjectKey:@"compatFileUpload"
           onCompleted:^(BOOL isSuccess, NSError *error) {
               XCTAssertTrue(isSuccess);
               [tcs setResult:nil];
           } onProgress:^(float progress) {
               NSLog(@"Progress: %f", progress);
               progValue = progress;
           }];
    
    [tcs.task waitUntilFinished];
}

- (void)testCompatDownload {
    [OSSTestUtils putTestDataWithKey:@"file1m" withClient:client withBucket:_privateBucketName];
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    
    [client downloadToDataFromBucket:_privateBucketName
                           objectKey:@"file1m"
                         onCompleted:^(NSData *data, NSError *error) {
                             XCTAssertNotNil(data);
                             [tcs setResult:nil];
                             XCTAssertEqual(1024 * 1024, [data length]);
                         } onProgress:^(float progress) {
                             NSLog(@"Progress: %f", progress);
                         }];
    
    [tcs.task waitUntilFinished];
}

- (void)testCompatDownloadToFile {
    [OSSTestUtils putTestDataWithKey:@"file1m" withClient:client withBucket:_privateBucketName];
    NSString * docDir = [NSString oss_documentDirectory];
    
    NSString * saveToFile = [NSString stringWithFormat:@"%@/%@", docDir, @"compatDownloadFile"];
    
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    
    [client downloadToFileFromBucket:_privateBucketName
                           objectKey:@"file1m"
                              toFile:saveToFile
                         onCompleted:^(BOOL isSuccess, NSError *error) {
                             XCTAssertTrue(isSuccess);
                             [tcs setResult:nil];
                             NSFileManager * fm = [NSFileManager defaultManager];
                             XCTAssertTrue([fm fileExistsAtPath:saveToFile]);
                             int64_t fileSize = [[[fm attributesOfItemAtPath:saveToFile
                                                                       error:nil] objectForKey:NSFileSize] longLongValue];
                             XCTAssertEqual(1024 * 1024, fileSize);
                         } onProgress:^(float progress) {
                             NSLog(@"Progress: %f", progress);
                         }];
    
    [tcs.task waitUntilFinished];
}

- (void)testCompatDeleteObject {
    [OSSTestUtils putTestDataWithKey:@"file1m" withClient:client withBucket:_privateBucketName];
    OSSCopyObjectRequest * copy = [OSSCopyObjectRequest new];
    copy.bucketName = _privateBucketName;
    copy.objectKey = @"file1m_copy";
    copy.sourceCopyFrom = [NSString stringWithFormat:@"/%@/%@", _privateBucketName, @"file1m"];
    [[[client copyObject:copy] continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    OSSHeadObjectRequest * head = [OSSHeadObjectRequest new];
    head.bucketName = _privateBucketName;
    head.objectKey = @"file1m_copy";
    
    [[[client headObject:head] continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    [client deleteObjectInBucket:_privateBucketName
                       objectKey:@"file1m_copy"
                     onCompleted:^(BOOL isSuccess, NSError *error) {
                         XCTAssertTrue(isSuccess);
                         [tcs setResult:nil];
                     }];
    
    [tcs.task waitUntilFinished];
    
    head = [OSSHeadObjectRequest new];
    head.bucketName = _privateBucketName;
    head.objectKey = @"file1m_copy";
    
    [[[client headObject:head] continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(-404, task.error.code);
        return nil;
    }] waitUntilFinished];
    
}

#pragma mark test UtilFunction

- (void)testHttpdns {
    NSString * host1 = @"oss-ap-southeast-1.aliyuncs.com";
    NSString * host2 = @"oss-us-east-1.aliyuncs.com";
    NSString * ip1 = [[OSSHttpdns sharedInstance] asynGetIpByHost:host1];
    ip1 = [[OSSHttpdns sharedInstance] asynGetIpByHost:host1];
    XCTAssertNil(ip1);
    
    NSString * ip2 = [[OSSHttpdns sharedInstance] asynGetIpByHost:host2];
    XCTAssertNil(ip2);
    
    sleep(3);
    
    ip1 = [[OSSHttpdns sharedInstance] asynGetIpByHost:host1];
    ip2 = [[OSSHttpdns sharedInstance] asynGetIpByHost:host2];
    XCTAssertNotNil(ip1);
    XCTAssertNotNil(ip2);
}

- (void)testDetemineMimeTypeFunction {
    NSString * filePath1 = @"/a/b/c/d/aaa.txt";
    NSString * uploadName1 = @"aaa";
    NSString * mimeType1 = [OSSUtil detemineMimeTypeForFilePath:filePath1 uploadName:uploadName1];
    XCTAssertEqualObjects(@"text/plain", mimeType1);
    
    NSString * filePath2 = @"/a/b/c/d/aaa";
    NSString * uploadName2 = @"aaa.txt";
    NSString * mimeType2 = [OSSUtil detemineMimeTypeForFilePath:filePath2 uploadName:uploadName2];
    XCTAssertEqualObjects(@"text/plain", mimeType2);
    
    NSString * filePath3 = @"/a/b/c/d/aaa";
    NSString * uploadName3 = @"aaa";
    NSString * mimeType3 = [OSSUtil detemineMimeTypeForFilePath:filePath3 uploadName:uploadName3];
    XCTAssertEqualObjects(@"application/octet-stream", mimeType3);
    
    NSString * filePath4 = @"/a/b/c/d/aaa";
    NSString * uploadName4 = @"aaa.jpg";
    NSString * mimeType4 = [OSSUtil detemineMimeTypeForFilePath:filePath4 uploadName:uploadName4];
    XCTAssertEqualObjects(@"image/jpeg", mimeType4);
}

- (void)testValidateName {
    XCTAssertFalse([OSSUtil validateBucketName:@"-abc"]);
    XCTAssertFalse([OSSUtil validateBucketName:@"abc.cde"]);
    XCTAssertFalse([OSSUtil validateBucketName:@"_adbdsf"]);
    XCTAssertFalse([OSSUtil validateBucketName:@"abc\\"]);
    XCTAssertFalse([OSSUtil validateBucketName:@"中文"]);
    XCTAssertTrue([OSSUtil validateBucketName:@"abc"]);
    XCTAssertTrue([OSSUtil validateBucketName:@"abc-abc"]);
    XCTAssertFalse([OSSUtil validateBucketName:@"abc-abc-"]);
    
    XCTAssertFalse([OSSUtil validateObjectKey:@"/abc"]);
    XCTAssertFalse([OSSUtil validateObjectKey:@"\\abc"]);
    XCTAssertFalse([OSSUtil validateObjectKey:@"\\中文"]);
    XCTAssertTrue([OSSUtil validateObjectKey:@"abc"]);
    XCTAssertTrue([OSSUtil validateObjectKey:@"abc中文"]);
    XCTAssertTrue([OSSUtil validateObjectKey:@"-中文"]);
    XCTAssertTrue([OSSUtil validateObjectKey:@"abc  "]);
    XCTAssertTrue([OSSUtil validateObjectKey:@"abc-sfds/sf-\\sfdssf"]);
    XCTAssertTrue([OSSUtil validateObjectKey:@" ?-+xsfs*sfds "]);
}

- (void) testUrlEncode{
    NSString * objectKey = @"test/a/汉字。，；：‘’“”？（）『』【】《》！@#￥%……&×/test+ =-_*&^%$#@!`~[]{}()<>|\\/?.,;";
    NSString * encodekey = [OSSUtil encodeURL:objectKey];
    
    NSString * encodedKey = @"test/a/%E6%B1%89%E5%AD%97%E3%80%82%EF%BC%8C%EF%BC%9B%EF%BC%9A%E2%80%98%E2%80%99%E2%80%9C%E2%80%9D%EF%BC%9F%EF%BC%88%EF%BC%89%E3%80%8E%E3%80%8F%E3%80%90%E3%80%91%E3%80%8A%E3%80%8B%EF%BC%81%40%23%EF%BF%A5%25%E2%80%A6%E2%80%A6%26%C3%97/test%2B%20%3D-_%2A%26%5E%25%24%23%40%21%60~%5B%5D%7B%7D%28%29%3C%3E%7C%5C/%3F.%2C%3B";
    XCTAssertTrue([encodekey isEqualToString:encodedKey]);
}



#pragma mark util

- (BOOL)isFileOnOSSBucket:(NSString *)bucketName objectKey:(NSString *)objectKey equalsToLocalFile:(NSString *)filePath {
    NSString * docDir = [NSString oss_documentDirectory];
    NSString * tempFile = [docDir stringByAppendingPathComponent:@"tempfile_for_check"];
    
    OSSGetObjectRequest * get = [OSSGetObjectRequest new];
    get.bucketName = bucketName;
    get.objectKey = objectKey;
    get.downloadToFileURL = [NSURL fileURLWithPath:tempFile];
    [[[client getObject:get] continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    NSString * remoteMD5 = [OSSUtil fileMD5String:tempFile];
    NSString * localMD5 = [OSSUtil fileMD5String:filePath];
    NSLog(@"%s - tempfile path: %@", __func__, tempFile);
    NSLog(@"%s - remote md5: %@ local md5: %@", __func__, remoteMD5, localMD5);
    return [remoteMD5 isEqualToString:localMD5];
}

#pragma mark filelog

- (void)testWriteFileLog {
    OSSLogDebug(@"----------TestDebug------------");
    [NSThread sleepForTimeInterval:(1)];
    unsigned long long filesize = [self getLogFileSize];
    XCTAssertTrue(filesize > 0);
}

- (void)testFileLogMaxSize {
    [NSThread sleepForTimeInterval:(1.0)];
    unsigned long long max_size = 1024;
    [OSSDDLog removeAllLoggers];
    OSSDDFileLogger *fileLogger = [[OSSDDFileLogger alloc] init];
    [[fileLogger logFileManager] createNewLogFile];
    [fileLogger setMaximumFileSize:max_size];
    [OSSDDLog addLogger:fileLogger];
    [NSThread sleepForTimeInterval:(1.0)];
    unsigned long long filesize = 0;
    while (filesize <= max_size) {
        OSSLogDebug(@"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
        [NSThread sleepForTimeInterval:(1.0)];
        filesize = [self getLogFileSize];
    }
    XCTAssertTrue(filesize > max_size);
    OSSLogDebug(@"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    [NSThread sleepForTimeInterval:(1.0)];
    filesize = [self getLogFileSize];
    XCTAssertTrue(filesize <= max_size);
    //revert file max size 5mb
    [fileLogger setMaximumFileSize:5 * 1024 * 1024];
}

- (void)testDisableFileLog {
    [OSSLog disableLog];
    OSSDDFileLogger *fileLogger = [[OSSDDFileLogger alloc] init];
    [[fileLogger logFileManager] createNewLogFile];
    OSSLogDebug(@"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    [NSThread sleepForTimeInterval:(1.0)];
    unsigned long long filesize = [self getLogFileSize];
    XCTAssertTrue(filesize == 0);
    [OSSLog enableLog];
}

- (unsigned long long)getLogFileSize {
    OSSDDFileLogger *fileLogger = [[OSSDDFileLogger alloc] init];
    NSArray *arr = [[fileLogger logFileManager] sortedLogFileInfos];
    unsigned long long filesize = [arr[0] fileSize];
    return filesize;
}

- (void)testOSSAuthCredentialProvider {
    [OSSTestUtils putTestDataWithKey:@"file1m" withClient:client withBucket:_privateBucketName];
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file1m";
    
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    id<OSSCredentialProvider> provider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    
    OSSClient * client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:provider];
    
    OSSTask * task = [client getObject:request];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        XCTAssertEqual(1024 * 1024, [result.downloadedData length]);
        XCTAssertEqualObjects(@"1048576", [result.objectMeta objectForKey:@"Content-Length"]);
        NSLog(@"Result - requestId: %@, headerFields: %@, dataLength: %lu",
              result.requestId,
              result.httpResponseHeaderFields,
              (unsigned long)[result.downloadedData length]);
        return nil;
    }] waitUntilFinished];
}

#pragma mark - crc64ecma check
- (void)testForCrc64Error
{
    __block NSString * uploadId = nil;
    __block NSMutableArray * partInfos = [NSMutableArray array];
    OSSInitMultipartUploadRequest * init = [OSSInitMultipartUploadRequest new];
    init.bucketName = _privateBucketName;
    init.objectKey = OSS_MULTIPART_UPLOADKEY;
    init.contentType = @"application/octet-stream";
    init.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    OSSTask * task = [client multipartUploadInit:init];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSInitMultipartUploadResult * result = task.result;
        XCTAssertNotNil(result.uploadId);
        uploadId = result.uploadId;
        return nil;
    }] waitUntilFinished];
    
    int chuckCount = 7;
    for (int i = 0; i < chuckCount; i++)
    {
        OSSUploadPartRequest * uploadPart = [OSSUploadPartRequest new];
        uploadPart.bucketName = _privateBucketName;
        uploadPart.objectkey = OSS_MULTIPART_UPLOADKEY;
        uploadPart.uploadId = uploadId;
        uploadPart.partNumber = i+1; // part number start from 1
        NSString * filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"file1m"];
        uint64_t fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil] fileSize];
        OSSLogVerbose(@" testMultipartUpload filesize: %llu", fileSize);
        uint64_t offset = fileSize / chuckCount;
        OSSLogVerbose(@" testMultipartUpload offset: %llu", offset);
        
        NSFileHandle* readHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
        [readHandle seekToFileOffset:offset * i];
        
        NSData* data;
        if (i+1 == chuckCount)
        {
            NSUInteger lastLength = offset + fileSize % chuckCount;
            data = [readHandle readDataOfLength:lastLength];
        }else
        {
            data = [readHandle readDataOfLength:offset];
        }
        
        uploadPart.uploadPartData = data;
        NSUInteger partSize = data.length;
        NSTimeInterval startUpload = [[NSDate date] timeIntervalSince1970];
        task = [client uploadPart:uploadPart];
        [[task continueWithBlock:^id(OSSTask *task) {
            XCTAssertNil(task.error);
            OSSUploadPartResult * result = task.result;
            XCTAssertNotNil(result.eTag);
            
            uint64_t remoteCrc64ecma;
            NSScanner *scanner = [NSScanner scannerWithString:result.remoteCRC64ecma];
            [scanner scanUnsignedLongLong:&remoteCrc64ecma];
            if (i == 2) {
                remoteCrc64ecma += 1;
            }
            
            [partInfos addObject:[OSSPartInfo partInfoWithPartNum:i+1 eTag:result.eTag size:partSize crc64:remoteCrc64ecma]];
            return nil;
        }] waitUntilFinished];
        NSTimeInterval endUpload = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval cost = endUpload - startUpload;
        OSSLogDebug(@"part num: %d  upload part cost time: %f", i, cost);
    }
    
    __block uint64_t localCrc64 = 0;
    [partInfos enumerateObjectsUsingBlock:^(OSSPartInfo *partInfo, NSUInteger idx, BOOL * _Nonnull stop) {
        if (localCrc64 == 0)
        {
            localCrc64 = partInfo.crc64;
        }else
        {
            localCrc64 = [OSSUtil crc64ForCombineCRC1:localCrc64 CRC2:partInfo.crc64 length:partInfo.size];
        }
    }];
    
    OSSCompleteMultipartUploadRequest * complete = [OSSCompleteMultipartUploadRequest new];
    complete.bucketName = _privateBucketName;
    complete.objectKey = OSS_MULTIPART_UPLOADKEY;
    complete.uploadId = uploadId;
    complete.partInfos = partInfos;
    complete.crcFlag = OSSRequestCRCOpen;
    
    task = [client completeMultipartUpload:complete];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSCompleteMultipartUploadResult * result = task.result;
        XCTAssertNotNil(result.location);
        uint64_t remoteCrc64ecma;
        NSScanner *scanner = [NSScanner scannerWithString:result.remoteCRC64ecma];
        [scanner scanUnsignedLongLong:&remoteCrc64ecma];
        XCTAssertNotEqual(localCrc64, remoteCrc64ecma);
        return nil;
    }] waitUntilFinished];
}

- (void)testConcurrencyMultipartUpload
{
    __block BOOL finished = NO,complete = NO;
    OSSMultipartUploadRequest * multipartUploadRequest = [OSSMultipartUploadRequest new];
    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.bucketName = _privateBucketName;
    multipartUploadRequest.objectKey = OSS_MULTIPART_UPLOADKEY;
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.partSize = 100 * 1024;
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    multipartUploadRequest.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    OSSTask * multipartTask = [client multipartUpload:multipartUploadRequest];
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[multipartTask continueWithBlock:^id(OSSTask *task) {
            XCTAssertNil(task.error);
            if (task.error) {
                NSLog(@"error: %@", task.error);
                if ([task.error.domain isEqualToString:OSSClientErrorDomain] && task.error.code == OSSClientErrorCodeCannotResumeUpload) {
                    // The upload cannot be resumed. Needs to re-initiate a upload.
                }
            } else {
                NSLog(@"Upload file success");
            }
            finished = YES;
            return nil;
        }] waitUntilFinished];
    });
    
    OSSMultipartUploadRequest *request = [OSSMultipartUploadRequest new];
    request.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.bucketName = _privateBucketName;
    request.objectKey = OSS_MULTIPART_UPLOADKEY;
    request.contentType = @"application/octet-stream";
    request.partSize = 100 * 1024;
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    request.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    OSSClient *newClient = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:[[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL]];
    OSSTask * otherTask = [newClient multipartUpload:request];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[otherTask continueWithBlock:^id(OSSTask *task) {
            XCTAssertNil(task.error);
            if (task.error) {
                NSLog(@"error: %@", task.error);
                if ([task.error.domain isEqualToString:OSSClientErrorDomain] && task.error.code == OSSClientErrorCodeCannotResumeUpload) {
                    // The upload cannot be resumed. Needs to re-initiate a upload.
                }
            } else {
                NSLog(@"Upload file success");
            }
            complete = YES;
            return nil;
        }] waitUntilFinished];
    });
    
    while (!complete || !finished) {
        OSSLogVerbose(@"上传任务执行中");
    }
    //    BOOL isEqual = [self isFileOnOSSBucket:OSS_BUCKET_PRIVATE objectKey:OSS_MULTIPART_UPLOADKEY equalsToLocalFile:[multipartUploadRequest.uploadingFileURL path]];
    //    XCTAssertTrue(isEqual);
}

- (void)testImagePersist {
    OSSImagePersistRequest *request = [OSSImagePersistRequest new];
    request.fromBucket = _privateBucketName;
    request.fromObject = OSS_IMAGE_KEY;
    request.toBucket = _privateBucketName;
    request.toObject = @"image_persist_key";
    request.action = @"image/resize,w_100";
    //request.action = @"resize,w_100";也可以
    
    [[[client imageActionPersist:request] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}



#pragma mark - token update
/*
- (void)testZZZTokenUpdate {
    if (![client.credentialProvider isKindOfClass:[OSSFederationCredentialProvider class]]) {
        return;
    }
    
    for (int i = 0; i < 16; i++) {
        OSSPutObjectRequest * request = [OSSPutObjectRequest new];
        request.bucketName = OSS_BUCKET_PRIVATE;
        request.objectKey = @"file1m";
        
        NSString * docDir = [NSString oss_documentDirectory];
        NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
        NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
        
        request.uploadingData = [readFile readDataToEndOfFile];
        request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
        request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
            NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        };
        
        OSSTask * task = [client putObject:request];
        [[task continueWithBlock:^id(OSSTask *task) {
            XCTAssertNil(task.error);
            if (task.error) {
                OSSLogError(@"%@", task.error);
            }
            OSSPutObjectResult * result = task.result;
            XCTAssertEqual(200, result.httpResponseCode);
            NSLog(@"Result - requestId: %@, headerFields: %@",
                  result.requestId,
                  result.httpResponseHeaderFields);
            return nil;
        }] waitUntilFinished];
        [NSThread sleepForTimeInterval:60];
    }
}
*/
@end

