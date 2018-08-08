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
    _privateBucketName = [@"oss-ios-private-" stringByAppendingString:testName];
    _publicBucketName = [@"oss-ios-public-" stringByAppendingString:testName];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [self setUpOSSClient];
    [self setUpLocalFiles];
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [OSSTestUtils cleanBucket:_privateBucketName with:_client];
    [OSSTestUtils cleanBucket:_publicBucketName with:_client];
}

- (void)setUpOSSClient
{
    OSSClientConfiguration *config = [OSSClientConfiguration new];
//    config.crc64Verifiable = YES;
    
    OSSAuthCredentialProvider *authProv = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    _client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                               credentialProvider:authProv
                              clientConfiguration:config];
    
    _specialClient = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                                      credentialProvider:authProv
                                     clientConfiguration:config];
    
    [OSSLog enableLog];
    
    OSSCreateBucketRequest *createBucket1 = [OSSCreateBucketRequest new];
    createBucket1.bucketName = _privateBucketName;
    [[_client createBucket:createBucket1] waitUntilFinished];
    
    OSSCreateBucketRequest *createBucket2 = [OSSCreateBucketRequest new];
    createBucket2.bucketName = _publicBucketName;
    createBucket2.xOssACL = @"public-read-write";
    [[_client createBucket:createBucket2] waitUntilFinished];
    
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
    
    OSSHeadObjectRequest * head = [OSSHeadObjectRequest new];
    head.bucketName = _privateBucketName;
    head.objectKey = objectKeyWithoutContentType;
    [[[_client headObject:head] continueWithBlock:^id(OSSTask *task) {
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
    
    OSSHeadObjectRequest * head = [OSSHeadObjectRequest new];
    head.bucketName = _privateBucketName;
    head.objectKey = fileName;
    
    [[[_client headObject:head] continueWithBlock:^id(OSSTask *task) {
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

- (void)testAPI_putObjectACL
{
    [OSSTestUtils putTestDataWithKey:_fileNames[0] withClient:_client withBucket:_privateBucketName];
    
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[0];
    request.isAuthenticationRequired = NO;
    OSSTask * task = [_client getObject:request];
    [task waitUntilFinished];
    
    XCTAssertNotNil(task.error);
    XCTAssertEqual(-403, task.error.code);
    
    OSSPutObjectACLRequest * putAclRequest = [OSSPutObjectACLRequest new];
    putAclRequest.bucketName = _privateBucketName;
    putAclRequest.objectKey = _fileNames[0];
    putAclRequest.acl = @"public-read-write";
    task = [_client putObjectACL:putAclRequest];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);
    
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[0];
    request.isAuthenticationRequired = NO;
    task = [_client getObject:request];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);
}

- (void)testAPI_appendObject
{
    OSSDeleteObjectRequest * delete = [OSSDeleteObjectRequest new];
    delete.bucketName = _privateBucketName;
    delete.objectKey = @"appendObject";
    OSSTask * task = [_client deleteObject:delete];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDeleteObjectResult * result = task.result;
        XCTAssertEqual(204, result.httpResponseCode);
        return nil;
    }] waitUntilFinished];
    
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[0]];
    OSSAppendObjectRequest * request = [OSSAppendObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"appendObject";
    request.appendPosition = 0;
    request.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    __block int64_t nextAppendPosition = 0;
    __block NSString *lastCrc64ecma;
    task = [_client appendObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSAppendObjectResult * result = task.result;
        nextAppendPosition = result.xOssNextAppendPosition;
        lastCrc64ecma = result.remoteCRC64ecma;
        return nil;
    }] waitUntilFinished];
    
    request.bucketName = _privateBucketName;
    request.objectKey = @"appendObject";
    request.appendPosition = nextAppendPosition;
    request.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    task = [_client appendObject:request withCrc64ecma:lastCrc64ecma];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

