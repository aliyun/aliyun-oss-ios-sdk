//
//  AliyunOSSiOSTests.m
//  AliyunOSSiOSTests
//
//  Created by zhouzhuo on 9/16/15.
//  Copyright (c) 2015 zhouzhuo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "OSSService.h"
#import "OSSModel.h"
#import "OSSCompat.h"

@interface oss_ios_sdk_newTests : XCTestCase

@end

NSString * const g_AK = @"<your access key>";
NSString * const g_SK = @"<your secret key>";
NSString * const TEST_BUCKET = @"mbaas-test1";
NSString * const BUGFIX_BUCKET = @"bugfix-test";
NSString * const PUBLIC_BUCKET = @"public-read-write-android";
NSString * const ENDPOINT = @"http://oss-cn-hangzhou.aliyuncs.com";
NSString * const MultipartUploadObjectKey = @"multipartUploadObject";

static NSArray * fileNameArray;
static NSArray * fileSizeArray;
static OSSClient * client;
static dispatch_queue_t test_queue;

id<OSSCredentialProvider> credential1, credential2, credential3;

@implementation oss_ios_sdk_newTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fileNameArray = @[@"file1k", @"file10k", @"file100k", @"file1m", @"file10m", @"fileDirA/", @"fileDirB/"];
        fileSizeArray = @[@1024, @10240, @102400, @1024000, @10240000, @1024, @1024];
        [self initWithAKSK];
        [self initLocalFiles];
        test_queue = dispatch_queue_create("com.aliyun.oss.test", DISPATCH_QUEUE_CONCURRENT);
    });
}

- (NSString *)getDocumentDirectory {
    NSString * path = NSHomeDirectory();
    NSLog(@"NSHomeDirectory:%@",path);
    NSString * userName = NSUserName();
    NSString * rootPath = NSHomeDirectoryForUser(userName);
    NSLog(@"NSHomeDirectoryForUser:%@",rootPath);
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * documentsDirectory = [paths objectAtIndex:0];
    return documentsDirectory;
}

