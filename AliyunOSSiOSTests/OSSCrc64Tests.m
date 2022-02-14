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
    _privateBucketName = OSS_BUCKET_PRIVATE;
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
    // 通过ClientConfiguration配置开启全局的crc64校验
    config.crc64Verifiable = YES;
    
    OSSFederationToken *token = [OSSTestUtils getSts];
    OSSStsTokenCredentialProvider *authProv = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:token.tAccessKey secretKeyId:token.tSecretKey securityToken:token.tToken];
    
    
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

@end
