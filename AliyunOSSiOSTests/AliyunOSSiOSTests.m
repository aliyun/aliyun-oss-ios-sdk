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

NSString * const g_AK = @"<your access key id>";
NSString * const g_SK = @"<your access key secret";
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
    // "expiration":"2015-11-03T09:52:59Z[;",
    // "federatedUser":"335450541522398178:alice-001",
    // "requestId":"C0E01B94-332E-4582-87F9-B857C807EE52",
    // "securityToken":"CAES7QIIARKAAZPlqaN9ILiQZPS+JDkS/GSZN45RLx4YS/p3OgaUC+oJl3XSlbJ7StKpQp1Q3KtZVCeAKAYY6HYSFOa6rU0bltFXAPyW+jvlijGKLezJs0AcIvP5a4ki6yHWovkbPYNnFSOhOmCGMmXKIkhrRSHMGYJRj8AIUvICAbDhzryeNHvUGhhTVFMuaUE2NDVlVE9YRXFQM2NnM1ZlSGYiEjMzNTQ1MDU0MTUyMjM5ODE3OCoJYWxpY2UtMDAxMOG/g7v6KToGUnNhTUQ1QloKATEaVQoFQWxsb3cSHwoMQWN0aW9uRXF1YWxzEgZBY3Rpb24aBwoFb3NzOioSKwoOUmVzb3VyY2VFcXVhbHMSCFJlc291cmNlGg8KDWFjczpvc3M6KjoqOipKEDEwNzI2MDc4NDc4NjM4ODhSAFoPQXNzdW1lZFJvbGVVc2VyYABqEjMzNTQ1MDU0MTUyMjM5ODE3OHIHeHljLTAwMQ=="}
    credential3 = [[OSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^OSSFederationToken * {
        NSURL * url = [NSURL URLWithString:@"http://localhost:8080/distribute-token.json"];
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
            OSSFederationToken * token = [OSSFederationToken new];
            // 四个值缺一不可
            token.tAccessKey = [object objectForKey:@"accessKeyId"];
            token.tSecretKey = [object objectForKey:@"accessKeySecret"];
            token.tToken = [object objectForKey:@"securityToken"];
            token.expirationTimeInGMTFormat = [object objectForKey:@"expiration"];
            return token;
        }
    }];


    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    conf.maxRetryCount = 2;
    conf.timeoutIntervalForRequest = 30;
    conf.timeoutIntervalForResource = 24 * 60 * 60;

    client = [[OSSClient alloc] initWithEndpoint:ENDPOINT credentialProvider:credential3 clientConfiguration:conf];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#pragma mark normal_test

- (void)testGetServcie {
    if ([client.credentialProvider isKindOfClass:[OSSFederationCredentialProvider class]]) {
        return; // we need the account owner's ak/sk to create bucket; federation token can't do this
    }
    OSSGetServiceRequest * getService = [OSSGetServiceRequest new];
    OSSTask * getServiceTask = [client getService:getService];
    [[getServiceTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetServiceResult * result = task.result;
        NSLog(@"buckets: %@", result.buckets);
        [result.buckets enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary * bucketInfo = obj;
            NSLog(@"BucketName: %@", [bucketInfo objectForKey:@"Name"]);
            NSLog(@"CreationDate: %@", [bucketInfo objectForKey:@"CreationDate"]);
            NSLog(@"Location: %@", [bucketInfo objectForKey:@"Location"]);
        }];
        NSLog(@"owner: %@, %@", result.ownerId, result.ownerDispName);
        return nil;
    }] waitUntilFinished];

    getService = [OSSGetServiceRequest new];
    getService.maxKeys = 10;
    getService.prefix = @"android";
    [[[client getService:getService] continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetServiceResult * result = task.result;
        XCTAssertEqual(1, [result.buckets count]);
        NSLog(@"buckets: %@", result.buckets);
        NSLog(@"owner: %@, %@", result.ownerId, result.ownerDispName);
        return nil;
    }] waitUntilFinished];
}

- (void)testGetBucketACL {
    OSSGetBucketACLRequest * getBucketACL = [OSSGetBucketACLRequest new];
    getBucketACL.bucketName = TEST_BUCKET;
    OSSTask * getBucketACLTask = [client getBucketACL:getBucketACL];
    [[getBucketACLTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetBucketACLResult * result = task.result;
        XCTAssertEqualObjects(@"private", result.aclGranted);
        return nil;
    }] waitUntilFinished];
}

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
        // request.contentType = @"";
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

    BOOL isEqual = [self isFileOnOSSBucket:TEST_BUCKET objectKey:@"file1m" equalsToLocalFile:fileURL.path];
    XCTAssertTrue(isEqual);
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

- (void)testTokenUpdate {
    for (int i = 0; i < 20; i++) {
        OSSPutObjectRequest * request = [OSSPutObjectRequest new];
        request.bucketName = TEST_BUCKET;
        request.objectKey = @"file1m";

        NSString * docDir = [self getDocumentDirectory];
        NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
        NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];

        request.uploadingData = [readFile readDataToEndOfFile];
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
        [NSThread sleepForTimeInterval:60];
    }
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
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.callbackParam = @{
                              @"callbackUrl": @"110.75.82.106/mbaas/callback",
                              @"callbackBody": @"test"
                              };
    request.callbackVar = @{
                            @"var1": @"value1",
                            @"var2": @"value2"
                            };
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