- (void)initLocalFiles {
    NSFileManager * fm = [NSFileManager defaultManager];
    NSString * mainDir = [self getDocumentDirectory];

    NSMutableData * basePart = [NSMutableData dataWithCapacity:1024];
    for (int i = 0; i < 1024/4; i++) {
        u_int32_t randomBit = i; // arc4random();
        [basePart appendBytes:(void*)&randomBit length:4];
    }

    for (int i = 0; i < [fileNameArray count]; i++) {
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

- (void)initWithAKSK {
    [OSSLog enableLog];

    credential1 = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:g_AK
                                                                                                            secretKey:g_SK];

    // 自实现签名，可以用本地签名也可以远程加签
    credential2 = [[OSSCustomSignerCredentialProvider alloc] initWithImplementedSigner:^NSString *(NSString *contentToSign, NSError *__autoreleasing *error) {
        NSString *signature = [OSSUtil calBase64Sha1WithData:contentToSign withSecret:g_SK];
        if (signature != nil) {
            *error = nil;
        } else {
            // construct error object
            *error = [NSError errorWithDomain:@"<your error domain>" code:OSSClientErrorCodeSignFailed userInfo:nil];
            return nil;
        }
        return [NSString stringWithFormat:@"OSS %@:%@", g_AK, signature];
    }];

    // Federation鉴权，建议通过访问远程业务服务器获取签名
    // 假设访问业务服务器的获取token服务时，返回的数据格式如下：
    // {"accessKeyId":"STS.iA645eTOXEqP3cg3VeHf",
    // "accessKeySecret":"rV3VQrpFQ4BsyHSAvi5NVLpPIVffDJv4LojUBZCf",
    // "expiration":1441593388000,
    // "federatedUser":"335450541522398178:alice-001",
    // "requestId":"C0E01B94-332E-4582-87F9-B857C807EE52",
    // "securityToken":"CAES7QIIARKAAZPlqaN9ILiQZPS+JDkS/GSZN45RLx4YS/p3OgaUC+oJl3XSlbJ7StKpQp1Q3KtZVCeAKAYY6HYSFOa6rU0bltFXAPyW+jvlijGKLezJs0AcIvP5a4ki6yHWovkbPYNnFSOhOmCGMmXKIkhrRSHMGYJRj8AIUvICAbDhzryeNHvUGhhTVFMuaUE2NDVlVE9YRXFQM2NnM1ZlSGYiEjMzNTQ1MDU0MTUyMjM5ODE3OCoJYWxpY2UtMDAxMOG/g7v6KToGUnNhTUQ1QloKATEaVQoFQWxsb3cSHwoMQWN0aW9uRXF1YWxzEgZBY3Rpb24aBwoFb3NzOioSKwoOUmVzb3VyY2VFcXVhbHMSCFJlc291cmNlGg8KDWFjczpvc3M6KjoqOipKEDEwNzI2MDc4NDc4NjM4ODhSAFoPQXNzdW1lZFJvbGVVc2VyYABqEjMzNTQ1MDU0MTUyMjM5ODE3OHIHeHljLTAwMQ=="}
    credential3 = [[OSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^OSSFederationToken * {
        NSURL * url = [NSURL URLWithString:@"http://localhost:8080/distribute-token.json"];
        NSURLRequest * request = [NSURLRequest requestWithURL:url];
        BFTaskCompletionSource * tcs = [BFTaskCompletionSource taskCompletionSource];
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
            OSSFederationToken * token = [OSSFederationToken new];
            token.tAccessKey = [object objectForKey:@"accessKeyId"];
            token.tSecretKey = [object objectForKey:@"accessKeySecret"];
            token.tToken = [object objectForKey:@"securityToken"];
            OSSLogDebug(@"expirationString: %@", [object objectForKey:@"expiration"]);
            token.expirationTimeInMilliSecond = [[object objectForKey:@"expiration"] longLongValue];
            OSSLogDebug(@"%@\n%@\n%@\n%lld", token.tAccessKey, token.tSecretKey, token.tToken, token.expirationTimeInMilliSecond);
            return token;
        }
    }];


    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    conf.maxRetryCount = 3;
    conf.enableBackgroundTransmitService = YES;
    conf.timeoutIntervalForRequest = 15;
    conf.timeoutIntervalForResource = 24 * 60 * 60;

    client = [[OSSClient alloc] initWithEndpoint:ENDPOINT credentialProvider:credential3 clientConfiguration:conf];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#pragma mark normal_test

- (void)testCreateBucket {
    if ([client.credentialProvider isKindOfClass:[OSSFederationCredentialProvider class]]) {
        return; // we need the account owner's ak/sk to create bucket; federation token can't do this
    }
    OSSCreateBucketRequest * create = [OSSCreateBucketRequest new];
    create.bucketName = @"create-zhouzhuo-bucket";
    create.xOssACL = @"public-read";
    create.location = @"oss-cn-hangzhou";

    [[[client createBucket:create] continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testDeleteBucket {
    if ([client.credentialProvider isKindOfClass:[OSSFederationCredentialProvider class]]) {
        return; // we need the account owner's ak/sk to create bucket; federation token can't do this
    }
    OSSDeleteBucketRequest * delete = [OSSDeleteBucketRequest new];
    delete.bucketName = @"create-zhouzhuo-bucket";

    [[[client deleteBucket:delete] continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        NSLog(@"error: %@", task.error);
        OSSDeleteBucketResult * result = task.result;
        XCTAssertEqual(204, result.httpResponseCode);
        return nil;
    }] waitUntilFinished];
}

- (void)testA_putObjectFromFile {
    for (int i = 0; i < [fileNameArray count]; i++) {
        OSSPutObjectRequest * request = [OSSPutObjectRequest new];
        request.bucketName = TEST_BUCKET;
        request.objectKey = [fileNameArray objectAtIndex:i];
        NSString * docDir = [self getDocumentDirectory];
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
    }
}

- (void)testA_putObjectWithContentType {
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file1m";

    NSString * docDir = [self getDocumentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];

    request.uploadingData = [readFile readDataToEndOfFile];
    request.contentType = @"application/special";
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

    OSSHeadObjectRequest * head = [OSSHeadObjectRequest new];
    head.bucketName = TEST_BUCKET;
    head.objectKey = @"file1m";

    [[[client headObject:head] continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSHeadObjectResult * headResult = task.result;
        XCTAssertEqualObjects([headResult.objectMeta objectForKey:@"Content-Type"], @"application/special");
        return nil;
    }] waitUntilFinished];
}

- (void)testA_putObjectFromNSData {
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file1m";

    NSString * docDir = [self getDocumentDirectory];
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
}

- (void)testA_putObjectToPublicBucket {
    for (int i = 0; i < [fileNameArray count]; i++) {
        OSSPutObjectRequest * request = [OSSPutObjectRequest new];
        request.bucketName = PUBLIC_BUCKET;
        request.isAuthenticationRequired = NO;
        request.objectKey = [fileNameArray objectAtIndex:i];
        NSString * docDir = [self getDocumentDirectory];
        NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:[fileNameArray objectAtIndex:i]]];
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
    }
}

- (void)testA_putObjectWithServerCallback {
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file100k";
    NSString * docDir = [self getDocumentDirectory];
    request.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file100k"]];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1",
                          @"eyJjYWxsYmFja1VybCI6IjExMC43NS44Mi4xMDYvbWJhYXMvY2FsbGJhY2siLCAiY2FsbGJhY2tCb2R5IjoidGVzdCJ9", @"x-oss-callback", nil];
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
        NSLog(@"Result - requestId: %@, headerFields: %@, servercallback: %@",
              result.requestId,
              result.httpResponseHeaderFields,
              result.serverReturnJsonString);
        return nil;
    }] waitUntilFinished];
}

