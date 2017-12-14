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

@interface OSSObjectTests : XCTestCase
{
    OSSClient *_client;
    NSArray<NSNumber *> *_fileSizes;
    NSArray<NSString *> *_fileNames;
}

@end

@implementation OSSObjectTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [self setUpOSSClient];
    [self setUpLocalFiles];
    [self initUploadFile];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)setUpOSSClient
{
    OSSClientConfiguration *config = [OSSClientConfiguration new];
//    config.crc64Verifiable = YES;
    
    OSSAuthCredentialProvider *authProv = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    _client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                               credentialProvider:authProv
                              clientConfiguration:config];
    [OSSLog enableLog];
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

- (void)initUploadFile{
    NSString * uploadFile = @"guihua";
    NSString * type = @"zip";
    NSFileManager * fm = [NSFileManager defaultManager];
    NSString * mainDir = [NSString oss_documentDirectory];
    NSString * newFilePath = [mainDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", uploadFile, type]];
    if ([fm fileExistsAtPath:newFilePath]) {
        return;
    }
    
    //获取bundle中的资源内容
    NSString * uploadPath = [[NSBundle mainBundle] pathForResource:uploadFile ofType:type];
    
    NSLog(@"uploadPath: %@, newFilePath: %@", uploadPath, newFilePath);
    NSData *data = [NSData dataWithContentsOfFile:uploadPath];
    
    BOOL result = [data writeToFile:newFilePath atomically:YES];
    
    if (result) {
        NSLog(@"write upload file success");
    }else {
        NSLog(@"write upload file failed");
    }
}

#pragma mark - putObject

- (void)testAPI_putObjectFromNSData
{
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[0]];
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
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
    NSString *objectKey = _fileNames[0];
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:objectKey];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.objectKey = objectKey;
    request.uploadingFileURL = fileURL;
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.crcFlag = OSSRequestCRCOpen;
    
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"bytesSent: %lld, totalByteSent: %lld, totalBytesExpectedToSend: %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    OSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        BOOL isEqual = [self checkMd5WithBucketName:OSS_BUCKET_PRIVATE
                                          objectKey:objectKey
                                      localFilePath:filePath];
        XCTAssertTrue(isEqual);
        return nil;
    }] waitUntilFinished];
}

- (void)test_putObjectFromFileWithCRC
{
    NSString *fileName = @"guihua.zip";
    NSString *objectKey = @"putObject-guihua.zip";
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:fileName];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.objectKey = objectKey;
    request.uploadingFileURL = fileURL;
    request.crcFlag = OSSRequestCRCOpen;
//    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
//        NSLog(@"bytesSent: %lld, totalByteSent: %lld, totalBytesExpectedToSend: %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
//    };
    
    OSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        BOOL isEqual = [self checkMd5WithBucketName:OSS_BUCKET_PRIVATE
                                          objectKey:objectKey
                                      localFilePath:filePath];
        XCTAssertTrue(isEqual);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_putObjectToPublicBucketFromFile
{
    for (NSUInteger pIdx = 0; pIdx < _fileNames.count; pIdx++)
    {
        NSString *objectKey = _fileNames[pIdx];
        NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:objectKey];
        NSURL * fileURL = [NSURL fileURLWithPath:filePath];
        
        OSSPutObjectRequest * request = [OSSPutObjectRequest new];
        request.bucketName = OSS_BUCKET_PUBLIC;
        request.objectKey = objectKey;
        request.uploadingFileURL = fileURL;
        request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
        request.crcFlag = OSSRequestCRCOpen;
        
        request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
            NSLog(@"bytesSent: %lld, totalByteSent: %lld, totalBytesExpectedToSend: %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        };
        
        OSSTask * task = [_client putObject:request];
        [[task continueWithBlock:^id(OSSTask *task) {
            XCTAssertNil(task.error);
            BOOL isEqual = [self checkMd5WithBucketName:OSS_BUCKET_PRIVATE
                                              objectKey:objectKey
                                          localFilePath:filePath];
            XCTAssertTrue(isEqual);
            return nil;
        }] waitUntilFinished];
    }
}