- (void)testGetObjectByBlocks {
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file1m";

    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    request.onRecieveData = ^(NSData * data) {
        NSLog(@"onRecieveData: %lu", [data length]);
    };

    OSSTask * task = [client getObject:request];

    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);

        // if onRecieveData is setting, it will not return whole data
        XCTAssertEqual(0, [result.downloadedData length]);
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
    NSString * saveToFilePath = [docDir stringByAppendingPathComponent:@"downloadDir/temp/file1m"];
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

- (void)testGetObjectOverwriteOldFile {
    NSString * docDir = [self getDocumentDirectory];
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file1m";
    request.downloadToFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"tempfile"]];

    OSSTask * task = [client getObject:request];

    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        XCTAssertNil(result.downloadedData);
        XCTAssertEqualObjects(@"1024000", [result.objectMeta objectForKey:@"Content-Length"]);
        NSLog(@"Result - requestId: %@, headerFields: %@",
              result.requestId,
              result.httpResponseHeaderFields);
        return nil;
    }] waitUntilFinished];

    uint64_t fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:request.downloadToFileURL.path error:nil] fileSize];
    XCTAssertEqual(1024 * 1000, fileSize);
    XCTAssertTrue([self isFileOnOSSBucket:TEST_BUCKET objectKey:@"file1m" equalsToLocalFile:request.downloadToFileURL.path]);

    request = [OSSGetObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file100k";
    request.downloadToFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"tempfile"]];

    task = [client getObject:request];

    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        XCTAssertNil(result.downloadedData);
        XCTAssertEqualObjects(@"102400", [result.objectMeta objectForKey:@"Content-Length"]);
        NSLog(@"Result - requestId: %@, headerFields: %@",
              result.requestId,
              result.httpResponseHeaderFields);
        return nil;
    }] waitUntilFinished];

    fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:request.downloadToFileURL.path error:nil] fileSize];
    XCTAssertEqual(1024 * 100, fileSize);
    XCTAssertTrue([self isFileOnOSSBucket:TEST_BUCKET objectKey:@"file100k" equalsToLocalFile:request.downloadToFileURL.path]);
}

- (void)testHeadObject {
    OSSHeadObjectRequest * request = [OSSHeadObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file1m";

    OSSTask * task = [client headObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSHeadObjectResult * result = task.result;
        NSLog(@"header fields: %@", result.httpResponseHeaderFields);
        for (NSString * key in result.objectMeta) {
            NSLog(@"ObjectMeta: %@ - %@", key, [result.objectMeta objectForKey:key]);
        }
        XCTAssertEqual(200, result.httpResponseCode);
        XCTAssertEqualObjects(@"1024000", [result.httpResponseHeaderFields objectForKey:@"Content-Length"]);
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

    OSSListPartsRequest * listParts = [OSSListPartsRequest new];
    listParts.bucketName = TEST_BUCKET;
    listParts.objectKey = MultipartUploadObjectKey;
    listParts.uploadId = uploadId;
    task = [client listParts:listParts];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSListPartsResult * result = task.result;
        XCTAssertNotNil(result);
        [result.parts enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            XCTAssertNotNil(obj);
            NSLog(@"part: %@", obj);
        }];
        return nil;
    }] waitUntilFinished];

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
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
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
    NSLog(@"url: %@", task.result);
    NSURLRequest * request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:task.result]];
    NSURLSession * session = [NSURLSession sharedSession];
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
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

- (void)testResumableUpload_normal {
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

    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = TEST_BUCKET;
    resumableUpload.objectKey = MultipartUploadObjectKey;
    resumableUpload.uploadId = uploadId;
    resumableUpload.partSize = 1024 * 1024;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    NSString * docDir = [self getDocumentDirectory];
    resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file10m"]];
    OSSTask * resumeTask = [client resumableUpload:resumableUpload];
    [[resumeTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        if (task.error) {
            NSLog(@"error: %@", task.error);
            if ([task.error.domain isEqualToString:OSSClientErrorDomain] && task.error.code == OSSClientErrorCodeCannotResumeUpload) {
                // 该任务无法续传，需要获取新的uploadId重新上传
            }
        } else {
            NSLog(@"Upload file success");
        }
        return nil;
    }] waitUntilFinished];

    BOOL isEqual = [self isFileOnOSSBucket:TEST_BUCKET objectKey:MultipartUploadObjectKey equalsToLocalFile:[resumableUpload.uploadingFileURL path]];
    XCTAssertTrue(isEqual);
}