- (void)testA_appendObject {
    OSSDeleteObjectRequest * delete = [OSSDeleteObjectRequest new];
    delete.bucketName = TEST_BUCKET;
    delete.objectKey = @"appendObject";
    OSSTask * task = [client deleteObject:delete];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDeleteObjectResult * result = task.result;
        XCTAssertEqual(204, result.httpResponseCode);
        return nil;
    }] waitUntilFinished];

    OSSAppendObjectRequest * request = [OSSAppendObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"appendObject";
    request.appendPosition = 0;
    NSString * docDir = [self getDocumentDirectory];
    request.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file100k"]];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };

    task = [client appendObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        if (task.error) {
            OSSLogError(@"%@", task.error);
        }
        OSSAppendObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        XCTAssertTrue(result.xOssNextAppendPosition > 0);
        NSLog(@"Result - requestId: %@, headerFields: %@",
              result.requestId,
              result.httpResponseHeaderFields);
        return nil;
    }] waitUntilFinished];
}

- (void)testGetBucket {
    OSSGetBucketRequest * request = [OSSGetBucketRequest new];
    request.bucketName = TEST_BUCKET;
    request.delimiter = @"";
    request.marker = @"";
    request.maxKeys = 1000;
    request.prefix = @"";

    OSSTask * task = [client getBucket:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertTrue([task isCompleted]);
        XCTAssertNil(task.error);
        OSSGetBucketResult * result = task.result;
        NSLog(@"GetBucket prefixed: %@", result.commentPrefixes);
        XCTAssertEqualObjects(result.bucketName, TEST_BUCKET);
        XCTAssertNotEqual(0, [result.contents count]);
        for (NSDictionary * objectInfo in result.contents) {
            XCTAssertNotNil([objectInfo objectForKey:@"Key"]);
            XCTAssertNotNil([objectInfo objectForKey:@"Size"]);
            XCTAssertNotNil([objectInfo objectForKey:@"LastModified"]);
        }
        return nil;
    }] waitUntilFinished];


    request = [OSSGetBucketRequest new];
    request.bucketName = TEST_BUCKET;
    request.prefix = @"fileDir";
    request.delimiter = @"/";

    task = [client getBucket:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        if (task.error) {
            NSLog(@"GetBucketError: %@", task.error);
        }
        XCTAssertTrue([task isCompleted]);
        OSSGetBucketResult * result = task.result;
        NSLog(@"GetBucket prefixed: %@", result.commentPrefixes);
        XCTAssertEqualObjects(result.bucketName, TEST_BUCKET);
        XCTAssertEqual(result.httpResponseCode, 200);
        XCTAssertTrue([result.commentPrefixes containsObject:@"fileDirA/"]);
        return nil;
    }] waitUntilFinished];
}

- (void)testGetObject {
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file1m";

    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };

    OSSTask * task = [client getObject:request];

    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        XCTAssertEqual(1024000, [result.downloadedData length]);
        XCTAssertEqualObjects(@"1024000", [result.objectMeta objectForKey:@"Content-Length"]);
        NSLog(@"Result - requestId: %@, headerFields: %@, dataLength: %lu",
              result.requestId,
              result.httpResponseHeaderFields,
              (unsigned long)[result.downloadedData length]);
        return nil;
    }] waitUntilFinished];
}

- (void)testGetObjectWithRange {
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file1m";
    request.range = [[OSSRange alloc] initWithStart:0 withEnd:99]; // bytes=0-99
    // request.range = [[OSSRange alloc] initWithStart:-1 withEnd:99]; // bytes=-99
    // request.range = [[OSSRange alloc] initWithStart:10 withEnd:-1]; // bytes=10-

    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };

    OSSTask * task = [client getObject:request];

    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetObjectResult * result = task.result;
        XCTAssertEqual(206, result.httpResponseCode);
        XCTAssertEqual(100, [result.downloadedData length]);
        XCTAssertEqualObjects(@"100", [result.objectMeta objectForKey:@"Content-Length"]);
        NSLog(@"Result - requestId: %@, headerFields: %@, dataLength: %lu",
              result.requestId,
              result.httpResponseHeaderFields,
              (unsigned long)[result.downloadedData length]);
        return nil;
    }] waitUntilFinished];
}