- (void)testAPI_putObjectWithoutContentType
{
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[0]];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
    
    NSString *objectKeyWithoutContentType = @"objectWithoutContentType";
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.objectKey = objectKeyWithoutContentType;
    request.crcFlag = OSSRequestCRCOpen;
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
    head.bucketName = OSS_BUCKET_PRIVATE;
    head.objectKey = objectKeyWithoutContentType;
    [[[_client headObject:head] continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSHeadObjectResult * headResult = task.result;
        XCTAssertNotNil([headResult.objectMeta objectForKey:@"Content-Type"]);
        return nil;
    }] waitUntilFinished];
    
    BOOL isEqual = [self checkMd5WithBucketName:OSS_BUCKET_PRIVATE
                                      objectKey:objectKeyWithoutContentType
                                  localFilePath:filePath];
    XCTAssertTrue(isEqual);
}

- (void)testAPI_putObjectWithContentType
{
    NSString *fileName = _fileNames[0];
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:fileName];
    
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
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
        NSLog(@"Result - requestId: %@, headerFields: %@",
              result.requestId,
              result.httpResponseHeaderFields);
        return nil;
    }] waitUntilFinished];
    
    OSSHeadObjectRequest * head = [OSSHeadObjectRequest new];
    head.bucketName = OSS_BUCKET_PRIVATE;
    head.objectKey = fileName;
    
    [[[_client headObject:head] continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSHeadObjectResult * headResult = task.result;
        XCTAssertEqualObjects([headResult.objectMeta objectForKey:@"Content-Type"], @"application/special");
        return nil;
    }] waitUntilFinished];
    
    BOOL isEqual = [self checkMd5WithBucketName:OSS_BUCKET_PRIVATE
                                      objectKey:fileName
                                  localFilePath:filePath];
    XCTAssertTrue(isEqual);
}

- (void)testAPI_putObjectWithServerCallback
{
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
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
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.objectKey = _fileNames[0];
    request.isAuthenticationRequired = NO;
    OSSTask * task = [_client getObject:request];
    [task waitUntilFinished];
    
    XCTAssertNotNil(task.error);
    XCTAssertEqual(-403, task.error.code);
    
    OSSPutObjectACLRequest * putAclRequest = [OSSPutObjectACLRequest new];
    putAclRequest.bucketName = OSS_BUCKET_PRIVATE;
    putAclRequest.objectKey = _fileNames[0];
    putAclRequest.acl = @"public-read-write";
    task = [_client putObjectACL:putAclRequest];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);
    
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.objectKey = _fileNames[0];
    request.isAuthenticationRequired = NO;
    task = [_client getObject:request];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);
}