#pragma mark - getObject
- (void)testAPI_getObject
{
    [OSSTestUtils putTestDataWithKey:_fileNames[0] withClient:_client withBucket:_privateBucketName];
    
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[0];
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    OSSTask * task = [_client getObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectACL
{
    OSSGetObjectACLRequest * request = [OSSGetObjectACLRequest new];
    request.bucketName = _privateBucketName;
    request.objectName = OSS_IMAGE_KEY;
    
    OSSTask * task = [_client getObjectACL:request];
    [[task continueWithBlock:^id(OSSTask *t) {
        XCTAssertNil(task.error);
        if (t.result != nil) {
            OSSGetObjectACLResult *result = (OSSGetObjectACLResult *)t.result;
            XCTAssertEqualObjects(result.grant, @"default");
        }
        
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getImage
{
    OSSPutObjectRequest * put = [OSSPutObjectRequest new];
    put.bucketName = _privateBucketName;
    put.objectKey = OSS_IMAGE_KEY;
    put.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"hasky" withExtension:@"jpeg"];
    put.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    
    [[_client putObject:put] waitUntilFinished];
    
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = OSS_IMAGE_KEY;
    request.xOssProcess = @"image/resize,m_lfit,w_100,h_100";

    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };

    OSSTask * task = [_client getObject:request];

    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectWithRecieveDataBlock
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_privateBucketName];
    
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[3];
    
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    request.onRecieveData = ^(NSData * data) {
        NSLog(@"onRecieveData: %lu", [data length]);
    };
    
    OSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        
        OSSGetObjectResult * result = task.result;
        // if onRecieveData is setting, it will not return whole data
        XCTAssertEqual(0, [result.downloadedData length]);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectWithRecieveDataBlockAndNoRetry
{
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"wrong-key";
    
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    request.onRecieveData = ^(NSData * data) {
        NSLog(@"onRecieveData: %lu", [data length]);
    };
    
    OSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectWithRange
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_privateBucketName];
    
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[3];
    request.range = [[OSSRange alloc] initWithStart:0 withEnd:99]; // bytes=0-99
    
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    OSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetObjectResult * result = task.result;
        XCTAssertEqual(206, result.httpResponseCode);
        XCTAssertEqual(100, [result.downloadedData length]);
        XCTAssertEqualObjects(@"100", [result.objectMeta objectForKey:@"Content-Length"]);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectByPartiallyRecieveData
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_privateBucketName];
    
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[3];
    
    NSMutableData * recieveData = [NSMutableData data];
    
    request.onRecieveData = ^(NSData * data) {
        [recieveData appendData:data];
        NSLog(@"recieveData %ld", [recieveData length]);
    };
    
    OSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        XCTAssertEqual(1024 * 1024, [recieveData length]);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectFromPublicBucket
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_publicBucketName];
    
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _publicBucketName;
    request.isAuthenticationRequired = NO;
    request.objectKey = _fileNames[3];
    
    NSString * saveToFilePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"downloads/temp/file1m"];
    request.downloadToFileURL = [NSURL fileURLWithPath:saveToFilePath];
    
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    OSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        NSFileManager * fm = [NSFileManager defaultManager];
        XCTAssertTrue([fm fileExistsAtPath:request.downloadToFileURL.path]);
        int64_t fileLength = [[[fm attributesOfItemAtPath:request.downloadToFileURL.path
                                                    error:nil] objectForKey:NSFileSize] longLongValue];
        XCTAssertEqual(1024 * 1024, fileLength);
        [fm removeItemAtPath:saveToFilePath error:nil];
        [fm removeItemAtPath:[[NSString oss_documentDirectory] stringByAppendingPathComponent:@"downloads/temp"] error:nil];
        [fm removeItemAtPath:[[NSString oss_documentDirectory] stringByAppendingPathComponent:@"downloads"] error:nil];
        
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectOverwriteOldFile
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_publicBucketName];
    [OSSTestUtils putTestDataWithKey:_fileNames[2] withClient:_client withBucket:_publicBucketName];
    NSString *tmpFilePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"tempfile"];
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _publicBucketName;
    request.objectKey = _fileNames[3];
    request.downloadToFileURL = [NSURL fileURLWithPath:tmpFilePath];
    
    OSSTask * task = [_client getObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetObjectResult * result = task.result;
        XCTAssertNil(result.downloadedData);
        return nil;
    }] waitUntilFinished];
    
    uint64_t fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:tmpFilePath error:nil] fileSize];
    XCTAssertEqual(1024 * 1024, fileSize);
    
    request = [OSSGetObjectRequest new];
    request.bucketName = _publicBucketName;
    request.objectKey = _fileNames[2];
    request.downloadToFileURL = [NSURL fileURLWithPath:tmpFilePath];
    
    task = [_client getObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetObjectResult * result = task.result;
        XCTAssertNil(result.downloadedData);
        return nil;
    }] waitUntilFinished];
    
    fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:tmpFilePath error:nil] fileSize];
    XCTAssertEqual(102400, fileSize);
    [[NSFileManager defaultManager] removeItemAtPath:tmpFilePath error:nil];
}