- (void)testGetObjectByPartiallyRecieveData {
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file1m";

    NSMutableData * recieveData = [NSMutableData new];

    request.onRecieveData = ^(NSData * data) {
        [recieveData appendData:data];
    };

    OSSTask * task = [client getObject:request];

    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        XCTAssertEqual(1024000, [recieveData length]);
        NSLog(@"Result - requestId: %@, headerFields: %@",
              result.requestId,
              result.httpResponseHeaderFields);
        return nil;
    }] waitUntilFinished];
}

- (void)testGetObjectFromPublicBucket {
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = PUBLIC_BUCKET;
    request.isAuthenticationRequired = NO;
    request.objectKey = @"file1m";

    NSString * docDir = [self getDocumentDirectory];
    NSString * saveToFilePath = [docDir stringByAppendingPathComponent:@"downloadFromPublicBucket"];
    request.downloadToFileURL = [NSURL fileURLWithPath:saveToFilePath];

    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };

    OSSTask * task = [client getObject:request];

    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        XCTAssertEqualObjects(@"1024000", [result.objectMeta objectForKey:@"Content-Length"]);
        NSLog(@"Result - requestId: %@, headerFields: %@",
              result.requestId,
              result.httpResponseHeaderFields);
        NSFileManager * fm = [NSFileManager defaultManager];
        XCTAssertTrue([fm fileExistsAtPath:request.downloadToFileURL.path]);
        int64_t fileLength = [[[fm attributesOfItemAtPath:request.downloadToFileURL.path
                                                    error:nil] objectForKey:NSFileSize] longLongValue];
        XCTAssertEqual(1024000, fileLength);
        return nil;
    }] waitUntilFinished];
}

- (void)testHeadObject {
    OSSHeadObjectRequest * request = [OSSHeadObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file1m";

    OSSTask * task = [client headObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSHeadObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        XCTAssertEqualObjects(@"1024000", [result.httpResponseHeaderFields objectForKey:@"Content-Length"]);
        for (NSString * key in result.objectMeta) {
            NSLog(@"ObjectMeta: %@ - %@", key, [result.objectMeta objectForKey:key]);
        }
        return nil;
    }] waitUntilFinished];
}

- (void)testCopyAndDeleteObject {
    OSSHeadObjectRequest * head = [OSSHeadObjectRequest new];
    head.bucketName = TEST_BUCKET;
    head.objectKey = @"file1m_copyTo";
    OSSTask * task = [client headObject:head];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(-404, task.error.code);
        NSLog(@"404 error: %@", task.error);
        return nil;
    }] waitUntilFinished];

    OSSCopyObjectRequest * copy = [OSSCopyObjectRequest new];
    copy.bucketName = TEST_BUCKET;
    copy.objectKey = @"file1m_copyTo";
    copy.sourceCopyFrom = [NSString stringWithFormat:@"/%@/%@", TEST_BUCKET, @"file1m"];
    task = [client copyObject:copy];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSCopyObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        NSString * headerEtag = [result.httpResponseHeaderFields objectForKey:@"Etag"];
        NSString * bodyEtag = result.eTag;
        XCTAssertEqualObjects(headerEtag, bodyEtag);
        return nil;
    }] waitUntilFinished];

    OSSDeleteObjectRequest * delete = [OSSDeleteObjectRequest new];
    delete.bucketName = TEST_BUCKET;
    delete.objectKey = @"file1m_copyTo";
    task = [client deleteObject:delete];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDeleteObjectResult * result = task.result;
        XCTAssertEqual(204, result.httpResponseCode);
        return nil;
    }] waitUntilFinished];
}