- (void)testResumbleUpload_cancel {
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

    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = TEST_BUCKET;
    resumableUpload.objectKey = MultipartUploadObjectKey;
    resumableUpload.uploadId = uploadId;
    resumableUpload.partSize = 1024 * 1024;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    NSString * docDir = [self getDocumentDirectory];
    resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file10m"]];
    OSSTask * resumeTask = [client resumableUpload:resumableUpload];
    [resumeTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        NSLog(@"error: %@", task.error);
        XCTAssertEqual(OSSClientErrorCodeTaskCancelled, task.error.code);
        return nil;
    }];

    [resumableUpload cancel];
    [NSThread sleepForTimeInterval:1];
}

- (void)testResumableUpload_small_file {
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

    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = TEST_BUCKET;
    resumableUpload.objectKey = MultipartUploadObjectKey;
    resumableUpload.uploadId = uploadId;
    resumableUpload.partSize = 1024 * 1024;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    NSString * docDir = [self getDocumentDirectory];
    resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1k"]];
    OSSTask * resumeTask = [client resumableUpload:resumableUpload];
    [[resumeTask continueWithBlock:^id(OSSTask *task) {
        NSLog(@"error: %@", task.error);
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];

    BOOL isEqual = [self isFileOnOSSBucket:TEST_BUCKET objectKey:MultipartUploadObjectKey equalsToLocalFile:[resumableUpload.uploadingFileURL path]];
    XCTAssertTrue(isEqual);
}

- (void)testResumableUpload_resume_upload {
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

    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = TEST_BUCKET;
    resumableUpload.objectKey = MultipartUploadObjectKey;
    resumableUpload.uploadId = uploadId;
    resumableUpload.partSize = 1024 * 1024;
    __weak OSSResumableUploadRequest * upload = resumableUpload;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        if (totalByteSent > totalBytesExpectedToSend / 2) {
            [upload cancel];
        }
    };
    NSString * docDir = [self getDocumentDirectory];
    resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file10m"]];
    OSSTask * resumeTask = [client resumableUpload:resumableUpload];
    [[resumeTask continueWithBlock:^id(OSSTask *task) {
        NSLog(@"error: %@", task.error);
        XCTAssertNotNil(task.error);
        XCTAssertEqual(OSSClientErrorCodeTaskCancelled, task.error.code);
        return nil;
    }] waitUntilFinished];

    resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = TEST_BUCKET;
    resumableUpload.objectKey = MultipartUploadObjectKey;
    resumableUpload.uploadId = uploadId;
    resumableUpload.partSize = 1024 * 1024;
    resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file10m"]];
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        XCTAssertGreaterThan(totalByteSent, totalBytesExpectedToSend / 2);
    };
    resumeTask = [client resumableUpload:resumableUpload];
    [[resumeTask continueWithBlock:^id(OSSTask *task) {
        NSLog(@"error: %@", task.error);
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];


    BOOL isEqual = [self isFileOnOSSBucket:TEST_BUCKET objectKey:MultipartUploadObjectKey equalsToLocalFile:[resumableUpload.uploadingFileURL path]];
    XCTAssertTrue(isEqual);
}

- (void)testCnamePutObject {
    OSSClient * tClient = [[OSSClient alloc] initWithEndpoint:@"http://osstest.xxyycc.com"
                                          credentialProvider:credential3];
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

    OSSTask * task = [tClient putObject:request];
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

- (void)testCnameGetObejct {
    OSSClient * tClient = [[OSSClient alloc] initWithEndpoint:@"http://osstest.xxyycc.com"
                                          credentialProvider:credential3];
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = TEST_BUCKET;
    request.objectKey = @"file1m";

    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };

    OSSTask * task = [tClient getObject:request];

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
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
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
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
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
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
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
        NSLog(@"error: %@", task.error);
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

- (void)testResumableUpload_invalid_partSize {
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

    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = TEST_BUCKET;
    resumableUpload.objectKey = MultipartUploadObjectKey;
    resumableUpload.uploadId = uploadId;
    resumableUpload.partSize = 1024;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    NSString * docDir = [self getDocumentDirectory];
    resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file10m"]];
    OSSTask * resumeTask = [client resumableUpload:resumableUpload];
    [[resumeTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(OSSClientErrorCodeInvalidArgument, task.error.code);
        NSLog(@"task.error: %@", task.error);
        return nil;
    }] waitUntilFinished];

    OSSAbortMultipartUploadRequest * abort = [OSSAbortMultipartUploadRequest new];
    abort.bucketName = TEST_BUCKET;
    abort.objectKey = MultipartUploadObjectKey;
    abort.uploadId = uploadId;
    [[[client abortMultipartUpload:abort] continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
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
                                                       XCTAssertFalse(isSuccess);
                                                       XCTAssertEqual(error.code, OSSClientErrorCodeTaskCancelled);
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
    OSSTaskCompletionSource * bcs = [OSSTaskCompletionSource taskCompletionSource];
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

    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];

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

    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];

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
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];

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

    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];

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

    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
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

#pragma mark test UtilFunction

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
}

#pragma mark util

- (BOOL)isFileOnOSSBucket:(NSString *)bucketName objectKey:(NSString *)objectKey equalsToLocalFile:(NSString *)filePath {
    NSString * docDir = [self getDocumentDirectory];
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

@end