- (void)testAPI_putSymlink {
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[2]];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    OSSPutObjectRequest * putObjectRequest = [OSSPutObjectRequest new];
    putObjectRequest.bucketName = _publicBucketName;
    putObjectRequest.objectKey = @"test-symlink-targetObjectName";
    putObjectRequest.uploadingFileURL = fileURL;
    putObjectRequest.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"test-symlink-target", @"x-oss-meta-name", nil];
    
    OSSTask * task = [_client putObject:putObjectRequest];
    [task waitUntilFinished];
    
    OSSPutSymlinkRequest * putSymlinkRequest = [OSSPutSymlinkRequest new];
    putSymlinkRequest.bucketName = _publicBucketName;
    putSymlinkRequest.objectKey = @"test-symlink-objectName";
    putSymlinkRequest.targetObjectName = @"test-symlink-targetObjectName";
    putSymlinkRequest.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"HONGKONG", @"x-oss-meta-location", nil];
    
    OSSTask * putSymlinktask = [_client putSymlink:putSymlinkRequest];
    
    [[putSymlinktask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        
        return nil;
    }] waitUntilFinished];
    
    OSSGetSymlinkRequest * getSymlinkRequest = [OSSGetSymlinkRequest new];
    getSymlinkRequest.bucketName = _publicBucketName;
    getSymlinkRequest.objectKey = @"test-symlink-objectName";
    
    OSSTask * getSymlinktask = [_client getSymlink:getSymlinkRequest];
    
    [[getSymlinktask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetSymlinkResult *result = (OSSGetSymlinkResult *)task.result;
        NSString *targetObjectName = (NSString *)[result.httpResponseHeaderFields valueForKey:OSSHttpHeaderSymlinkTarget];
        NSString *metaLocation = (NSString *)[result.httpResponseHeaderFields valueForKey:@"x-oss-meta-location"];
        
        XCTAssertTrue([targetObjectName isEqualToString:@"test-symlink-targetObjectName"]);
        XCTAssertTrue([metaLocation isEqualToString:@"HONGKONG"]);
        
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getSymlink {
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[2]];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    OSSPutObjectRequest * putObjectRequest = [OSSPutObjectRequest new];
    putObjectRequest.bucketName = _publicBucketName;
    putObjectRequest.objectKey = @"test-symlink-targetObjectName";
    putObjectRequest.uploadingFileURL = fileURL;
    putObjectRequest.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"test-symlink-target", @"x-oss-meta-name", nil];
    
    OSSTask * task = [_client putObject:putObjectRequest];
    [task waitUntilFinished];
    
    OSSPutSymlinkRequest * putSymlinkRequest = [OSSPutSymlinkRequest new];
    putSymlinkRequest.bucketName = _publicBucketName;
    putSymlinkRequest.objectKey = @"test-symlink-objectName";
    putSymlinkRequest.targetObjectName = @"test-symlink-targetObjectName";
    putSymlinkRequest.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"HONGKONG", @"x-oss-meta-location", nil];
    
    OSSTask * putSymlinktask = [_client putSymlink:putSymlinkRequest];
    
    [[putSymlinktask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        
        return nil;
    }] waitUntilFinished];
    
    OSSGetSymlinkRequest * getSymlinkRequest = [OSSGetSymlinkRequest new];
    getSymlinkRequest.bucketName = _publicBucketName;
    getSymlinkRequest.objectKey = @"test-symlink-objectName";
    
    OSSTask * getSymlinktask = [_client getSymlink:getSymlinkRequest];
    
    [[getSymlinktask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetSymlinkResult *result = (OSSGetSymlinkResult *)task.result;
        NSString *targetObjectName = (NSString *)[result.httpResponseHeaderFields valueForKey:OSSHttpHeaderSymlinkTarget];
        NSString *metaLocation = (NSString *)[result.httpResponseHeaderFields valueForKey:@"x-oss-meta-location"];
        
        XCTAssertTrue([targetObjectName isEqualToString:@"test-symlink-targetObjectName"]);
        XCTAssertTrue([metaLocation isEqualToString:@"HONGKONG"]);
        
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_restoreObject {
    NSString *bucketName = @"aliyun-oss-ios-restore-object-test";
    NSString *objectName = @"test-restore-objectName";
    
    OSSCreateBucketRequest *createBucketRequest = [OSSCreateBucketRequest new];
    createBucketRequest.bucketName = bucketName;
    createBucketRequest.storageClass = OSSBucketStorageClassArchive;
    [[_client createBucket:createBucketRequest] waitUntilFinished];
    
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[2]];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    OSSPutObjectRequest * putObjectRequest = [OSSPutObjectRequest new];
    putObjectRequest.bucketName = bucketName;
    putObjectRequest.objectKey = objectName;
    putObjectRequest.uploadingFileURL = fileURL;
    putObjectRequest.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:objectName, @"x-oss-meta-name", nil];
    
    OSSTask * task = [_client putObject:putObjectRequest];
    [task waitUntilFinished];
    
    OSSRestoreObjectRequest * restoreObjectRequest = [OSSRestoreObjectRequest new];
    restoreObjectRequest.bucketName = bucketName;
    restoreObjectRequest.objectKey = objectName;
    
    OSSTask * restoreObjecTtask = [_client restoreObject:restoreObjectRequest];
    [[restoreObjecTtask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSRestoreObjectResult *result = (OSSRestoreObjectResult *)task.result;
        XCTAssertEqual(result.httpResponseCode, 202);
        
        return nil;
    }] waitUntilFinished];
    
    OSSTask * restoreObjectTask1 = [_client restoreObject:restoreObjectRequest];
    [[restoreObjectTask1 continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:bucketName with:_client];
}