- (void)testA_appendObject
{
    OSSDeleteObjectRequest * delete = [OSSDeleteObjectRequest new];
    delete.bucketName = OSS_BUCKET_PRIVATE;
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
    request.bucketName = OSS_BUCKET_PRIVATE;
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
    
    request.bucketName = OSS_BUCKET_PRIVATE;
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
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
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

- (void)testAPI_getImage
{
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.objectKey = @"hasky.jpeg";
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
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
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
    request.bucketName = OSS_BUCKET_PRIVATE;
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
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
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
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.objectKey = _fileNames[3];
    
    NSMutableData * recieveData = [NSMutableData data];
    
    request.onRecieveData = ^(NSData * data) {
        [recieveData appendData:data];
        NSLog(@"%ld", [data length]);
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
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = OSS_BUCKET_PUBLIC;
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
    NSString *tmpFilePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"tempfile"];
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = OSS_BUCKET_PUBLIC;
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
    request.bucketName = OSS_BUCKET_PUBLIC;
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

#pragma mark - others
- (void)testAPI_headObject
{
    OSSHeadObjectRequest * request = [OSSHeadObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.objectKey = @"file1m";
    
    OSSTask * task = [_client headObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_doesObjectExistWithExistObject
{
    NSError * error = nil;
    BOOL isExist = [_client doesObjectExistInBucket:OSS_BUCKET_PRIVATE objectKey:@"file1m" error:&error];
    XCTAssertEqual(isExist, YES);
    XCTAssertNil(error);
}

- (void)testAPI_doesObjectExistWithNoExistObject
{
    NSError * error = nil;
    BOOL isExist = [_client doesObjectExistInBucket:OSS_BUCKET_PRIVATE objectKey:@"wrong-key" error:&error];
    XCTAssertEqual(isExist, NO);
    XCTAssertNil(error);
}

- (void)testAPI_doesObjectExistWithError
{
    NSError * error = nil;
    // invalid credentialProvider
    id<OSSCredentialProvider> c = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:@"" secretKey:@""];
    OSSClient * tClient = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:c];
    BOOL isExist = [tClient doesObjectExistInBucket:OSS_BUCKET_PRIVATE objectKey:@"file1m" error:&error];
    XCTAssertEqual(isExist, NO);
    XCTAssertNotNil(error);
}

- (void)testAPI_copyAndDeleteObject
{
    OSSHeadObjectRequest * head = [OSSHeadObjectRequest new];
    head.bucketName = OSS_BUCKET_PRIVATE;
    head.objectKey = @"file1m_copyTo";
    OSSTask * task = [_client headObject:head];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(-404, task.error.code);
        NSLog(@"404 error: %@", task.error);
        return nil;
    }] waitUntilFinished];
    
    OSSCopyObjectRequest * copy = [OSSCopyObjectRequest new];
    copy.bucketName = OSS_BUCKET_PRIVATE;
    copy.objectKey = @"file1m_copyTo";
    copy.sourceCopyFrom = [NSString stringWithFormat:@"/%@/%@", OSS_BUCKET_PRIVATE, @"file1m"];
    task = [_client copyObject:copy];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    OSSDeleteObjectRequest * delete = [OSSDeleteObjectRequest new];
    delete.bucketName = OSS_BUCKET_PRIVATE;
    delete.objectKey = @"file1m_copyTo";
    task = [_client deleteObject:delete];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDeleteObjectResult * result = task.result;
        XCTAssertEqual(204, result.httpResponseCode);
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
    if (readError) {
        NSLog(@"readError: %@",readError);
    }
    
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
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
    
    BOOL isEqual = [self checkMd5WithBucketName:OSS_BUCKET_PRIVATE
                                      objectKey:fileName
                                  localFilePath:filePath];
    XCTAssertTrue(isEqual);
}

- (void)testAPI_timeSkewedButAutoRetry
{
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.objectKey = @"file1m";
    
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
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.objectKey = @"file1m";
    
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
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
    request.bucketName = OSS_BUCKET_PUBLIC;
    request.isAuthenticationRequired = NO;
    request.objectKey = @"file1m";
    request.contentType = @"application/octet-stream";
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    
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
    request.bucketName = OSS_BUCKET_PUBLIC;
    request.isAuthenticationRequired = NO;
    request.objectKey = @"file1m";
    request.contentType = @"application/octet-stream";
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    
    request.uploadingFileURL = fileURL;
    request.contentMd5 = @"invliadmd5valuetotest";
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        // NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    OSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(-1 * 400, task.error.code);
        return nil;
    }] waitUntilFinished];
}

#pragma mark - cname
- (void)testAPI_cnamePutObject
{
    id<OSSCredentialProvider> provider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient * tClient = [[OSSClient alloc] initWithEndpoint:OSS_CNAME_URL
                                           credentialProvider:provider];
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = OSS_BUCKET_PUBLIC;
    request.objectKey = @"file1m";
    
    NSString * docDir = [NSString oss_documentDirectory];
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

- (void)testAPI_cnameGetObejct
{
    id<OSSCredentialProvider> provider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSClient * tClient = [[OSSClient alloc] initWithEndpoint:OSS_CNAME_URL
                                           credentialProvider:provider];
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = OSS_BUCKET_PUBLIC;
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
        NSLog(@"Result - requestId: %@, headerFields: %@, dataLength: %lu",
              result.requestId,
              result.httpResponseHeaderFields,
              (unsigned long)[result.downloadedData length]);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_customExcludeCname
{
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    conf.cnameExcludeList = @[@"osstest.xxyycc.com", @"vpc.sample.com"];
    id<OSSCredentialProvider> provider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    
    OSSClient * tClient = [[OSSClient alloc] initWithEndpoint:OSS_CNAME_URL
                                           credentialProvider:provider
                                          clientConfiguration:conf];
    
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = OSS_BUCKET_PUBLIC;
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
        NSLog(@"Result - requestId: %@, headerFields: %@, dataLength: %lu",
              result.requestId,
              result.httpResponseHeaderFields,
              (unsigned long)[result.downloadedData length]);
        return nil;
    }] waitUntilFinished];
}