- (void)testMultipartUpload {
    __block NSString * uploadId = nil;
    __block NSMutableArray * partInfos = [NSMutableArray new];
    OSSInitMultipartUploadRequest * init = [OSSInitMultipartUploadRequest new];
    init.bucketName = TEST_BUCKET;
    init.objectKey = MultipartUploadObjectKey;
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

    for (int i = 1; i <= 3; i++) {
        OSSUploadPartRequest * uploadPart = [OSSUploadPartRequest new];
        uploadPart.bucketName = TEST_BUCKET;
        uploadPart.objectkey = MultipartUploadObjectKey;
        uploadPart.uploadId = uploadId;
        uploadPart.partNumber = i; // part number start from 1
        NSString * docDir = [self getDocumentDirectory];
        uploadPart.uploadPartFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
        uint64_t fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:uploadPart.uploadPartFileURL.absoluteString error:nil] fileSize];
        OSSLogError(@"filesize: %llu", fileSize);
        task = [client uploadPart:uploadPart];
        [[task continueWithBlock:^id(OSSTask *task) {
            XCTAssertNil(task.error);
            OSSUploadPartResult * result = task.result;
            XCTAssertNotNil(result.eTag);
            [partInfos addObject:[OSSPartInfo partInfoWithPartNum:i eTag:result.eTag size:fileSize]];
            return nil;
        }] waitUntilFinished];
    }

    OSSCompleteMultipartUploadRequest * complete = [OSSCompleteMultipartUploadRequest new];
    complete.bucketName = TEST_BUCKET;
    complete.objectKey = MultipartUploadObjectKey;
    complete.uploadId = uploadId;
    complete.partInfos = partInfos;
    task = [client completeMultipartUpload:complete];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSCompleteMultipartUploadResult * result = task.result;
        XCTAssertNotNil(result.location);
        return nil;
    }] waitUntilFinished];

    OSSHeadObjectRequest * head = [OSSHeadObjectRequest new];
    head.bucketName = TEST_BUCKET;
    head.objectKey = MultipartUploadObjectKey;
    task = [client headObject:head];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSHeadObjectResult * result = task.result;
        __block BOOL exist = false;
        [result.objectMeta enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSString * theKey = key;
            NSString * theValue = obj;
            if ([theKey isEqualToString:@"x-oss-meta-name1"]) {
                XCTAssertEqualObjects(@"value1", theValue);
                exist = true;
            }
        }];
        XCTAssertTrue(exist);
        return nil;
    }] waitUntilFinished];
}

- (void)testAbortMultipartUpload {
    __block NSString * uploadId = nil;
    OSSInitMultipartUploadRequest * init = [OSSInitMultipartUploadRequest new];
    init.bucketName = TEST_BUCKET;
    init.objectKey = MultipartUploadObjectKey;
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
    abort.bucketName = TEST_BUCKET;
    abort.objectKey = MultipartUploadObjectKey;
    abort.uploadId = uploadId;

    OSSTask * abortTask = [client abortMultipartUpload:abort];

    [abortTask waitUntilFinished];

    XCTAssertNil(abortTask.error);
    OSSAbortMultipartUploadResult * abortResult = abortTask.result;
    XCTAssertEqual(204, abortResult.httpResponseCode);
}

- (void)testTimeSkewedButAutoRetry {
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file1m";

    [NSDate oss_setClockSkew:-1 * 30 * 60];

    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };

    OSSTask * task = [client getObject:request];

    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testPutObjectWithCheckingDataMd5 {
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file1m";

    NSString * docDir = [self getDocumentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];

    request.uploadingData = [readFile readDataToEndOfFile];
    request.contentMd5 = [OSSUtil base64Md5ForData:request.uploadingData];
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
}

- (void)testPutObjectWithCheckingFileMd5 {
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = PUBLIC_BUCKET;
    request.isAuthenticationRequired = NO;
    request.objectKey = @"file1m";
    request.contentType = @"application/octet-stream";

    NSString * docDir = [self getDocumentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];

    request.uploadingFileURL = fileURL;
    request.contentMd5 = [OSSUtil base64Md5ForFilePath:fileURL.path];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        // NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
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
}

- (void)testAccessViaHttpProxy {
    OSSClientConfiguration * conf = [OSSClientConfiguration new];

    conf.proxyHost = @"test";
    if ([conf.proxyHost isEqualToString:@"test"]) {
        /* your have to set your own proxy to run */
        return;
    }
    conf.proxyPort = @(8088);

    OSSClient * testProxyClient = [[OSSClient alloc] initWithEndpoint:ENDPOINT
                                                   credentialProvider:client.credentialProvider
                                                  clientConfiguration:conf];

    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = TEST_BUCKET;
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

- (void)testPresignConstrainURL {
    OSSTask * tk = [client presignConstrainURLWithBucketName:TEST_BUCKET
                                                 withObjectKey:@"file1k"
                                        withExpirationInterval:30 * 60];
    XCTAssertNil(tk.error);
    if (tk.error) {
        NSLog(@"error: %@", tk.error);
    } else {
        NSLog(@"url: %@", (NSString *)tk.result);
    }
    NSURLRequest * request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:tk.result]];
    NSURLSession * session = [NSURLSession sharedSession];
    BFTaskCompletionSource * tcs = [BFTaskCompletionSource taskCompletionSource];
    NSURLSessionDataTask * dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * data, NSURLResponse * response, NSError * error) {
        XCTAssertNil(error);
        XCTAssertEqual(200, ((NSHTTPURLResponse *)response).statusCode);
        XCTAssertEqual(1024, [data length]);
        [tcs setResult:nil];
    }];
    [dataTask resume];
    [tcs.task waitUntilFinished];
}