#pragma mark - others

- (void)testAPI_get_Bucket_list_Objects
{
    NSString * bucket = @"oss-ios-get-bucket-list-object-test";
    OSSCreateBucketRequest *req = [OSSCreateBucketRequest new];
    req.bucketName = bucket;
    [[_client createBucket:req] waitUntilFinished];
    
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[0]];
    OSSPutObjectRequest * put = [OSSPutObjectRequest new];
    put.bucketName = bucket;
    put.objectKey = _fileNames[0];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    NSError *readError;
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:&readError];
    put.uploadingData = [readFile readDataToEndOfFile];
    [[_client putObject:put] waitUntilFinished];
    
    OSSGetBucketRequest * request = [OSSGetBucketRequest new];
    request.bucketName = bucket;
    request.delimiter = @"";
    request.marker = @"";
    request.maxKeys = 1000;
    request.prefix = @"";
    
    OSSTask * task = [_client getBucket:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    request = [OSSGetBucketRequest new];
    request.bucketName = bucket;
    request.delimiter = @"";
    request.marker = @"";
    request.maxKeys = 2;
    request.prefix = @"";
    
    task = [_client getBucket:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    request = [OSSGetBucketRequest new];
    request.bucketName = bucket;
    request.prefix = @"fileDir";
    request.delimiter = @"/";
    
    task = [_client getBucket:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:bucket with:_client];
}

- (void)testAPI_headObject
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_publicBucketName];
    
    OSSHeadObjectRequest * request = [OSSHeadObjectRequest new];
    request.bucketName = _publicBucketName;
    request.objectKey = _fileNames[3];
    
    OSSTask * task = [_client headObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_doesObjectExistWithExistObject
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_privateBucketName];
    NSError * error = nil;
    BOOL isExist = [_client doesObjectExistInBucket:_privateBucketName objectKey:_fileNames[3] error:&error];
    XCTAssertEqual(isExist, YES);
    XCTAssertNil(error);
}

- (void)testAPI_doesObjectExistWithNoExistObject
{
    NSError * error = nil;
    BOOL isExist = [_client doesObjectExistInBucket:_privateBucketName objectKey:@"wrong-key" error:&error];
    XCTAssertEqual(isExist, NO);
    XCTAssertNil(error);
}

- (void)testAPI_doesObjectExistWithError
{
    NSError * error = nil;
    // invalid credentialProvider
    id<OSSCredentialProvider> c = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:@"" secretKey:@""];
    OSSClient * tClient = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:c];
    BOOL isExist = [tClient doesObjectExistInBucket:_privateBucketName objectKey:_fileNames[3] error:&error];
    XCTAssertEqual(isExist, NO);
    XCTAssertNotNil(error);
}