#pragma mark cancel

- (void)testAPI_cancelPutObejct
{
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
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
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
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
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    OSSGetObjectRequest * getRequest = [OSSGetObjectRequest new];
    getRequest.bucketName = OSS_BUCKET_PRIVATE;
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
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    OSSGetObjectRequest * getRequest = [OSSGetObjectRequest new];
    getRequest.bucketName = OSS_BUCKET_PRIVATE;
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

- (void)testAPI_getObjectWithServerErrorNotExistObject
{
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.objectKey = @"not_exist_ttt";
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    OSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(task.error.domain, OSSServerErrorDomain);
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
        XCTAssertEqual(task.error.domain, OSSServerErrorDomain);
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
    request.bucketName = OSS_BUCKET_PRIVATE;
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
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.objectKey = @"file1m";
    request.isAuthenticationRequired = NO;
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    OSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(task.error.domain, OSSServerErrorDomain);
        XCTAssertEqual(-1 * 403, task.error.code);
        NSLog(@"error: %@", task.error);
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
        XCTAssertEqual(task.error.domain, OSSClientErrorDomain);
        XCTAssertEqual(OSSClientErrorCodeInvalidArgument, task.error.code);
        NSLog(@"ErrorMessage: %@", [task.error.userInfo objectForKey:OSSErrorMessageTOKEN]);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_putObjectWithErrorOfNoSource
{
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.objectKey = @"file1m";
    
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    OSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(task.error.domain, OSSClientErrorDomain);
        XCTAssertEqual(OSSClientErrorCodeInvalidArgument, task.error.code);
        NSLog(@"ErrorMessage: %@", [task.error.userInfo objectForKey:OSSErrorMessageTOKEN]);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_putObjectWithErrorOfNoCredentialProvier
{
    OSSClient * tempClient = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:nil];
    
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
    
    OSSTask * task = [tempClient putObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        return nil;
        XCTAssertEqualObjects(OSSClientErrorDomain, task.error.domain);
    }] waitUntilFinished];
    
    task = [tempClient presignConstrainURLWithBucketName:OSS_BUCKET_PRIVATE withObjectKey:@"file1m" withExpirationInterval:3600];
    [task waitUntilFinished];
    XCTAssertEqual(OSSClientErrorDomain, task.error.domain);
    NSLog(@"error: %@", task.error);
}

#pragma mark - presign

- (void)testAPI_presignConstrainURL
{
    OSSTask * tk = [_client presignConstrainURLWithBucketName:OSS_BUCKET_PRIVATE
                                               withObjectKey:@"file1k"
                                      withExpirationInterval:30 * 60];
    XCTAssertNil(tk.error);
}

- (void)testAPI_presignPublicURL
{
    OSSTask * task = [_client presignPublicURLWithBucketName:OSS_BUCKET_PUBLIC withObjectKey:@"file1m"];
    XCTAssertNil(task.error);
}

- (void)testPresignImageConstrainURL
{
    OSSTask * tk = [_client presignConstrainURLWithBucketName:OSS_BUCKET_PRIVATE
                                                withObjectKey:@"hasky.jpeg"
                                       withExpirationInterval:30 * 60
                                               withParameters:@{@"x-oss-process": @"image/resize,w_50"}];
    XCTAssertNil(tk.error);
}

- (void)testPublicImageURL
{
    OSSTask * task = [_client presignPublicURLWithBucketName:OSS_BUCKET_PUBLIC
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
@end
