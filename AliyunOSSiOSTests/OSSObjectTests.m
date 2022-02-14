//
//  OSSObjectTests.m
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/12/11.
//  Copyright © 2017年 阿里云. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "OSSTestMacros.h"
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import "OSSTestUtils.h"
#import "OSSTestHttpResponseParser.h"
#import "OSSTestModel.h"

#define SCHEME @"https://"
#define ENDPOINT @"oss-cn-hangzhou.aliyuncs.com"
#define CNAME_ENDPOINT @"oss.custom.com"
#define IP_ENDPOINT @"192.168.1.1:8080"
#define CUSTOMPATH(endpoint) [endpoint stringByAppendingString:@"/path"]
#define BUCKET_NAME @"BucketName"
#define OBJECT_KEY @"ObjectKey"


@interface OSSObjectTests : XCTestCase
{
    OSSClient *_client;
    NSArray<NSNumber *> *_fileSizes;
    NSArray<NSString *> *_fileNames;
    NSString *_privateBucketName;
    NSString *_publicBucketName;
    OSSClient *_specialClient;
}

@end

@implementation OSSObjectTests

- (void)setUp {
    [super setUp];
    NSArray *array1 = [self.name componentsSeparatedByString:@" "];
    NSArray *array2 = [array1[1] componentsSeparatedByString:@"_"];
    NSString *testName = [[array2[1] substringToIndex:([array2[1] length] -1)] lowercaseString];
    _privateBucketName = OSS_BUCKET_PRIVATE;
    _publicBucketName = OSS_BUCKET_PUBLIC;
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [self setUpOSSClient];
    [self setUpLocalFiles];
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)setUpOSSClient
{
    OSSClientConfiguration *config = [OSSClientConfiguration new];
//    config.crc64Verifiable = YES;
    
    OSSFederationToken *token = [OSSTestUtils getSts];
    OSSStsTokenCredentialProvider *authProv = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:token.tAccessKey secretKeyId:token.tSecretKey securityToken:token.tToken];
    
    _client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                               credentialProvider:authProv
                              clientConfiguration:config];
    
    _specialClient = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                                      credentialProvider:authProv
                                     clientConfiguration:config];
    
    [OSSLog enableLog];
    
    //upload test image
    OSSPutObjectRequest * put = [OSSPutObjectRequest new];
    put.bucketName = _privateBucketName;
    put.objectKey = OSS_IMAGE_KEY;
    put.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"hasky" withExtension:@"jpeg"];
    [[_client putObject:put] waitUntilFinished];
}

- (void)setUpLocalFiles
{
    _fileNames = @[@"file1k", @"file10k", @"file100k", @"file1m", @"file5m", @"file10m", @"fileDirA/", @"fileDirB/"];
    _fileSizes = @[@1024, @10240, @102400, @(1024 * 1024 * 1), @(1024 * 1024 * 5), @(1024 * 1024 * 10), @1024, @1024];
    NSFileManager * fm = [NSFileManager defaultManager];
    NSString * documentDirectory = [NSString oss_documentDirectory];
    
    for (int i = 0; i < [_fileNames count]; i++)
    {
        NSMutableData * basePart = [NSMutableData dataWithCapacity:1024];
        for (int j = 0; j < 1024/4; j++)
        {
            u_int32_t randomBit = j;// arc4random();
            [basePart appendBytes:(void*)&randomBit length:4];
        }
        NSString * name = [_fileNames objectAtIndex:i];
        long size = [[_fileSizes objectAtIndex:i] longLongValue];
        NSString * newFilePath = [documentDirectory stringByAppendingPathComponent:name];
        if ([fm fileExistsAtPath:newFilePath])
        {
            [fm removeItemAtPath:newFilePath error:nil];
        }
        [fm createFileAtPath:newFilePath contents:nil attributes:nil];
        NSFileHandle * f = [NSFileHandle fileHandleForWritingAtPath:newFilePath];
        for (int k = 0; k < size/1024; k++)
        {
            [f writeData:basePart];
        }
        [f closeFile];
    }
    OSSLogVerbose(@"document directory path is: %@", documentDirectory);
    
    
    
}

#pragma mark - putObject