- (void)testAPI_copyAndDeleteObject
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_privateBucketName];
    
    OSSHeadObjectRequest * head = [OSSHeadObjectRequest new];
    head.bucketName = _privateBucketName;
    head.objectKey = @"file1m_copyTo";
    OSSTask * task = [_client headObject:head];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(-404, task.error.code);
        return nil;
    }] waitUntilFinished];
    
    OSSCopyObjectRequest * copy = [OSSCopyObjectRequest new];
    copy.bucketName = _privateBucketName;
    copy.objectKey = @"file1m_copyTo";
    copy.sourceCopyFrom = [NSString stringWithFormat:@"/%@/%@", _privateBucketName, _fileNames[3]];
    task = [_client copyObject:copy];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    OSSDeleteObjectRequest * delete = [OSSDeleteObjectRequest new];
    delete.bucketName = _privateBucketName;
    delete.objectKey = @"file1m_copyTo";
    task = [_client deleteObject:delete];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDeleteObjectResult * result = task.result;
        XCTAssertEqual(204, result.httpResponseCode);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_copyObjectWithZhongWenAndDeleteObject
{
    NSString *objectKey = @"中文";
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"file1m"];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = objectKey;
    request.uploadingFileURL = fileURL;
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    
    OSSTask * putTask = [_client putObject:request];
    [putTask waitUntilFinished];
    
    OSSHeadObjectRequest * head = [OSSHeadObjectRequest new];
    head.bucketName = _privateBucketName;
    head.objectKey = @"中文_copyTo";
    OSSTask * headTask = [_client headObject:head];
    [[headTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(-404, task.error.code);
        return nil;
    }] waitUntilFinished];
    
    OSSCopyObjectRequest * copy = [OSSCopyObjectRequest new];
    copy.bucketName = _privateBucketName;
    copy.objectKey = @"中文_copyTo";
    copy.sourceBucketName = _privateBucketName;
    copy.sourceObjectKey = objectKey;
    OSSTask *cpTask = [_client copyObject:copy];
    [[cpTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    OSSDeleteObjectRequest * delete = [OSSDeleteObjectRequest new];
    delete.bucketName = _privateBucketName;
    delete.objectKey = @"中文_copyTo";
    OSSTask *dTask = [_client deleteObject:delete];
    [[dTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDeleteObjectResult * result = task.result;
        XCTAssertEqual(204, result.httpResponseCode);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_DeleteMultipleObjects {
    OSSDeleteMultipleObjectsRequest *request = [OSSDeleteMultipleObjectsRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.keys = @[@"file1k",@"file10k",@"file100k",@"file1m"];
    request.encodingType = @"url";
    
    OSSTask *task = [_client deleteMultipleObjects:request];
    [[task continueWithBlock:^id(OSSTask *t) {
        XCTAssertNil(t.error);

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

- (void)testAPI_timeSkewedButAutoRetry
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_privateBucketName];
    
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[3];
    
    [NSDate oss_setClockSkew: 30 * 60];
    
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    OSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
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

- (void)testAPI_customExcludeCname
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_publicBucketName];

    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    conf.cnameExcludeList = @[@"oss-cn-hangzhou.aliyuncs.com", @"vpc.sample.com"];
    id<OSSCredentialProvider> provider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];

    OSSClient * tClient = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                                           credentialProvider:provider
                                          clientConfiguration:conf];

    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _publicBucketName;
    request.objectKey = @"file1m";

    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };

    OSSTask * task = [tClient getObject:request];

    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        XCTAssertEqual(1024 * 1024, [result.downloadedData length]);
        XCTAssertEqualObjects(@"1048576", [result.objectMeta objectForKey:@"Content-Length"]);

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

- (void)testAPI_cancelGetObject
{
    [OSSTestUtils putTestDataWithKey:@"file5m" withClient:_client withBucket:_privateBucketName];
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file5m";
    
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    __block BOOL completed = NO;
    OSSTask * task = [_client getObject:request];
    
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

- (void)testAPI_cancelGetObjectWithNoSessionTask
{
    [OSSTestUtils putTestDataWithKey:@"file5m" withClient:_client withBucket:_privateBucketName];
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    OSSGetObjectRequest * getRequest = [OSSGetObjectRequest new];
    getRequest.bucketName = _privateBucketName;
    getRequest.objectKey = @"file5m";
    OSSTask * getTask = [_client getObject:getRequest];
    [getTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(task.error.code, OSSClientErrorCodeTaskCancelled);
        [tcs setResult:nil];
        return nil;
    }];
    [getRequest cancel];
    [tcs.task waitUntilFinished];
}

- (void)testAPI_cancelGetObjectAndContinue
{
    [OSSTestUtils putTestDataWithKey:@"file5m" withClient:_client withBucket:_privateBucketName];
    
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    OSSGetObjectRequest * getRequest = [OSSGetObjectRequest new];
    getRequest.bucketName = _privateBucketName;
    getRequest.objectKey = @"file5m";
    OSSTask * getTask = [_client getObject:getRequest];
    [getTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(task.error.code, OSSClientErrorCodeTaskCancelled);
        [tcs setResult:nil];
        return nil;
    }];
    [getRequest cancel];
    [tcs.task waitUntilFinished];
    OSSTask * getTaskAgain = [_client getObject:getRequest];
    [getTaskAgain waitUntilFinished];
    XCTAssertNil(getTaskAgain.error);
}

#pragma mark - exceptional tests

- (void)testAPI_DeleteMultipleObjects_withoutBucketName {
    OSSDeleteMultipleObjectsRequest *request = [OSSDeleteMultipleObjectsRequest new];
    request.keys = @[@"file1k",@"file10k",@"file100k",@"file1m"];
    request.encodingType = @"url";
    
    OSSTask *task = [_client deleteMultipleObjects:request];
    [[task continueWithBlock:^id(OSSTask *t) {
        XCTAssertNotNil(t.error);
        
        return nil;
    }] waitUntilFinished];
    
}

- (void)testAPI_DeleteMultipleObjects_withoutKeys {
    OSSDeleteMultipleObjectsRequest *request = [OSSDeleteMultipleObjectsRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.encodingType = @"url";
    
    OSSTask *task = [_client deleteMultipleObjects:request];
    [[task continueWithBlock:^id(OSSTask *t) {
        XCTAssertNotNil(t.error);
        
        return nil;
    }] waitUntilFinished];
    
}

- (void)testAPI_getObjectWithServerErrorNotExistObject
{
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"not_exist_ttt";
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    OSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertTrue([OSSServerErrorDomain isEqualToString:task.error.domain]);
        XCTAssertEqual(-1 * 404, task.error.code);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectWithServerErrorNotExistBucket
{
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = @"not-exist-bucket-dfadsfd";
    request.objectKey = @"file1m";
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    OSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertTrue([OSSServerErrorDomain isEqualToString:task.error.domain]);
        XCTAssertEqual(-1 * 404, task.error.code);
        return nil;
    }] waitUntilFinished];
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

- (void)testAPI_getObjectWithErrorOfAccessDenied
{
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file1m";
    request.isAuthenticationRequired = NO;
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    OSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertTrue([OSSServerErrorDomain isEqualToString:task.error.domain]);
        XCTAssertEqual(-1 * 403, task.error.code);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectWithErrorOfInvalidParam
{
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.objectKey = @"file1m";
    request.isAuthenticationRequired = NO;
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    OSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertTrue([OSSClientErrorDomain isEqualToString:task.error.domain]);
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
    
    task = [tempClient presignConstrainURLWithBucketName:_privateBucketName withObjectKey:@"file1m" withExpirationInterval:3600];
    [task waitUntilFinished];
     XCTAssertTrue([OSSClientErrorDomain isEqualToString:task.error.domain]);
}

#pragma mark - cname
- (void)testAPI_cnameUrlCheck
{
    id<OSSCredentialProvider> provider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient * tClient = [[OSSClient alloc] initWithEndpoint:OSS_CNAME_URL
                                           credentialProvider:provider];
    OSSTask * tk = [tClient presignConstrainURLWithBucketName:_privateBucketName
                                 withObjectKey:@"file1k"
                        withExpirationInterval:30 * 60];
    [tk waitUntilFinished];
    XCTAssertNotNil(tk.result);
    XCTAssertTrue([tk.result hasPrefix:OSS_CNAME_URL]);
}

#pragma mark - presign

- (void)testAPI_presignConstrainURL
{
    OSSTask * tk = [_client presignConstrainURLWithBucketName:_privateBucketName
                                               withObjectKey:@"file1k"
                                      withExpirationInterval:30 * 60];
    XCTAssertNil(tk.error);
}

- (void)testAPI_presignPublicURL
{
    OSSTask * task = [_client presignPublicURLWithBucketName:_publicBucketName withObjectKey:@"file1m"];
    XCTAssertNil(task.error);
}

- (void)testAPI_PresignImageConstrainURL
{
    OSSTask * tk = [_client presignConstrainURLWithBucketName:_privateBucketName
                                                withObjectKey:@"hasky.jpeg"
                                       withExpirationInterval:30 * 60
                                               withParameters:@{@"x-oss-process": @"image/resize,w_50"}];
    XCTAssertNil(tk.error);
}

- (void)testAPI_PublicImageURL
{
    OSSTask * task = [_client presignPublicURLWithBucketName:_publicBucketName
                                              withObjectKey:@"hasky.jpeg"
                                             withParameters:@{@"x-oss-process": @"image/resize,w_50"}];
    XCTAssertNil(task.error);
}

#pragma mark - utils

- (BOOL)checkMd5WithBucketName:(nonnull NSString *)bucketName objectKey:(nonnull NSString *)objectKey localFilePath:(nonnull NSString *)filePath
{
    NSString * tempFile = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"tempfile_for_check"];
    
    OSSGetObjectRequest * get = [OSSGetObjectRequest new];
    get.bucketName = bucketName;
    get.objectKey = objectKey;
    get.downloadToFileURL = [NSURL fileURLWithPath:tempFile];
    [[[_client getObject:get] continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    NSString *remoteMD5 = [OSSUtil fileMD5String:tempFile];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tempFile]) {
        [[NSFileManager defaultManager] removeItemAtPath:tempFile
                                                   error:nil];
    }
    
    NSString *localMD5 = [OSSUtil fileMD5String:filePath];
    return [remoteMD5 isEqualToString:localMD5];
}

- (void)testAPI_multipartRequestWithoutUploadingURL {
    OSSMultipartUploadRequest * multipartUploadRequest = [OSSMultipartUploadRequest new];
    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.bucketName = _privateBucketName;
    multipartUploadRequest.objectKey = OSS_MULTIPART_UPLOADKEY;
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.partSize = 1024 * 1024;
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    OSSTask * multipartTask = [_client multipartUpload:multipartUploadRequest];
    
    [[multipartTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_multipartRequest_concurrently {
    NSOperationQueue *queue = [NSOperationQueue new];
    queue.maxConcurrentOperationCount = 5;
    
    for (int pIndex = 0; pIndex < 5; pIndex++) {
        OSSMultipartUploadRequest * multipartUploadRequest = [OSSMultipartUploadRequest new];
        multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
        multipartUploadRequest.bucketName = _privateBucketName;
        multipartUploadRequest.objectKey = [NSString stringWithFormat:@"multipart-concurrently-%d", pIndex];
        multipartUploadRequest.contentType = @"application/octet-stream";
        multipartUploadRequest.uploadingFileURL = [NSURL fileURLWithPath:[[NSString oss_documentDirectory] stringByAppendingPathComponent:@"file5m"]];
        multipartUploadRequest.partSize = 256 * 1024;
        multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
            XCTAssertTrue(totalBytesExpectedToSend >= totalByteSent);
        };
        
        [queue addOperationWithBlock:^{
            OSSTask * task = [_client multipartUpload:multipartUploadRequest];
            [task waitUntilFinished];
            XCTAssertNotNil(task.result);
        }];
    }
    [queue waitUntilAllOperationsAreFinished];
}

- (void)testAPI_multipartRequestWithWrongFileURL {
    OSSMultipartUploadRequest * multipartUploadRequest = [OSSMultipartUploadRequest new];
    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.bucketName = _privateBucketName;
    multipartUploadRequest.objectKey = OSS_MULTIPART_UPLOADKEY;
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.partSize = 1024 * 1024;
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    multipartUploadRequest.uploadingFileURL = [NSURL URLWithString:@"http://www.alibaba-inc.com"];
    
    OSSTask * multipartTask = [_client multipartUpload:multipartUploadRequest];
    
    [[multipartTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        NSLog(@"Error: %@", task.error);
        
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_multipartRequestWithUnexistFileURL {
    OSSMultipartUploadRequest * multipartUploadRequest = [OSSMultipartUploadRequest new];
    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.bucketName = _privateBucketName;
    multipartUploadRequest.objectKey = OSS_MULTIPART_UPLOADKEY;
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.partSize = 1024 * 1024;
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    NSString * docDir = [NSString oss_documentDirectory];
    multipartUploadRequest.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"unexistfile"]];
    
    OSSTask * multipartTask = [_client multipartUpload:multipartUploadRequest];
    
    [[multipartTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_multipartRequestWithoutPartSize {
    OSSMultipartUploadRequest * multipartUploadRequest = [OSSMultipartUploadRequest new];
    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.bucketName = _privateBucketName;
    multipartUploadRequest.objectKey = OSS_MULTIPART_UPLOADKEY;
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    OSSTask * multipartTask = [_client multipartUpload:multipartUploadRequest];
    
    [[multipartTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_multipartRequestWithoutObjectKey {
    OSSMultipartUploadRequest * multipartUploadRequest = [OSSMultipartUploadRequest new];
    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.bucketName = _privateBucketName;
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.partSize = 1024 * 1024;
    multipartUploadRequest.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    OSSTask * multipartTask = [_client multipartUpload:multipartUploadRequest];
    
    [[multipartTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_multipartRequestWithoutBucketName {
    OSSMultipartUploadRequest * multipartUploadRequest = [OSSMultipartUploadRequest new];
    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.objectKey = OSS_MULTIPART_UPLOADKEY;
    multipartUploadRequest.partSize = 1024 * 1024;
    multipartUploadRequest.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    OSSTask * multipartTask = [_client multipartUpload:multipartUploadRequest];
    
    [[multipartTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_dataTaskAndUploadTaskSimultaneously {
    [OSSTestUtils putTestDataWithKey:@"file10k" withClient:_client withBucket:_privateBucketName];
    
    OSSPutObjectRequest *putObjectRequest = [OSSPutObjectRequest new];
    putObjectRequest.bucketName = _privateBucketName;
    putObjectRequest.objectKey = @"test-bucket";
    putObjectRequest.uploadingFileURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"xml"]];
    
    OSSHeadObjectRequest *headObjectRequest = [OSSHeadObjectRequest new];
    headObjectRequest.bucketName = _privateBucketName;
    headObjectRequest.objectKey = @"file10k";
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    dispatch_group_enter(group);
    
    [[_specialClient putObject:putObjectRequest] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        dispatch_group_leave(group);
        return nil;
    }];

    [[_specialClient headObject:headObjectRequest] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        dispatch_group_leave(group);
        return nil;
    }];

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    XCTAssertTrue(YES);
}

- (void)testAPI_multipartUploadWithFileSizeLessThan100k {
    OSSMultipartUploadRequest *request = [OSSMultipartUploadRequest new];
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"file10k"];
    request.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file10k";
    
    OSSTask *task = [_client multipartUpload:request];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);
}

- (void)testAPI_multipartUploadWithPartSizeLessThan100k {
    OSSMultipartUploadRequest *request = [OSSMultipartUploadRequest new];
    NSURL *fileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    request.uploadingFileURL = fileURL;
    request.partSize = 51200;
    request.bucketName = _privateBucketName;
    request.objectKey = @"test-part-size-less-than-100k";
    
    OSSTask *task = [_client multipartUpload:request];
    [task waitUntilFinished];
    
    XCTAssertNotNil(task.error);
}

- (void)testAPI_multipartUploadWithFileAndPartSizeLessThan100k {
    OSSMultipartUploadRequest *request = [OSSMultipartUploadRequest new];
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"file10k"];
    request.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    request.partSize = 51200;
    request.bucketName = _privateBucketName;
    request.objectKey = @"test-part-size-less-than-100k";
    
    OSSTask *task = [_client multipartUpload:request];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);
}

- (void)testAPI_multipartUploadWithPartSizeEqualToZero {
    OSSMultipartUploadRequest *request = [OSSMultipartUploadRequest new];
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"file10k"];
    request.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    request.partSize = 0;
    request.bucketName = _privateBucketName;
    request.objectKey = @"test-part-size-less-than-100k";
    
    OSSTask *task = [_client multipartUpload:request];
    [task waitUntilFinished];
    
    XCTAssertNotNil(task.error);
}

@end