- (void)testPresignPublicURL {
    OSSTask * task = [client presignPublicURLWithBucketName:PUBLIC_BUCKET withObjectKey:@"file1k"];
    XCTAssertNil(task.error);
    NSURLRequest * request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:task.result]];
    NSURLSession * session = [NSURLSession sharedSession];
    BFTaskCompletionSource * tcs = [BFTaskCompletionSource taskCompletionSource];
    NSURLSessionDataTask * dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * data, NSURLResponse * response, NSError * error) {
        XCTAssertNil(error);
        XCTAssertEqual(200, ((NSHTTPURLResponse *)response).statusCode);
        XCTAssertEqual(1024, [data length]);
        [tcs setResult:nil];
    }];
    [dataTask resume];
    [tcs.task waitUntilFinished];
}

- (void)testMultiClientInstance {
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    conf.maxRetryCount = 3;
    conf.enableBackgroundTransmitService = NO;
    conf.timeoutIntervalForRequest = 15;
    conf.timeoutIntervalForResource = 24 * 60 * 60;

    OSSClient * client1 = [[OSSClient alloc] initWithEndpoint:@"http://oss-cn-hangzhou.aliyuncs.com"
                                           credentialProvider:credential3
                                          clientConfiguration:conf];

    conf = [OSSClientConfiguration new];
    conf.maxRetryCount = 3;
    conf.enableBackgroundTransmitService = YES;
    conf.backgroundSesseionIdentifier = @"test_other_backgroundservice-enbaled_client";
    conf.timeoutIntervalForRequest = 15;
    conf.timeoutIntervalForResource = 24 * 60 * 60;
    OSSClient * client2 = [[OSSClient alloc] initWithEndpoint:@"http://oss-cn-hangzhou.aliyuncs.com"
                                           credentialProvider:credential3
                                          clientConfiguration:conf];

    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file1m";

    NSString * docDir = [self getDocumentDirectory];
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
    request.bucketName = TEST_BUCKET;
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

#pragma mark cancel

- (void)testCancelPutObejct {
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file10m";

    NSString * docDir = [self getDocumentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file10m"]];
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
    request.uploadingData = [readFile readDataToEndOfFile];

    request.contentMd5 = [OSSUtil base64Md5ForData:request.uploadingData];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };

    __block BOOL completed = NO;
    OSSTask * task = [client putObject:request];
    [task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        OSSLogError(@"error should be raised:%@", task.error);
        XCTAssertEqual(OSSClientErrorCodeTaskCancelled, task.error.code);
        completed = YES;
        return nil;
    }];

    [NSThread sleepForTimeInterval:1];
    [request cancel];
    [NSThread sleepForTimeInterval:1];
    XCTAssertTrue(completed);
}

- (void)testCancelGetObject {
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file10m";

    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };

    __block BOOL completed = NO;
    OSSTask * task = [client getObject:request];

    [task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        OSSLogError(@"error should be raise: %@", task.error);
        XCTAssertEqual(OSSClientErrorCodeTaskCancelled, task.error.code);
        completed = YES;
        return nil;
    }];

    [NSThread sleepForTimeInterval:1];
    [request cancel];
    [NSThread sleepForTimeInterval:1];
    XCTAssertTrue(completed);
}

#pragma mark concurrent

- (void)testConcurrentPutObject {
    BFTaskCompletionSource * tcs = [BFTaskCompletionSource taskCompletionSource];
    __block int counter = 0;
    for (int i = 0; i < [fileNameArray count]; i++) {
        dispatch_async(test_queue, ^{
            OSSPutObjectRequest * request = [OSSPutObjectRequest new];
            request.bucketName = TEST_BUCKET;
            request.objectKey = [fileNameArray objectAtIndex:i];
            NSString * docDir = [self getDocumentDirectory];
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
                if (counter == [fileNameArray count]) {
                    [tcs setResult:nil];
                }
            }
        });
    }
    [tcs.task waitUntilFinished];
}