- (void)testAPI_putObjectFromNSData
{
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[0]];
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[0];
    
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    NSError *readError;
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:&readError];
    XCTAssertNil(readError);
    
    request.uploadingData = [readFile readDataToEndOfFile];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        
    };
    
    OSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_putObjectFromFile
{
    for (NSUInteger pIdx = 0; pIdx < _fileNames.count; pIdx++)
    {
        NSString *objectKey = _fileNames[pIdx];
        NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:objectKey];
        NSURL * fileURL = [NSURL fileURLWithPath:filePath];
        
        OSSPutObjectRequest * request = [OSSPutObjectRequest new];
        request.bucketName = _privateBucketName;
        request.objectKey = objectKey;
        request.uploadingFileURL = fileURL;
        request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
//  在统一config 中修改
//        request.crcFlag = OSSRequestCRCOpen;
        
        request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
            NSLog(@"bytesSent: %lld, totalByteSent: %lld, totalBytesExpectedToSend: %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        };
        
        OSSTask * task = [_client putObject:request];
        [[task continueWithBlock:^id(OSSTask *task) {
            XCTAssertNil(task.error);
            BOOL isEqual = [self checkMd5WithBucketName:_privateBucketName
                                              objectKey:objectKey
                                          localFilePath:filePath];
            XCTAssertTrue(isEqual);
            return nil;
        }] waitUntilFinished];
    }
}

- (void)testAPI_putObjectFromFileWithCRC
{
    NSString *objectKey = @"putObject-wangwang.zip";
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"wangwang" ofType:@"zip"];;
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = objectKey;
    request.uploadingFileURL = fileURL;
//  在统一config 中修改
//    request.crcFlag = OSSRequestCRCOpen;
    
    OSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        BOOL isEqual = [self checkMd5WithBucketName:_privateBucketName
                                          objectKey:objectKey
                                      localFilePath:filePath];
        XCTAssertTrue(isEqual);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_putObjectWithoutContentType
{
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[0]];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
    
    NSString *objectKeyWithoutContentType = @"objectWithoutContentType";
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = objectKeyWithoutContentType;
//    request.crcFlag = OSSRequestCRCOpen;
    request.uploadingData = [readFile readDataToEndOfFile];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"bytesSent: %lld, totalByteSent: %lld, totalBytesExpectedToSend: %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    request.contentType = @"";
    
    OSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    OSSTask *headTask = [OSSTestUtils headObjectWithKey:objectKeyWithoutContentType withClient:_client withBucket:_privateBucketName];
    [[headTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSHeadObjectResult * headResult = task.result;
        XCTAssertNotNil([headResult.objectMeta objectForKey:@"Content-Type"]);
        return nil;
    }] waitUntilFinished];

    BOOL isEqual = [self checkMd5WithBucketName:_privateBucketName
                                      objectKey:objectKeyWithoutContentType
                                  localFilePath:filePath];
    XCTAssertTrue(isEqual);
}

- (void)testAPI_putObjectWithContentType
{
    NSString *fileName = _fileNames[0];
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:fileName];
    
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = fileName;
    
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
    
    request.uploadingData = [readFile readDataToEndOfFile];
    request.contentType = @"application/special";
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    OSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        if (task.error) {
            OSSLogError(@"%@", task.error);
        }
        OSSPutObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        return nil;
    }] waitUntilFinished];
    
    OSSTask *headTask = [OSSTestUtils headObjectWithKey:fileName withClient:_client withBucket:_privateBucketName];
    [[headTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSHeadObjectResult * headResult = task.result;
        XCTAssertEqualObjects([headResult.objectMeta objectForKey:@"Content-Type"], @"application/special");
        return nil;
    }] waitUntilFinished];
    
    BOOL isEqual = [self checkMd5WithBucketName:_privateBucketName
                                      objectKey:fileName
                                  localFilePath:filePath];
    XCTAssertTrue(isEqual);
}

- (void)testAPI_putObjectWithServerCallback
{
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[0];
    
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[0]];
    request.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.callbackParam = @{
                              @"callbackUrl": OSS_CALLBACK_URL,
                              @"callbackBody": @"test"
                              };
    request.callbackVar = @{
                            @"var1": @"value1",
                            @"var2": @"value2"
                            };
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    OSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

#pragma mark - retry operations
- (void)testAPI_PutObjectWithErrorRetry
{
    [NSDate oss_setClockSkew: 30 * 60];
    NSString *fileName = _fileNames[0];
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:fileName];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    NSError *readError;
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:&readError];
    
    XCTAssertNil(readError);
    
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = fileName;
    request.uploadingData = [readFile readDataToEndOfFile];
    request.contentMd5 = [OSSUtil base64Md5ForData:request.uploadingData];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    request.uploadRetryCallback = ^{
        NSLog(@"put object call retry");
    };
    
    OSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    BOOL isEqual = [self checkMd5WithBucketName:_privateBucketName
                                      objectKey:fileName
                                  localFilePath:filePath];
    XCTAssertTrue(isEqual);
}

#pragma mark - md5 check

