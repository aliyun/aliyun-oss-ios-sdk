//
// 关于通过crc64校验数据传输的完整性请参考文档:https://help.aliyun.com/document_detail/43394.html

// OSS-iOS-SDK提供两种开启crc64校验的方式,1.通过OSSClientConfiguration的crc64Verifiable开启全局的crc64校验，2.也可以通过OSSRequest的crcFlag枚举设置开启crc64校验。当同时设置了两者，以后者为准。

// 需要注意的是:当使用OSSClient的- (OSSTask *)getObject:(OSSGetObjectRequest *)request API时,如果用户设置了request的onRecieveData时,需要用户自行在请求回调中计算crc64的值进行crc64的校验

//  Created by 怀叙 on 2017/12/14.
//  Copyright © 2017年 阿里云. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import "OSSTestMacros.h"
#import "OSSTestUtils.h"

@interface OSSCrc64Tests : XCTestCase
{
    OSSClient *_client;
    NSArray<NSNumber *> *_fileSizes;
    NSArray<NSString *> *_fileNames;
    NSString *_privateBucketName;
}

@end

@implementation OSSCrc64Tests

- (void)setUp {
    [super setUp];
    NSArray *array1 = [self.name componentsSeparatedByString:@" "];
    NSArray *array2 = [array1[1] componentsSeparatedByString:@"_"];
    NSString *testName = [[array2[1] substringToIndex:([array2[1] length] -1)] lowercaseString];
    _privateBucketName = [@"oss-ios-" stringByAppendingString:testName];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [self setUpOSSClient];
    [self setUpLocalFiles];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [OSSTestUtils cleanBucket:_privateBucketName with:_client];
}

- (void)setUpOSSClient
{
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    // 通过ClientConfiguration配置开启全局的crc64校验
    config.crc64Verifiable = YES;
    
    OSSAuthCredentialProvider *authProv = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    
    
    _client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                               credentialProvider:authProv
                              clientConfiguration:config];
    OSSCreateBucketRequest *createBucket = [OSSCreateBucketRequest new];
    createBucket.bucketName = _privateBucketName;
    [[_client createBucket:createBucket] waitUntilFinished];
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

#pragma mark - crc64 testcases

- (void)test_putObjectWithCrc64Check
{
    for (NSUInteger pIdx = 0; pIdx < 4; pIdx++)
    {
        NSString *objectKey = _fileNames[pIdx];
        NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:objectKey];
        NSURL * fileURL = [NSURL fileURLWithPath:filePath];
        
        OSSPutObjectRequest * request = [OSSPutObjectRequest new];
        request.bucketName = _privateBucketName;
        request.objectKey = objectKey;
        request.uploadingFileURL = fileURL;
        request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
        
        request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
            NSLog(@"bytesSent: %lld, totalByteSent: %lld, totalBytesExpectedToSend: %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        };
        
        OSSTask * task = [_client putObject:request];
        [[task continueWithBlock:^id(OSSTask *task) {
            XCTAssertNil(task.error);
            return nil;
        }] waitUntilFinished];
    }
}

- (void)testA_appendObject{
    
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
    OSSTask * task = [_client appendObject:request];
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

- (void)test_getObject
{
    [OSSTestUtils putTestDataWithKey:_fileNames[0] withClient:_client withBucket:_privateBucketName];
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[0];
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    __block uint64_t localCrc64 = 0;
    NSMutableData *receivedData = [NSMutableData data];
    request.onRecieveData = ^(NSData *data) {
        if (data)
        {
            NSMutableData *mutableData = [data mutableCopy];
            void *bytes = mutableData.mutableBytes;
            localCrc64 = [OSSUtil crc64ecma:localCrc64 buffer:bytes length:data.length];
            [receivedData appendData:data];
        }
    };
    
    __block uint64_t remoteCrc64 = 0;
    OSSTask * task = [_client getObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetObjectResult *result = task.result;
        if (result.remoteCRC64ecma) {
            NSScanner *scanner = [NSScanner scannerWithString:result.remoteCRC64ecma];
            [scanner scanUnsignedLongLong:&remoteCrc64];
            if (remoteCrc64 == localCrc64)
            {
                NSLog(@"crc64校验成功!");
            }else
            {
                NSLog(@"crc64校验失败!");
            }
        }
        
        return nil;
    }] waitUntilFinished];
}


- (void)test_MultipartUploadNormal {
    NSString * objectkey = @"mul-wangwang.zip";
    OSSMultipartUploadRequest * multipartUploadRequest = [OSSMultipartUploadRequest new];
    
    multipartUploadRequest.bucketName = _privateBucketName;
    multipartUploadRequest.objectKey = objectkey;
    multipartUploadRequest.partSize = 1024 * 1024;
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    multipartUploadRequest.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    OSSTask * multipartTask = [_client multipartUpload:multipartUploadRequest];
    
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
        return nil;
    }] waitUntilFinished];

}

- (void)test_resumbleUploadCancelResumble {
    NSString * objectkey = @"oss-browser.zip";
    __block bool cancel = NO;
    OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
    resumableUpload.bucketName = _privateBucketName;
    resumableUpload.objectKey = objectkey;
    resumableUpload.deleteUploadIdOnCancelling = NO;
    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.partSize = 100 * 1024;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        if(bytesSent!=0 && totalByteSent / bytesSent >= 1000){
            cancel = YES;
        }
    };
    resumableUpload.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"oss-browser" withExtension:@"zip"];
    OSSTask * resumeTask = [_client resumableUpload:resumableUpload];
    [resumeTask continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        NSLog(@"resumbleUpload 001 error: %@", task.error);
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
    resumableUpload.objectKey = objectkey;
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.partSize = 100 * 1024;
    resumableUpload.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"oss-browser" withExtension:@"zip"];
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        XCTAssertGreaterThan(totalByteSent, totalBytesExpectedToSend / 3);
    };
    resumeTask = [_client resumableUpload:resumableUpload];
    [[resumeTask continueWithBlock:^id(OSSTask *task) {
        NSLog(@"resumbleUpload 002 error: %@", task.error);
        XCTAssertNil(task.error);
        NSString * recordFilePath = [self getRecordFilePath:resumableUpload];
        XCTAssertTrue(![[NSFileManager defaultManager] fileExistsAtPath:recordFilePath]);
        return nil;
    }] waitUntilFinished];
    
}

- (NSString *)getRecordFilePath:(OSSResumableUploadRequest *)resumableUpload {
    NSString *recordPathMd5 = [OSSUtil fileMD5String:[resumableUpload.uploadingFileURL path]];
    NSData *data = [[NSString stringWithFormat:@"%@%@%@%lu",recordPathMd5, resumableUpload.bucketName, resumableUpload.objectKey, resumableUpload.partSize] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *recordFileName = [OSSUtil dataMD5String:data];
    NSString *recordFilePath = [NSString stringWithFormat:@"%@/%@",resumableUpload.recordDirectoryPath,recordFileName];
    return recordFilePath;
}



@end