- (void)testConcurrentGetObject {
    BFTaskCompletionSource * tcs = [BFTaskCompletionSource taskCompletionSource];
    __block int counter = 0;
    for (int i = 0; i < 5; i++) {
        dispatch_async(test_queue, ^{
            OSSGetObjectRequest * request = [OSSGetObjectRequest new];
            request.bucketName = TEST_BUCKET;
            request.objectKey = @"file10m";

            OSSTask * task = [client getObject:request];
            [[task continueWithBlock:^id(OSSTask *task) {
                XCTAssertNil(task.error);
                OSSGetObjectResult * result = task.result;
                XCTAssertEqual(200, result.httpResponseCode);
                XCTAssertEqual(10240000, [result.downloadedData length]);
                XCTAssertEqualObjects(@"10240000", [result.objectMeta objectForKey:@"Content-Length"]);
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
    BFTaskCompletionSource * tcs = [BFTaskCompletionSource taskCompletionSource];
    static int counter = 0;
    for (int i = 0; i < 5; i++) {
        dispatch_async(test_queue, ^{
            NSString * docDir = [self getDocumentDirectory];
            NSString * fileToUpload = [NSString stringWithFormat:@"%@/%@", docDir, @"file10m"];
            __block float progValue = 0;
            [client resumableUploadFile:fileToUpload
                        withContentType:@"application/octet-stream"
                         withObjectMeta:nil
                           toBucketName:TEST_BUCKET
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
                                NSLog(@"1. progress: %f", progress);
                                progValue = progress;
                            }];
        });
    }
    [tcs.task waitUntilFinished];
}

#pragma mark exceptional_test

- (void)testGetNotExistObject {
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"not_exist_ttt";
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };

    OSSTask * task = [client getObject:request];

    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(task.error.domain, OSSServerErrorDomain);
        XCTAssertEqual(-1 * 404, task.error.code);
        return nil;
    }] waitUntilFinished];
}

- (void)testGetNotExistBucket {
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = @"not-exist-bucket-dfadsfd";
    request.objectKey = @"file1m";
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };

    OSSTask * task = [client getObject:request];

    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(task.error.domain, OSSServerErrorDomain);
        XCTAssertEqual(-1 * 404, task.error.code);
        return nil;
    }] waitUntilFinished];
}

- (void)testAccessDenied {
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file1m";
    request.isAuthenticationRequired = NO;
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };

    OSSTask * task = [client getObject:request];

    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(task.error.domain, OSSServerErrorDomain);
        XCTAssertEqual(-1 * 403, task.error.code);
        return nil;
    }] waitUntilFinished];
}

- (void)testWithInvalidMd5 {
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = PUBLIC_BUCKET;
    request.isAuthenticationRequired = NO;
    request.objectKey = @"file1m";
    request.contentType = @"application/octet-stream";

    NSString * docDir = [self getDocumentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];

    request.uploadingFileURL = fileURL;
    request.contentMd5 = @"invliadmd5valuetotest";
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        // NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };

    OSSTask * task = [client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(-1 * 400, task.error.code);
        return nil;
    }] waitUntilFinished];
}

- (void)testInvalidParam {
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.objectKey = @"file1m";
    request.isAuthenticationRequired = NO;
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };

    OSSTask * task = [client getObject:request];

    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(task.error.domain, OSSClientErrorDomain);
        XCTAssertEqual(OSSClientErrorCodeInvalidArgument, task.error.code);
        NSLog(@"ErrorMessage: %@", [task.error.userInfo objectForKey:OSSErrorMessageTOKEN]);
        return nil;
    }] waitUntilFinished];
}

- (void)testPutObjectWithNoSource {
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file1m";

    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };

    OSSTask * task = [client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(task.error.domain, OSSClientErrorDomain);
        XCTAssertEqual(OSSClientErrorCodeInvalidArgument, task.error.code);
        NSLog(@"ErrorMessage: %@", [task.error.userInfo objectForKey:OSSErrorMessageTOKEN]);
        return nil;
    }] waitUntilFinished];
}

#pragma mark compat_test

- (void)testCompatResumableUpload {
    NSString * docDir = [self getDocumentDirectory];
    NSString * fileToUpload = [NSString stringWithFormat:@"%@/%@", docDir, @"file10m"];
    NSString * objectKey = @"resumableUpload";
    __block float progValue = 0;
    OSSTaskHandler * taskHandler = [client resumableUploadFile:fileToUpload
                                               withContentType:@"application/octet-stream"
                                                withObjectMeta:nil
                                                  toBucketName:TEST_BUCKET
                                                   toObjectKey:objectKey
                                                   onCompleted:^(BOOL isSuccess, NSError *error) {
                                                       NSLog(@"1. error: %@", error);
                                                       XCTAssertTrue(isSuccess);
                                                   } onProgress:^(float progress) {
                                                       NSLog(@"1. progress: %f", progress);
                                                       progValue = progress;
                                                   }];

    while (progValue < 0.5) {
        [NSThread sleepForTimeInterval:0.2];
        OSSLogError(@"sleep : %f", progValue);
    }

    [taskHandler cancel];

    OSSLogDebug(@"XCTest-------------cancelled!");
    BFTaskCompletionSource * bcs = [BFTaskCompletionSource taskCompletionSource];
    [client resumableUploadFile:fileToUpload
                withContentType:@"application/octet-stream"
                 withObjectMeta:nil
                   toBucketName:TEST_BUCKET
                    toObjectKey:objectKey
                    onCompleted:^(BOOL isSuccess, NSError *error) {
                        NSLog(@"2. error: %@", error);
                        XCTAssertTrue(isSuccess);
                        [bcs setResult:nil];
                    } onProgress:^(float progress) {
                        NSLog(@"2. progress: %f", progress);
                        if (progress < 0.5) {
                            /* should continue from last position which should larger than 0.5 */
                            XCTAssertTrue(false);
                        }
                    }];

    [bcs.task waitUntilFinished];
}