- (void)testAPI_putObjectWithCheckingDataMd5
{
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[3];
    
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:_fileNames[3]]];
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
    
    request.uploadingData = [readFile readDataToEndOfFile];
    request.contentMd5 = [OSSUtil base64Md5ForData:request.uploadingData];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    OSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_putObjectWithCheckingFileMd5
{
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = _publicBucketName;
    request.isAuthenticationRequired = NO;
    request.objectKey = _fileNames[3];
    request.contentType = @"application/octet-stream";
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:_fileNames[3]]];
    
    request.uploadingFileURL = fileURL;
    request.contentMd5 = [OSSUtil base64Md5ForFilePath:fileURL.path];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        
    };
    
    OSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_putObjectWithInvalidMd5
{
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = _publicBucketName;
    request.isAuthenticationRequired = NO;
    request.objectKey = @"file1m";
    request.contentType = @"application/octet-stream";
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    
    request.uploadingFileURL = fileURL;
    request.contentMd5 = @"invliadmd5valuetotest";
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
         NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    OSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(-1 * 400, task.error.code);
        return nil;
    }] waitUntilFinished];
}

#pragma mark cancel

- (void)testAPI_cancelPutObejct
{
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file5m";
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file5m"]];
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
    request.uploadingData = [readFile readDataToEndOfFile];
    
    request.contentMd5 = [OSSUtil base64Md5ForData:request.uploadingData];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    __block BOOL cancelled = NO;
    OSSTask * task = [_client putObject:request];
    [task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        OSSLogError(@"error should be raised:%@", task.error);
        XCTAssertEqual(OSSClientErrorCodeTaskCancelled, task.error.code);
        cancelled = YES;
        return nil;
    }];
    
    [NSThread sleepForTimeInterval:1];
    [request cancel];
    [NSThread sleepForTimeInterval:1];
    XCTAssertTrue(cancelled);
}

- (void)testAPI_putObjectWithErrorOfInvalidBucketName
{
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = @"-invalid_bucket";
    request.objectKey = @"file1m";
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    
    request.uploadingFileURL = fileURL;
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    OSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(OSSClientErrorCodeInvalidArgument, task.error.code);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_putObjectWithErrorOfInvalidKey
{
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"/file1m";
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    
    request.uploadingFileURL = fileURL;
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    OSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(OSSClientErrorCodeInvalidArgument, task.error.code);
        return nil;
    }] waitUntilFinished];
}


- (void)testAPI_putObjectWithErrorOfNoSource
{
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file1m";
    
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    OSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertTrue([OSSClientErrorDomain isEqualToString:task.error.domain]);
        XCTAssertEqual(OSSClientErrorCodeInvalidArgument, task.error.code);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_putObjectWithErrorOfNoCredentialProvier
{
    OSSClient * tempClient = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:nil];
    
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file1m";
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
    
    request.uploadingData = [readFile readDataToEndOfFile];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    OSSTask * task = [tempClient putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        return nil;
        XCTAssertEqualObjects(OSSClientErrorDomain, task.error.domain);
    }] waitUntilFinished];
}

- (void)testAPI_dataTaskAndUploadTaskSimultaneously {
    [OSSTestUtils putTestDataWithKey:@"file10k" withClient:_client withBucket:_privateBucketName];
    
    OSSPutObjectRequest *putObjectRequest = [OSSPutObjectRequest new];
    putObjectRequest.bucketName = _privateBucketName;
    putObjectRequest.objectKey = @"test-bucket";
    putObjectRequest.uploadingFileURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"xml"]];
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    dispatch_group_enter(group);
    
    [[_specialClient putObject:putObjectRequest] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        dispatch_group_leave(group);
        return nil;
    }];

    OSSTask *headTask = [OSSTestUtils headObjectWithKey:@"file10k" withClient:_client withBucket:_privateBucketName];
    [headTask continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        dispatch_group_leave(group);
        return nil;
    }];

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    XCTAssertTrue(YES);
}

- (void)testAPI_putObjectWithEmptyFile {
    OSSPutObjectRequest *req = [OSSPutObjectRequest new];
    req.bucketName = OSS_BUCKET_PUBLIC;
    req.objectKey = @"test-empty-file";
    req.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"empty-file" withExtension:nil];
    
    OSSTask *task = [_client putObject:req];
    [task waitUntilFinished];
    
    XCTAssertNotNil(task.error);
}

- (BOOL)checkMd5WithBucketName:(nonnull NSString *)bucketName objectKey:(nonnull NSString *)objectKey localFilePath:(nonnull NSString *)filePath
{
    NSString * tempFile = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"tempfile_for_check"];
    
    [[OSSTestUtils getObjectWithKey:objectKey withClient:_client withBucket:bucketName fileUrl:[NSURL fileURLWithPath:tempFile]] waitUntilFinished];
    
    NSString *remoteMD5 = [OSSUtil fileMD5String:tempFile];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tempFile]) {
        [[NSFileManager defaultManager] removeItemAtPath:tempFile
                                                   error:nil];
    }
    
    NSString *localMD5 = [OSSUtil fileMD5String:filePath];
    return [remoteMD5 isEqualToString:localMD5];
}

@end