- (void)testCompatUploadObjectFromFile {
    NSString * docDir = [self getDocumentDirectory];
    NSString * fileToUpload = [NSString stringWithFormat:@"%@/%@", docDir, @"file10m"];
    __block float progValue = 0;

    BFTaskCompletionSource * tcs = [BFTaskCompletionSource taskCompletionSource];

    [client uploadFile:fileToUpload
       withContentType:@"application/octet-stream"
        withObjectMeta:nil
          toBucketName:TEST_BUCKET
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
    NSString * docDir = [self getDocumentDirectory];

    NSString * fileToUpload = [NSString stringWithFormat:@"%@/%@", docDir, @"file10m"];

    NSFileHandle * handle = [NSFileHandle fileHandleForReadingAtPath:fileToUpload];
    NSData * dataToUpload = [handle readDataToEndOfFile];

    __block float progValue = 0;

    BFTaskCompletionSource * tcs = [BFTaskCompletionSource taskCompletionSource];

    [client uploadData:dataToUpload
       withContentType:@"application/octet-stream"
        withObjectMeta:nil
          toBucketName:TEST_BUCKET
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
    BFTaskCompletionSource * tcs = [BFTaskCompletionSource taskCompletionSource];

    [client downloadToDataFromBucket:TEST_BUCKET
                           objectKey:@"file1m"
                         onCompleted:^(NSData *data, NSError *error) {
                             XCTAssertNotNil(data);
                             [tcs setResult:nil];
                             XCTAssertEqual(1024000, [data length]);
                         } onProgress:^(float progress) {
                             NSLog(@"Progress: %f", progress);
                         }];

    [tcs.task waitUntilFinished];
}

- (void)testCompatDownloadToFile {
    NSString * docDir = [self getDocumentDirectory];

    NSString * saveToFile = [NSString stringWithFormat:@"%@/%@", docDir, @"compatDownloadFile"];

    BFTaskCompletionSource * tcs = [BFTaskCompletionSource taskCompletionSource];

    [client downloadToFileFromBucket:TEST_BUCKET
                           objectKey:@"file1m"
                              toFile:saveToFile
                         onCompleted:^(BOOL isSuccess, NSError *error) {
                             XCTAssertTrue(isSuccess);
                             [tcs setResult:nil];
                             NSFileManager * fm = [NSFileManager defaultManager];
                             XCTAssertTrue([fm fileExistsAtPath:saveToFile]);
                             int64_t fileSize = [[[fm attributesOfItemAtPath:saveToFile
                                                                       error:nil] objectForKey:NSFileSize] longLongValue];
                             XCTAssertEqual(1024000, fileSize);
                         } onProgress:^(float progress) {
                             NSLog(@"Progress: %f", progress);
                         }];

    [tcs.task waitUntilFinished];
}

- (void)testCompatDeleteObject {
    OSSCopyObjectRequest * copy = [OSSCopyObjectRequest new];
    copy.bucketName = TEST_BUCKET;
    copy.objectKey = @"file1m_copy";
    copy.sourceCopyFrom = [NSString stringWithFormat:@"/%@/%@", TEST_BUCKET, @"file1m"];
    [[[client copyObject:copy] continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];

    OSSHeadObjectRequest * head = [OSSHeadObjectRequest new];
    head.bucketName = TEST_BUCKET;
    head.objectKey = @"file1m_copy";

    [[[client headObject:head] continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    BFTaskCompletionSource * tcs = [BFTaskCompletionSource taskCompletionSource];
    [client deleteObjectInBucket:TEST_BUCKET
                       objectKey:@"file1m_copy"
                     onCompleted:^(BOOL isSuccess, NSError *error) {
                         XCTAssertTrue(isSuccess);
                         [tcs setResult:nil];
                     }];
    
    [tcs.task waitUntilFinished];
    
    head = [OSSHeadObjectRequest new];
    head.bucketName = TEST_BUCKET;
    head.objectKey = @"file1m_copy";
    
    [[[client headObject:head] continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(-404, task.error.code);
        return nil;
    }] waitUntilFinished];
    
}

@end

